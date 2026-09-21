import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';

import '../models/note.dart';
import '../services/notes_repository.dart';
import '../services/multi_window_service.dart';
import '../theme.dart';
import '../utils/note_colors.dart';
import '../utils/tiptap_quill_converter.dart';
import '../widgets/neo_interactive.dart';
import '../widgets/note_toolbar.dart';

enum SaveStatus { saved, saving, error }

/// Standalone Floating Window Application for NoteEditorScreen
class NoteEditorApp extends ConsumerStatefulWidget {
  final String windowId;
  final String noteId;

  const NoteEditorApp({
    super.key,
    required this.windowId,
    required this.noteId,
  });

  @override
  ConsumerState<NoteEditorApp> createState() => _NoteEditorAppState();
}

class _NoteEditorAppState extends ConsumerState<NoteEditorApp> {
  @override
  void initState() {
    super.initState();
    MultiWindowService.initSubWindowListener(
      onThemeChanged: (themeModeName) {
        if (!mounted) return;
        if (themeModeName == 'dark') {
          ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark, broadcast: false);
        } else if (themeModeName == 'light') {
          ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light, broadcast: false);
        } else {
          ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system, broadcast: false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'NOPEPADS',
      theme: NeoTheme.lightTheme,
      darkTheme: NeoTheme.darkTheme,
      themeMode: themeMode,
      home: NoteEditorScreen(
        noteId: widget.noteId,
        isStandaloneWindow: true,
        windowId: widget.windowId,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        quill.FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
      ],
      debugShowCheckedModeBanner: false,
    );
  }
}

class NoteEditorScreen extends ConsumerStatefulWidget {
  final String? noteId;
  final bool isStandaloneWindow;
  final String? windowId;

