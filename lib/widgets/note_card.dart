import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../theme.dart';
import '../utils/note_colors.dart';
import '../utils/tiptap_quill_converter.dart';

class NoteCard extends StatefulWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Future<void> Function()? onTogglePin;
  final Future<void> Function()? onToggleArchive;
  final Future<void> Function()? onRestore;
  final String tab;
  final bool isSelectMode;
  final bool isSelected;
  final VoidCallback? onToggleSelect;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
    this.onTogglePin,
    this.onToggleArchive,
    this.onRestore,
    this.tab = 'active',
    this.isSelectMode = false,
    this.isSelected = false,
    this.onToggleSelect,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  bool _isHovered = false;
  bool _isPressed = false;
  bool _isMenuOpen = false;

  @override
  Widget build(BuildContext context) {
    final isDown = _isHovered || _isPressed;
    final shadowOffset = isDown ? const Offset(0, 0) : const Offset(6, 6);
    final transform = isDown ? Matrix4.translationValues(6, 6, 0) : Matrix4.identity();
    final isTrash = widget.note.isDeleted;
    final isArchived = widget.note.isArchived;
    final colorDef = getColorDef(widget.note.color);

    final cardBg = context.isDark ? const Color(0xFF2A2A35) : Colors.white;
    final textFg = context.isDark ? Colors.white : Colors.black;
    final bool isMobile = !kIsWeb && (Platform.isIOS || Platform.isAndroid) || MediaQuery.of(context).size.width < 768;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          if (widget.isSelectMode && widget.onToggleSelect != null) {
            widget.onToggleSelect!();
            return;
          }
          if (widget.note.isDeleted) return;
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        onLongPress: () {
          setState(() => _isPressed = false);
          if (widget.isSelectMode && widget.onToggleSelect != null) {
            widget.onToggleSelect!();
            return;
          }
          _showNoteMenu(context);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          transform: transform,
          decoration: BoxDecoration(
            color: cardBg,
            border: Border.all(
              color: Colors.black,
              width: widget.isSelectMode && widget.isSelected ? 6 : 4,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black, offset: shadowOffset),
            ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: colorDef.bg,
                      border: const Border(bottom: BorderSide(color: Colors.black, width: 4)),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (widget.note.isPinned && !isTrash && !isArchived)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Transform.rotate(
                              angle: 0.785,
                              child: Icon(Icons.push_pin, size: 16, color: colorDef.text),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            widget.note.title.isNotEmpty ? widget.note.title : 'Untitled',
                            style: NeoTheme.headingFont(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: colorDef.text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.isSelectMode)
                          const SizedBox(width: 32)
                        else if (isMobile)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('d MMM, HH:mm').format(widget.note.updatedAt),
                                style: NeoTheme.sansFont(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: colorDef.text.withValues(alpha: 0.75),
                                ),
                              ),
                              const SizedBox(width: 4),
                              _buildMenuButton(context, colorDef.text),
                            ],
                          )
                        else
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 150),
                            crossFadeState: (_isHovered || _isMenuOpen)
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            firstChild: Text(
                              DateFormat('d MMM, HH:mm').format(widget.note.updatedAt),
                              style: NeoTheme.sansFont(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: colorDef.text.withValues(alpha: 0.7),
                              ),
                            ),
                            secondChild: _buildMenuButton(context, colorDef.text),
                          ),
                      ],
                    ),
                  ),
                  // Body
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: Text(
                      widget.note.content != null
                          ? (_getPlainTextPreview(widget.note.content!).isEmpty
                              ? 'Empty note'
                              : _getPlainTextPreview(widget.note.content!))
                          : 'Empty note',
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: NeoTheme.sansFont(
                        fontSize: 13,
                        color: (widget.note.content != null &&
                                _getPlainTextPreview(widget.note.content!).isNotEmpty)
                            ? textFg
                            : textFg.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              // Selection circle (top-right, like MyNotes)
              if (widget.isSelectMode)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: widget.isSelected ? Colors.black : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 3),
                      boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
                    ),
                    child: widget.isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, Color iconColor) {
    return Semantics(
      label: 'Note options',
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (_) {
            // Prevent outer card from triggering press state
          },
          onTap: () => _showNoteMenu(context),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(Icons.more_horiz, size: 22, color: iconColor),
          ),
        ),
      ),
    );
  }

  void _showNoteMenu(BuildContext context) {
    final isTrash = widget.note.isDeleted;
    final isArchived = widget.note.isArchived;
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final Offset buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);

    setState(() => _isMenuOpen = true);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(
          buttonPosition.dx + button.size.width - 200,
          buttonPosition.dy + 44,
          200,
          0,
        ),
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black, width: 4),
      ),
      color: context.isDark ? const Color(0xFF27272A) : Colors.white,
      elevation: 6,
      shadowColor: Colors.black,
      items: [
        if (!isTrash)
          _buildPopupItem(
            value: 'open',
            icon: Icons.open_in_new,
            iconColor: context.neoText,
            text: 'Open Note',
            textColor: context.neoText,
          ),
        if (!isTrash && !isArchived)
          _buildPopupItem(
            value: 'pin',
            icon: widget.note.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
            iconColor: context.neoText,
            text: widget.note.isPinned ? 'Unpin Note' : 'Pin Note',
            textColor: context.neoText,
          ),
        if (!isTrash)
          _buildPopupItem(
            value: 'archive',
            icon: Icons.archive_outlined,
            iconColor: context.neoText,
            text: isArchived ? 'Unarchive' : 'Archive Note',
            textColor: context.neoText,
          ),
        if (isTrash)
          _buildPopupItem(
            value: 'restore',
            icon: Icons.undo,
            iconColor: Colors.green,
            text: 'Restore Note',
            textColor: Colors.green,
          ),
        _buildPopupItem(
          value: 'trash',
          icon: Icons.delete_outline,
          iconColor: Colors.red,
          text: isTrash ? 'Delete 4ever' : 'Trash Note',
          textColor: Colors.red,
        ),
      ],
    ).then((value) {
      if (mounted) setState(() => _isMenuOpen = false);
      if (value == null) return;
      switch (value) {
        case 'open':
          widget.onTap();
          break;
        case 'pin':
          widget.onTogglePin?.call();
          break;
        case 'archive':
          widget.onToggleArchive?.call();
          break;
        case 'restore':
          widget.onRestore?.call();
          break;
        case 'trash':
          widget.onDelete();
          break;
      }
    });
  }

  PopupMenuItem<String> _buildPopupItem({
    required String value,
    required IconData icon,
    required Color iconColor,
    required String text,
    required Color textColor,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 12),
            Text(
              text,
              style: NeoTheme.headingFont(fontWeight: FontWeight.bold, color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  String _getPlainTextPreview(dynamic rawContent) {
    return TiptapQuillConverter.extractPlainText(rawContent);
  }
}