  const NoteEditorScreen({
    super.key,
    this.noteId,
    this.isStandaloneWindow = false,
    this.windowId,
  });

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> with WindowListener {
  final _titleController = TextEditingController();
  late final quill.QuillController _quillController = quill.QuillController(
    document: quill.Document(),
    selection: const TextSelection.collapsed(offset: 0),
    config: quill.QuillControllerConfig(
      // ignore: experimental_member_use
      clipboardConfig: quill.QuillClipboardConfig(
        // ignore: experimental_member_use
        enableExternalRichPaste: false,
        // ignore: experimental_member_use
        onClipboardPaste: _handlePaste,
      ),
    ),
  );
  final _titleFocusNode = FocusNode();
  late final FocusNode _editorFocusNode = FocusNode(onKeyEvent: _handleEditorKey);
  final ScrollController _editorScrollController = ScrollController();
  
  bool _isLoading = false;
  Note? _existingNote;
  String _selectedColorId = 'Yellow';
  bool _showTitle = true; // Default

  // Autosave states — isolated with ValueNotifier to prevent full-screen rebuilds
  final ValueNotifier<SaveStatus> _saveStatusNotifier = ValueNotifier<SaveStatus>(SaveStatus.saved);
  Timer? _debounceTimer;
  bool _hasUnsavedChanges = false;
  bool _isInitializing = true;
  StreamSubscription? _quillSubscription;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTitleChanged);
    if (widget.isStandaloneWindow) {
      windowManager.addListener(this);
      _initWindow();
    }
    if (widget.noteId != null) {
      _loadNote();
    } else {
      // New note: mark initializing complete after initial frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _isInitializing = false;
          _attachDocListener();
        }
      });
    }
  }

  Future<void> _initWindow() async {
    try {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false);
      await windowManager.setSize(const Size(460, 520));
      await windowManager.setMinimumSize(const Size(360, 380));
      await windowManager.setTitle('NOPEPADS');

      bool hasShown = false;
      void doShow() async {
        if (!hasShown) {
          hasShown = true;
          try {
            await windowManager.show();
            await windowManager.focus();
          } catch (_) {}
        }
      }

      // Wait until the first frame is painted before revealing the window
      WidgetsBinding.instance.addPostFrameCallback((_) => doShow());
      Future.delayed(const Duration(milliseconds: 200), doShow);
    } catch (_) {}
  }

  @override
  void onWindowClose() async {
    await _flushAndPop();
  }

  @override
  void dispose() {
    if (widget.isStandaloneWindow) {
      windowManager.removeListener(this);
    }
    _debounceTimer?.cancel();
    _quillSubscription?.cancel();
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _quillController.dispose();
    _titleFocusNode.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    _saveStatusNotifier.dispose();
    super.dispose();
  }

  /// Explicit hardware keyboard handler for desktop (Windows/macOS/Linux)
  /// Guarantees that Backspace, Delete, Cut, Copy, Paste (Ctrl+V), and Select All work reliably
  KeyEventResult _handleEditorKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final docLen = _quillController.document.length;
    final isControl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;

    // --- TOOLBAR FORMATTING SHORTCUTS ---

    // 1. Undo: Ctrl+Z
    if (isControl && !isShift && !isAlt &&
        (event.logicalKey == LogicalKeyboardKey.keyZ ||
            event.character == 'z' ||
            event.character == 'Z')) {
      NoteToolbarActions.undo(_quillController);
      return KeyEventResult.handled;
    }

    // 2. Redo: Ctrl+Y or Ctrl+Shift+Z
    if ((isControl && !isShift && !isAlt &&
            (event.logicalKey == LogicalKeyboardKey.keyY ||
                event.character == 'y' ||
                event.character == 'Y')) ||
        (isControl && isShift && !isAlt &&
            (event.logicalKey == LogicalKeyboardKey.keyZ ||
                event.character == 'z' ||
                event.character == 'Z'))) {
      NoteToolbarActions.redo(_quillController);
      return KeyEventResult.handled;
    }

    // 3. Bold: Ctrl+B
    if (isControl && !isShift && !isAlt &&
        (event.logicalKey == LogicalKeyboardKey.keyB ||
            event.character == 'b' ||
            event.character == 'B')) {
      NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.bold);
      return KeyEventResult.handled;
    }

    // 4. Italic: Ctrl+I
    if (isControl && !isShift && !isAlt &&
        (event.logicalKey == LogicalKeyboardKey.keyI ||
            event.character == 'i' ||
            event.character == 'I')) {
      NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.italic);
      return KeyEventResult.handled;
    }

    // 5. Underline: Ctrl+U
    if (isControl && !isShift && !isAlt &&
        (event.logicalKey == LogicalKeyboardKey.keyU ||
            event.character == 'u' ||
            event.character == 'U')) {
      NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.underline);
      return KeyEventResult.handled;
    }

    // 6. Strikethrough: Ctrl+Shift+S
    if (isControl && isShift && !isAlt &&
        (event.logicalKey == LogicalKeyboardKey.keyS ||
            event.character == 's' ||
            event.character == 'S')) {
      NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.strikeThrough);
      return KeyEventResult.handled;
    }

    // 7. Highlight: Ctrl+Shift+H
    if (isControl && isShift && !isAlt &&
        (event.logicalKey == LogicalKeyboardKey.keyH ||
            event.character == 'h' ||
            event.character == 'H')) {
      NoteToolbarActions.toggleHighlight(_quillController);
      return KeyEventResult.handled;
    }

    // 8. Inline Code: Ctrl+E or Ctrl+Shift+E
    if (isControl && !isAlt &&
        (event.logicalKey == LogicalKeyboardKey.keyE ||
            event.character == 'e' ||
            event.character == 'E')) {
      NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.inlineCode);
      return KeyEventResult.handled;
    }

    // 9. Checklist: Ctrl+Shift+C
    if (isControl && isShift && !isAlt &&
        (event.logicalKey == LogicalKeyboardKey.keyC ||
            event.character == 'c' ||
            event.character == 'C')) {
      NoteToolbarActions.toggleCheck(_quillController);
      return KeyEventResult.handled;
    }

    // 10. Bullet List: Ctrl+Shift+8
    if (isControl && isShift && !isAlt &&
        (event.logicalKey == LogicalKeyboardKey.digit8 ||
            event.logicalKey == LogicalKeyboardKey.asterisk ||
            event.character == '*')) {
      NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.ul);
      return KeyEventResult.handled;
    }

    // 11. Numbered List: Ctrl+Shift+7
    if (isControl && isShift && !isAlt &&
        (event.logicalKey == LogicalKeyboardKey.digit7 ||
            event.logicalKey == LogicalKeyboardKey.ampersand ||
            event.character == '&')) {
      NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.ol);
      return KeyEventResult.handled;
    }

    // 12. Quote: Ctrl+Shift+Q or Ctrl+Shift+9
    if (isControl && isShift && !isAlt &&
        (event.logicalKey == LogicalKeyboardKey.keyQ ||
            event.character == 'q' ||
            event.character == 'Q' ||
            event.logicalKey == LogicalKeyboardKey.digit9 ||
            event.character == '(')) {
      NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.blockQuote);
      return KeyEventResult.handled;
    }

    // 13. Code Block: Ctrl+Alt+C or Ctrl+Shift+K
    if ((isControl && isAlt &&
            (event.logicalKey == LogicalKeyboardKey.keyC ||
                event.character == 'c' ||
                event.character == 'C')) ||
        (isControl && isShift && !isAlt &&
            (event.logicalKey == LogicalKeyboardKey.keyK ||
                event.character == 'k' ||
                event.character == 'K'))) {
      NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.codeBlock);
      return KeyEventResult.handled;
    }

    // 14. Headings: Ctrl+1, Ctrl+2, Ctrl+3 (and Ctrl+Alt+1, 2, 3)
    if (isControl && !isShift &&
        (event.logicalKey == LogicalKeyboardKey.digit1 ||
            event.logicalKey == LogicalKeyboardKey.numpad1 ||
            event.character == '1')) {
      NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.h1);
      return KeyEventResult.handled;
    }

    if (isControl && !isShift &&
        (event.logicalKey == LogicalKeyboardKey.digit2 ||
            event.logicalKey == LogicalKeyboardKey.numpad2 ||
            event.character == '2')) {
      NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.h2);
      return KeyEventResult.handled;
    }

    if (isControl && !isShift &&
        (event.logicalKey == LogicalKeyboardKey.digit3 ||
            event.logicalKey == LogicalKeyboardKey.numpad3 ||
            event.character == '3')) {
      NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.h3);
      return KeyEventResult.handled;
    }

    // 15. Clear Headings: Ctrl+0
    if (isControl && !isShift &&
        (event.logicalKey == LogicalKeyboardKey.digit0 ||
            event.logicalKey == LogicalKeyboardKey.numpad0 ||
            event.character == '0')) {
      _quillController.formatSelection(quill.Attribute.clone(quill.Attribute.h1, null));
      _quillController.formatSelection(quill.Attribute.clone(quill.Attribute.h2, null));
      _quillController.formatSelection(quill.Attribute.clone(quill.Attribute.h3, null));
      return KeyEventResult.handled;
    }

    // 16. Clear Formatting: Ctrl+\ or Ctrl+Space
    if (isControl && !isShift && !isAlt &&
        (event.logicalKey == LogicalKeyboardKey.backslash ||
            event.logicalKey == LogicalKeyboardKey.space ||
            event.character == '\\')) {
      NoteToolbarActions.clearFormatting(_quillController);
      return KeyEventResult.handled;
    }

    // 17. New Note: Ctrl+N (standalone sticky note window)
    if (widget.isStandaloneWindow &&
        isControl && !isShift && !isAlt &&
        (event.logicalKey == LogicalKeyboardKey.keyN ||
            event.character == 'n' ||
            event.character == 'N')) {
      MultiWindowService.createNewNoteFromSubWindow();
      return KeyEventResult.handled;
    }

    // --- STANDARD TEXT EDITING ACTIONS ---

    // Paste: Ctrl+V or Shift+Insert
    if ((isControl &&
            (event.logicalKey == LogicalKeyboardKey.keyV ||
                event.character == 'v' ||
                event.character == 'V')) ||
        (isShift && event.logicalKey == LogicalKeyboardKey.insert)) {
      _handlePaste();
      return KeyEventResult.handled;
    }

    // Copy: Ctrl+C or Ctrl+Insert (plain Ctrl+C, not Shift or Alt)
    if ((isControl && !isShift && !isAlt &&
            (event.logicalKey == LogicalKeyboardKey.keyC ||
                event.character == 'c' ||
                event.character == 'C')) ||
        (isControl && !isShift && !isAlt && event.logicalKey == LogicalKeyboardKey.insert)) {
      final selection = _quillController.selection;
      if (selection.isValid && !selection.isCollapsed) {
        final start = selection.start.clamp(0, (docLen > 0) ? docLen - 1 : 0);
        final end = selection.end.clamp(0, (docLen > 0) ? docLen - 1 : 0);
        if (end > start) {
          final selectedText =
              _quillController.document.getPlainText(start, end - start);
          Clipboard.setData(ClipboardData(text: selectedText));
          return KeyEventResult.handled;
        }
      }
    }

    // Cut: Ctrl+X or Shift+Delete (plain Ctrl+X, not Shift or Alt)
    if ((isControl && !isShift && !isAlt &&
            (event.logicalKey == LogicalKeyboardKey.keyX ||
                event.character == 'x' ||
                event.character == 'X')) ||
        (isShift && event.logicalKey == LogicalKeyboardKey.delete)) {
      final selection = _quillController.selection;
      if (selection.isValid && !selection.isCollapsed) {
        final start = selection.start.clamp(0, (docLen > 0) ? docLen - 1 : 0);
        final end = selection.end.clamp(0, (docLen > 0) ? docLen - 1 : 0);
        if (end > start) {
          final selectedText =
              _quillController.document.getPlainText(start, end - start);
          Clipboard.setData(ClipboardData(text: selectedText));
          _quillController.replaceText(start, end - start, '', null);
          _quillController.updateSelection(
            TextSelection.collapsed(offset: start),
            quill.ChangeSource.local,
          );
          _onContentChanged();
          if (mounted) setState(() {});
          return KeyEventResult.handled;
        }
      }
    }

    // Select All: Ctrl+A (plain Ctrl+A, not Shift or Alt)
    if (isControl && !isShift && !isAlt &&
        (event.logicalKey == LogicalKeyboardKey.keyA ||
            event.character == 'a' ||
            event.character == 'A')) {
      final maxOffset = (docLen > 1) ? docLen - 1 : 0;
      _quillController.updateSelection(
        TextSelection(baseOffset: 0, extentOffset: maxOffset),
        quill.ChangeSource.local,
      );
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      var selection = _quillController.selection;
      if (!selection.isValid) {
        final offset = (docLen > 1) ? docLen - 1 : 0;
        selection = TextSelection.collapsed(offset: offset);
        _quillController.updateSelection(selection, quill.ChangeSource.local);
      }

      if (!selection.isCollapsed) {
        final start = selection.start;
        int len = selection.end - selection.start;
        if (start + len >= docLen) {
          len = docLen - 1 - start;
        }
        if (len > 0) {
          _quillController.replaceText(start, len, '', null);
          _quillController.updateSelection(
            TextSelection.collapsed(offset: start),
            quill.ChangeSource.local,
          );
          _onContentChanged();
          return KeyEventResult.handled;
        } else if (docLen > 1 && start == 0) {
          _quillController.document = quill.Document();
          _quillController.updateSelection(
            const TextSelection.collapsed(offset: 0),
            quill.ChangeSource.local,
          );
          _onContentChanged();
          return KeyEventResult.handled;
        }
        return KeyEventResult.handled;
      }

      // Check if Ctrl is held for word deletion (Ctrl+Backspace)
      if (HardwareKeyboard.instance.isControlPressed) {
        if (selection.baseOffset > 0) {
          final text = _quillController.document.toPlainText();
          final before = text.substring(0, selection.baseOffset);
          int i = before.length - 1;
          while (i > 0 && before[i].trim().isEmpty) {
            i--;
          }
          while (i > 0 && before[i].trim().isNotEmpty) {
            i--;
          }
          final deleteFrom = i == 0 ? 0 : i + 1;
          final len = selection.baseOffset - deleteFrom;
          if (len > 0) {
            _quillController.replaceText(deleteFrom, len, '', null);
            _quillController.updateSelection(
              TextSelection.collapsed(offset: deleteFrom),
              quill.ChangeSource.local,
            );
            _onContentChanged();
            return KeyEventResult.handled;
          }
        }
      } else if (selection.baseOffset > 0) {
        final pos = selection.baseOffset - 1;
        _quillController.replaceText(pos, 1, '', null);
        _quillController.updateSelection(
          TextSelection.collapsed(offset: pos),
          quill.ChangeSource.local,
        );
        _onContentChanged();
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.delete) {
      var selection = _quillController.selection;
      if (!selection.isValid) {
        selection = const TextSelection.collapsed(offset: 0);
        _quillController.updateSelection(selection, quill.ChangeSource.local);
      }

      if (!selection.isCollapsed) {
        final start = selection.start;
        int len = selection.end - selection.start;
        if (start + len >= docLen) {
          len = docLen - 1 - start;
        }
        if (len > 0) {
          _quillController.replaceText(start, len, '', null);
          _quillController.updateSelection(
            TextSelection.collapsed(offset: start),
            quill.ChangeSource.local,
          );
          _onContentChanged();
          return KeyEventResult.handled;
        } else if (docLen > 1 && start == 0) {
          _quillController.document = quill.Document();
          _quillController.updateSelection(
            const TextSelection.collapsed(offset: 0),
            quill.ChangeSource.local,
          );
          _onContentChanged();
          return KeyEventResult.handled;
        }
        return KeyEventResult.handled;
      }

      // Check if Ctrl is held for word deletion (Ctrl+Delete)
      if (HardwareKeyboard.instance.isControlPressed) {
        if (selection.baseOffset < docLen - 1) {
          final text = _quillController.document.toPlainText();
          final after = text.substring(selection.baseOffset);
          int i = 0;
          while (i < after.length && after[i].trim().isEmpty) {
            i++;
          }
          while (i < after.length && after[i].trim().isNotEmpty) {
            i++;
          }
          if (i > 0) {
            final safeLen = (selection.baseOffset + i >= docLen)
                ? (docLen - 1 - selection.baseOffset)
                : i;
            if (safeLen > 0) {
              _quillController.replaceText(
                selection.baseOffset,
                safeLen,
                '',
                null,
              );
              _quillController.updateSelection(
                TextSelection.collapsed(offset: selection.baseOffset),
                quill.ChangeSource.local,
              );
              _onContentChanged();
              return KeyEventResult.handled;
            }
          }
        }
      } else if (selection.baseOffset < docLen - 1) {
        final pos = selection.baseOffset;
        _quillController.replaceText(pos, 1, '', null);
        _quillController.updateSelection(
          TextSelection.collapsed(offset: pos),
          quill.ChangeSource.local,
        );
        _onContentChanged();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  Future<bool> _handlePaste() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final rawText = clipboardData?.text;
      if (rawText == null || rawText.isEmpty) return true;

      // Normalize Windows CRLF to LF to prevent length & delta calculation bugs in Quill
      final text = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

      final docLen = _quillController.document.length;
      var selection = _quillController.selection;

      // If selection is invalid, place cursor at the end of the document
      if (!selection.isValid || selection.baseOffset < 0) {
        final offset = (docLen > 1) ? docLen - 1 : 0;
        selection = TextSelection.collapsed(offset: offset);
        _quillController.updateSelection(selection, quill.ChangeSource.local);
      }

      final maxInsertIndex = (docLen > 1) ? docLen - 1 : 0;
      final start = selection.start.clamp(0, maxInsertIndex);
      final end = selection.end.clamp(0, maxInsertIndex);
      final replaceLen = (end > start) ? (end - start) : 0;

      // CRITICAL: Pass `null` as textSelection to avoid Quill's internal getPositionDelta()
      // which throws ArgumentError on multi-line text due to operation length mismatches.
      _quillController.replaceText(
        start,
        replaceLen,
        text,
        null,
      );

      // Manually set cursor position right after the newly pasted text
      final newCursor =
          (start + text.length).clamp(0, _quillController.document.length - 1);
      _quillController.updateSelection(
        TextSelection.collapsed(offset: newCursor),
        quill.ChangeSource.local,
      );

      _onContentChanged();
      if (mounted) {
        setState(() {});
      }
      return true;
    } catch (e, st) {
      debugPrint('Error pasting text: $e\n$st');
      return true;
    }
  }

  void _attachDocListener() {
    _quillSubscription?.cancel();
    _quillSubscription = _quillController.document.changes.listen((_) {
      _onContentChanged();
    });
  }

  void _onTitleChanged() {
    if (_isInitializing) return;
    _scheduleAutosave();
  }

  void _onContentChanged() {
    if (_isInitializing) return;
    _scheduleAutosave();
  }

  void _scheduleAutosave() {
    _hasUnsavedChanges = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
      _performSave();
    });
  }

  Future<void> _performSave() async {
    if (!_hasUnsavedChanges || !mounted) return;

    final repo = ref.read(notesRepositoryProvider);
    final title = _titleController.text;
    final content = TiptapQuillConverter.contentFromQuillDoc(_quillController.document);

    _saveStatusNotifier.value = SaveStatus.saving;

    try {
      if (_existingNote == null) {
        final newNote = Note(
          id: const Uuid().v4(),
          userId: repo.currentUserId,
          title: title,
          content: content,
          color: _selectedColorId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repo.createNote(newNote);
        _existingNote = newNote; // Keep reference for subsequent updates
      } else {
        final updatedNote = _existingNote!.copyWith(
          title: title,
          content: content,
          color: _selectedColorId,
          updatedAt: DateTime.now(),
        );
        await repo.updateNote(updatedNote);
        _existingNote = updatedNote;
      }

      _hasUnsavedChanges = false;
      if (mounted) {
        _saveStatusNotifier.value = SaveStatus.saved;
      }
      if (_existingNote != null) {
        await MultiWindowService.notifyMainWindowNoteChanged(_existingNote!.id);
      }
    } catch (e) {
      debugPrint('Autosave error: $e');
      if (mounted) {
        _saveStatusNotifier.value = SaveStatus.error;
      }
    }
  }

  Future<void> _handleColorChange(String newColorId) async {
    setState(() {
      _selectedColorId = newColorId;
      _hasUnsavedChanges = true;
    });
    // Immediately save color change
    await _performSave();
  }

  Future<void> _flushAndPop() async {
    _debounceTimer?.cancel();
    if (_hasUnsavedChanges || _existingNote == null) {
      _hasUnsavedChanges = true;
      await _performSave();
    }
    if (widget.isStandaloneWindow) {
      try {
        await windowManager.hide();
      } catch (_) {}
      if (widget.noteId != null) {
        MultiWindowService.notifyMainWindowClosed(widget.noteId!);
      }
      try {
        await windowManager.close();
      } catch (_) {}
      return;
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _loadNote() async {
    setState(() => _isLoading = true);
    _isInitializing = true;
    final repo = ref.read(notesRepositoryProvider);
    final note = await repo.getNoteById(widget.noteId!);
    
    if (note != null) {
      _existingNote = note;
      _titleController.text = note.title;
      _selectedColorId = note.color;
      if (note.content != null) {
        _quillController.document =
            TiptapQuillConverter.quillDocFromContent(note.content);
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      _saveStatusNotifier.value = SaveStatus.saved;
      _isInitializing = false;
      _attachDocListener();
    }
  }

  Future<void> _deleteNote() async {
    _debounceTimer?.cancel();
    _hasUnsavedChanges = false;
    final repo = ref.read(notesRepositoryProvider);
    if (_existingNote != null) {
      await repo.moveNoteToTrash(_existingNote!.id);
      await MultiWindowService.notifyMainWindowNoteChanged(_existingNote!.id);
    }
    if (widget.isStandaloneWindow) {
      try {
        await windowManager.hide();
      } catch (_) {}
      if (widget.noteId != null) {
        MultiWindowService.notifyMainWindowClosed(widget.noteId!);
      }
      try {
        await windowManager.close();
      } catch (_) {}
      return;
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildColorGrid(NoteColorDef activeColorDef) {
    // Exclude 'Default' so we only show the 7 unique distinct colors
    final displayColors = noteColors.where((c) => c.id != 'Default').toList();
    final activeThemeColor = activeColorDef.id == 'Charcoal' ? const Color(0xFF71717A) : activeColorDef.bg;

    return SizedBox(
      width: 250,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: displayColors.map((colorDef) {
          final isSelected = colorDef.id == _selectedColorId ||
              (_selectedColorId == 'Default' && colorDef.id == 'Yellow');
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(context).pop(); // close popup
                _handleColorChange(colorDef.id);
              },
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: colorDef.bg,
                  border: Border.all(
                    color: isSelected
                        ? (colorDef.id == activeColorDef.id ? Colors.white : activeThemeColor)
                        : (colorDef.id == 'Charcoal' ? const Color(0xFF71717A) : Colors.black54),
                    width: isSelected ? 2.5 : 1.5,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: (colorDef.id == activeColorDef.id ? Colors.white : activeThemeColor).withValues(alpha: 0.6),
                            blurRadius: 5,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        size: 18,
                        color: colorDef.text,
                      )
                    : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusIndicator(NoteColorDef colorDef) {
    return ValueListenableBuilder<SaveStatus>(
      valueListenable: _saveStatusNotifier,
      builder: (context, saveStatus, _) {
        if (saveStatus == SaveStatus.saving) {
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorDef.text,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Saving...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colorDef.text,
                  ),
                ),
              ],
            ),
          );
        } else if (saveStatus == SaveStatus.error) {
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Error',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          );
        } else {
          // Saved state
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 13,
                  color: colorDef.text.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 4),
                Text(
                  'Saved',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorDef.text.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  quill.DefaultStyles _buildQuillStyles(bool isDark) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF18181B);
    final secondaryTextColor = isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF27272A);
    final codeContainerBg = isDark ? const Color(0xFF22222B) : const Color(0xFFF0E5CF);
    final codeTextColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
    final inlineCodeBg = isDark ? const Color(0xFF2E2E3C) : const Color(0xFFE8DCBE);
    final inlineCodeText = isDark ? const Color(0xFFFDE047) : const Color(0xFFB45309);
    final quoteBg = isDark ? const Color(0xFF22222C) : const Color(0xFFF5ECDA);

    return quill.DefaultStyles(
      placeHolder: quill.DefaultTextBlockStyle(
        TextStyle(
          color: isDark ? Colors.white38 : Colors.black38,
          fontSize: 16,
          height: 1.4,
        ),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(2, 2),
        const quill.VerticalSpacing(0, 0),
        null,
      ),
      paragraph: quill.DefaultTextBlockStyle(
        TextStyle(
          color: primaryTextColor,
          fontSize: 16,
          height: 1.4,
        ),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(2, 2),
        const quill.VerticalSpacing(0, 0),
        null,
      ),
      h1: quill.DefaultTextBlockStyle(
        TextStyle(
          color: primaryTextColor,
          fontSize: 26,
          fontWeight: FontWeight.w900,
          height: 1.3,
        ),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(10, 4),
        const quill.VerticalSpacing(0, 0),
        null,
      ),
      h2: quill.DefaultTextBlockStyle(
        TextStyle(
          color: primaryTextColor,
          fontSize: 21,
          fontWeight: FontWeight.w800,
          height: 1.3,
        ),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(8, 3),
        const quill.VerticalSpacing(0, 0),
        null,
      ),
      h3: quill.DefaultTextBlockStyle(
        TextStyle(
          color: primaryTextColor,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(6, 2),
        const quill.VerticalSpacing(0, 0),
        null,
      ),
      // Code Block: Sleek Neobrutalist Container
      code: quill.DefaultTextBlockStyle(
        TextStyle(
          color: codeTextColor,
          fontFamily: 'monospace',
          fontSize: 14,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
        const quill.HorizontalSpacing(12, 12),
        const quill.VerticalSpacing(8, 8),
        const quill.VerticalSpacing(4, 4),
        BoxDecoration(
          color: codeContainerBg,
          border: Border.all(color: Colors.black, width: 2.2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(2.5, 2.5),
            ),
          ],
        ),
      ),
      // Inline Code: Monospace text with rounded badge
      inlineCode: quill.InlineCodeStyle(
        backgroundColor: inlineCodeBg,
        radius: const Radius.circular(5),
        style: TextStyle(
          color: inlineCodeText,
          fontFamily: 'monospace',
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      // Blockquote: Yellow accent bar with italic text
      quote: quill.DefaultTextBlockStyle(
        TextStyle(
          color: secondaryTextColor,
          fontSize: 15.5,
          fontStyle: FontStyle.italic,
          height: 1.35,
        ),
        const quill.HorizontalSpacing(12, 12),
        const quill.VerticalSpacing(6, 6),
        const quill.VerticalSpacing(0, 0),
        BoxDecoration(
          color: quoteBg,
          border: const Border(
            left: BorderSide(color: Color(0xFFE6B905), width: 4.5),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      lists: quill.DefaultListBlockStyle(
        TextStyle(
          color: primaryTextColor,
          fontSize: 16,
          height: 1.35,
        ),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(2, 2),
        const quill.VerticalSpacing(0, 0),
        null,
        null,
      ),
      leading: quill.DefaultTextBlockStyle(
        TextStyle(
          color: primaryTextColor,
          fontWeight: FontWeight.normal,
          fontSize: 16,
        ),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(0, 0),
        const quill.VerticalSpacing(0, 0),
        null,
      ),
    );
  }

  Widget _buildTopBar(NoteColorDef colorDef, bool isDark) {
    final menuBorderColor = colorDef.id == 'Charcoal' ? const Color(0xFF71717A) : colorDef.bg;
    final itemColor = isDark ? Colors.white : const Color(0xFF18181B);

    return DragToMoveArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: colorDef.bg,
          border: const Border(bottom: BorderSide(color: Colors.black, width: 4)),
        ),
        child: Row(
          children: [
            // Left: Back button (only for mobile/embedded navigation, hidden on floating sticky notes)
            if (!widget.isStandaloneWindow)
              NeoInteractive(
                onTap: _flushAndPop,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(0),
                  ),
                  child: Icon(Icons.arrow_back, color: colorDef.text, size: 22),
                ),
              ),

            // Left: New Note (+) button for floating sticky notes (ala Microsoft Sticky Notes)
            if (widget.isStandaloneWindow)
              Tooltip(
                message: 'New note (Ctrl+N)',
                waitDuration: const Duration(milliseconds: 400),
                child: NeoInteractive(
                  onTap: () async {
                    await MultiWindowService.createNewNoteFromSubWindow();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(0),
                    ),
                    child: Icon(Icons.add, color: colorDef.text, size: 22),
                  ),
                ),
              ),

            // Draggable Spacer across the top
            const Expanded(
              child: SizedBox(
                height: 38,
              ),
            ),

            // Right Action Controls
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Autosave Status Indicator
                _buildStatusIndicator(colorDef),
                const SizedBox(width: 4),

                // More options dropdown
                Theme(
                  data: Theme.of(context).copyWith(
                    splashColor: menuBorderColor.withValues(alpha: 0.15),
                    highlightColor: menuBorderColor.withValues(alpha: 0.1),
                    hoverColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                  child: PopupMenuButton<int>(
                    icon: Icon(Icons.more_horiz, color: colorDef.text, size: 26),
                    color: isDark ? const Color(0xFF18181B) : const Color(0xFFFFF4E0),
                    elevation: 8,
                    shadowColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: menuBorderColor, width: 3.5),
                    ),
                    offset: const Offset(0, 48),
                    onSelected: (value) async {
                      if (value == 1) {
                        setState(() => _showTitle = !_showTitle);
                      } else if (value == 2) {
                        // In Microsoft Sticky Notes, "Notes list" reveals and focuses the main window
                        await MultiWindowService.showMainWindow();
                      } else if (value == 3) {
                        _deleteNote();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        enabled: false,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: _buildColorGrid(colorDef),
                      ),
                      _NeoPopupDivider(color: menuBorderColor, thickness: 2),
                      PopupMenuItem(
                        value: 1,
                        child: Row(
                          children: [
                            Icon(_showTitle ? Icons.visibility_off : Icons.visibility, color: itemColor, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              _showTitle ? "Hide title" : "Show title",
                              style: NeoTheme.headingFont(color: itemColor, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 2,
                        child: Row(
                          children: [
                            Icon(Icons.list, color: itemColor, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              "Notes list",
                              style: NeoTheme.headingFont(color: itemColor, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 3,
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                            const SizedBox(width: 12),
                            Text(
                              "Move to Trash",
                              style: NeoTheme.headingFont(color: const Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 4),

                // Close Button (Tanda X di navbar)
                _HoverIconButton(
                  icon: Icons.close,
                  color: colorDef.text,
                  hoverColor: const Color(0xFFEF4444),
                  hoverIconColor: Colors.white,
                  tooltip: 'Close',
                  onTap: _flushAndPop,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorDef = getColorDef(_selectedColorId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Light mode canvas: #FFF4E0 (exact cream from user image 2), Dark mode: #18181B
    final canvasBg = isDark ? const Color(0xFF18181B) : const Color(0xFFFFF4E0);
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _flushAndPop();
      },
      child: Container(
        decoration: BoxDecoration(
          color: canvasBg,
          border: widget.isStandaloneWindow
              ? Border.all(color: Colors.black, width: 2.5)
              : null,
        ),
        child: DragToResizeArea(
          resizeEdgeSize: 6,
          child: Scaffold(
            backgroundColor: canvasBg,
            body: SafeArea(
              top: false,
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: isDark ? Colors.white : Colors.black))
              : Stack(
                  children: [
                    // Main column: Top bar + Scrollable content
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTopBar(colorDef, isDark),

                        // Scrollable content area: Title + Editor scroll together
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              if (!_editorFocusNode.hasFocus) {
                                _editorFocusNode.requestFocus();
                              }
                              final docLen = _quillController.document.length;
                              final offset = (docLen > 1) ? docLen - 1 : 0;
                              if (!_quillController.selection.isValid ||
                                  _quillController.selection.baseOffset < 0) {
                                _quillController.updateSelection(
                                  TextSelection.collapsed(offset: offset),
                                  quill.ChangeSource.local,
                                );
                              }
                            },
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Title (scrolls with content, NOT sticky)
                                  if (_showTitle)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                                      child: TextField(
                                        controller: _titleController,
                                        focusNode: _titleFocusNode,
                                        onSubmitted: (_) => _editorFocusNode.requestFocus(),
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: isDark ? Colors.white : Colors.black,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Note Title',
                                          hintStyle: TextStyle(
                                            color: isDark ? Colors.white54 : Colors.black38,
                                          ),
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    )
                                  else
                                    const SizedBox(height: 20.0),

                                  // Editor with Keyboard Shortcuts
                                  CallbackShortcuts(
                                    bindings: <ShortcutActivator, VoidCallback>{
                                      const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () =>
                                          NoteToolbarActions.undo(_quillController),
                                      const SingleActivator(LogicalKeyboardKey.keyY, control: true): () =>
                                          NoteToolbarActions.redo(_quillController),
                                      const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): () =>
                                          NoteToolbarActions.redo(_quillController),
                                      const SingleActivator(LogicalKeyboardKey.keyB, control: true): () =>
                                          NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.bold),
                                      const SingleActivator(LogicalKeyboardKey.keyI, control: true): () =>
                                          NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.italic),
                                      const SingleActivator(LogicalKeyboardKey.keyU, control: true): () =>
                                          NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.underline),
                                      const SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true): () =>
                                          NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.strikeThrough),
                                      const SingleActivator(LogicalKeyboardKey.keyH, control: true, shift: true): () =>
                                          NoteToolbarActions.toggleHighlight(_quillController),
                                      const SingleActivator(LogicalKeyboardKey.keyE, control: true): () =>
                                          NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.inlineCode),
                                      const SingleActivator(LogicalKeyboardKey.keyE, control: true, shift: true): () =>
                                          NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.inlineCode),
                                      const SingleActivator(LogicalKeyboardKey.keyC, control: true, shift: true): () =>
                                          NoteToolbarActions.toggleCheck(_quillController),
                                      const SingleActivator(LogicalKeyboardKey.digit8, control: true, shift: true): () =>
                                          NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.ul),
                                      const SingleActivator(LogicalKeyboardKey.digit7, control: true, shift: true): () =>
                                          NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.ol),
                                      const SingleActivator(LogicalKeyboardKey.keyQ, control: true, shift: true): () =>
                                          NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.blockQuote),
                                      const SingleActivator(LogicalKeyboardKey.digit9, control: true, shift: true): () =>
                                          NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.blockQuote),
                                      const SingleActivator(LogicalKeyboardKey.keyC, control: true, alt: true): () =>
                                          NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.codeBlock),
                                      const SingleActivator(LogicalKeyboardKey.keyK, control: true, shift: true): () =>
                                          NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.codeBlock),
                                      const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
                                          NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.h1),
                                      const SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
                                          NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.h2),
                                      const SingleActivator(LogicalKeyboardKey.digit3, control: true): () =>
                                          NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.h3),
                                      const SingleActivator(LogicalKeyboardKey.digit1, control: true, alt: true): () =>
                                          NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.h1),
                                      const SingleActivator(LogicalKeyboardKey.digit2, control: true, alt: true): () =>
                                          NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.h2),
                                      const SingleActivator(LogicalKeyboardKey.digit3, control: true, alt: true): () =>
                                          NoteToolbarActions.toggleAttribute(_quillController, quill.Attribute.h3),
                                      const SingleActivator(LogicalKeyboardKey.backslash, control: true): () =>
                                          NoteToolbarActions.clearFormatting(_quillController),
                                      const SingleActivator(LogicalKeyboardKey.space, control: true): () =>
                                          NoteToolbarActions.clearFormatting(_quillController),
                                      if (widget.isStandaloneWindow)
                                        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
                                            MultiWindowService.createNewNoteFromSubWindow(),
                                    },
                                    child: quill.QuillEditor.basic(
                                      controller: _quillController,
                                      focusNode: _editorFocusNode,
                                      scrollController: _editorScrollController,
                                      config: quill.QuillEditorConfig(
                                        scrollable: false,
                                        autoFocus: false,
                                        expands: false,
                                        padding: EdgeInsets.zero,
                                        placeholder: 'Start writing...',
                                        customActions: {
                                          PasteTextIntent: CallbackAction<PasteTextIntent>(
                                            onInvoke: (intent) {
                                              _handlePaste();
                                              return null;
                                            },
                                          ),
                                        },
                                        contextMenuBuilder: (context, rawEditorState) =>
                                            quill.QuillRawEditorConfig.defaultContextMenuBuilder(
                                          context,
                                          rawEditorState,
                                        ),
                                        customStyles: _buildQuillStyles(isDark),
                                      ),
                                    ),
                                  ),

                                  // Bottom padding so content isn't hidden behind floating toolbar
                                  const SizedBox(height: 100),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Floating Interactive Toggle Toolbar (Gambar 2 & 3 / MyNotes)
                    Positioned(
                      left: 20,
                      bottom: 20,
                      child: FloatingNoteToolbar(controller: _quillController),
                    ),
                  ],
                ),
        ),
          ),
        ),
      ),
    );
  }
}

/// Hover icon button for navbar (close button with red hover effect like Sticky Notes)
class _HoverIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color hoverColor;
  final Color hoverIconColor;
  final String tooltip;
  final VoidCallback onTap;

  const _HoverIconButton({
    required this.icon,
    required this.color,
    required this.hoverColor,
    required this.hoverIconColor,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _isHovered ? widget.hoverColor : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 20,
              color: _isHovered ? widget.hoverIconColor : widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

// Custom yellow divider for PopupMenu ("list kuning")
class _NeoPopupDivider extends PopupMenuEntry<Never> {
  final Color color;
  final double thickness;

  const _NeoPopupDivider({
    this.color = const Color(0xFFE6B905),
    this.thickness = 2.0,
  });

  @override
  double get height => thickness + 12.0;

  @override
  bool represents(void value) => false;

  @override
  State<_NeoPopupDivider> createState() => _NeoPopupDividerState();
}

class _NeoPopupDividerState extends State<_NeoPopupDivider> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Container(
        height: widget.thickness,
        color: widget.color,
      ),
    );
  }
}
