import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../services/notes_repository.dart';
import '../services/sync_service.dart';
import '../services/multi_window_service.dart';
import '../main.dart';
import '../models/note.dart';
import '../widgets/onboarding_tour.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';
import '../widgets/motivational_quote.dart';
import '../widgets/note_card.dart';
import '../widgets/notes_sidebar.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/smooth_mouse_scroll.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NoteGroup {
  final String label;
  final List<Note> notes;
  _NoteGroup(this.label, this.notes);
}

List<_NoteGroup> _groupNotesByTime(List<Note> unpinnedNotes) {
  List<_NoteGroup> groups = [];
  for (var note in unpinnedNotes) {
    final date = note.updatedAt;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final noteDate = DateTime(date.year, date.month, date.day);

    final diffDays = today.difference(noteDate).inDays;

    String label = '';
    if (diffDays <= 0) {
      label = 'Today';
    } else if (diffDays == 1) {
      label = 'Yesterday';
    } else if (diffDays <= 7) {
      label = 'Previous 7 Days';
    } else if (diffDays <= 30) {
      label = 'Previous 30 Days';
    } else if (now.year == date.year) {
      label = DateFormat('MMMM').format(date);
    } else {
      label = date.year.toString();
    }

    if (groups.isNotEmpty && groups.last.label == label) {
      groups.last.notes.add(note);
    } else {
      groups.add(_NoteGroup(label, [note]));
    }
  }
  return groups;
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<Note> _notes = [];
  bool _isLoading = true;
  bool _isSidebarOpen = false;
  String _currentTab = 'active';
  bool _isSelectMode = false;
  final Set<String> _selectedNotes = {};
  String _searchQuery = '';

  // Tour Keys and State
  final GlobalKey _appTitleKey = GlobalKey();
  final GlobalKey _addNoteKey = GlobalKey();
  final GlobalKey _settingsKey = GlobalKey();
  final GlobalKey _notesGridKey = GlobalKey();

  bool _isTourActive = false;
  int _tourStep = 0;
  bool _hasCheckedTourInSession = false;

  List<TourStep> _buildTourSteps() => [
    const TourStep(
      content: "Welcome to NOPEPADS! Let's take a quick tour of your new Neobrutalist notebook.",
      placement: 'center',
    ),
    TourStep(
      targetKey: _appTitleKey,
      content: "This is your app title. You can customize this name in the settings!",
      placement: 'bottom',
    ),
    TourStep(
      targetKey: _addNoteKey,
      content: "Click here to create a new note and start writing.",
      placement: 'left',
    ),
    TourStep(
      targetKey: _settingsKey,
      content: "Customize your app name, theme (Light/Dark), and other preferences here.",
      placement: 'left',
    ),
    TourStep(
      targetKey: _notesGridKey,
      content: "Your notes will appear here. Enjoy your customized, markdown-powered NOPEPADS!",
      placement: 'center',
    ),
  ];

  void _startTour() {
    if (!mounted) return;
    setState(() {
      _tourStep = 0;
      _isTourActive = true;
    });
  }

  void _completeTour() async {
    if (mounted) {
      setState(() {
        _isTourActive = false;
      });
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool('tour_completed_${user.id}', true);
    }
  }

  void _checkTourStatusOnLoad() {
    if (_hasCheckedTourInSession) return;
    _hasCheckedTourInSession = true;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final prefs = ref.read(sharedPreferencesProvider);
    final hasSeenTour = prefs.getBool('tour_completed_${user.id}') ?? false;
    final createdAt = DateTime.tryParse(user.createdAt);
    final isOlderThan5Min = createdAt != null && DateTime.now().difference(createdAt).inMinutes > 5;
    final isReturningUser = _notes.isNotEmpty || isOlderThan5Min || hasSeenTour;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!isReturningUser && !hasSeenTour) {
        // New user: immediately show Step 1 of tour (Gambar 2)
        _startTour();
      } else if (isReturningUser) {
        // Returning user logging back in: show Welcome Back Decision Dialog (Gambar 3)
        final settings = ref.read(settingsProvider);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => WelcomeBackDecisionDialog(
            userName: settings.userName,
            onStartTour: () {
              Navigator.of(dialogCtx).pop();
              if (mounted) _startTour();
            },
            onDismiss: () {
              Navigator.of(dialogCtx).pop();
              _completeTour();
            },
          ),
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    ref.read(multiWindowServiceProvider).initMainWindowListener(
      onNotesRefresh: () {
        if (mounted) {
          _loadData();
        }
      },
      onCreateNote: () {
        if (mounted) {
          _createNote();
        }
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final repo = ref.read(notesRepositoryProvider);
      final notes = await repo.getNotes(tab: _currentTab);
      if (mounted) {
        setState(() {
          _notes = notes;
          _isLoading = false;
        });
        _checkTourStatusOnLoad();
      }

      // Sync in background if logged in
      ref.read(syncServiceProvider).trySyncInBackground().then((_) {
        if (mounted) {
          repo.getNotes(tab: _currentTab).then((updatedNotes) {
            if (mounted) setState(() => _notes = updatedNotes);
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _deleteNote(String id) async {
    try {
      final repo = ref.read(notesRepositoryProvider);
      if (_currentTab == 'trash') {
        await repo.deleteNotePermanently(id);
      } else {
        await repo.moveNoteToTrash(id);
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  bool _isCreatingNote = false;

  Future<void> _createNote() async {
    if (_isCreatingNote) return;
    _isCreatingNote = true;
    try {
      final repo = ref.read(notesRepositoryProvider);
      final newNote = Note(
        id: const Uuid().v4(),
        userId: repo.currentUserId,
        title: '',
        content: null,
        color: 'Yellow',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.createNote(newNote);
      _loadData();

      if (kIsWeb || (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)) {
        if (mounted) {
          Navigator.of(context)
              .pushNamed('/editor', arguments: newNote.id)
              .then((_) => _loadData());
        }
      } else {
        await ref.read(multiWindowServiceProvider).openStickyNote(newNote.id, title: 'Sticky Note');
      }
    } catch (e) {
      debugPrint('Error creating note: $e');
    } finally {
      _isCreatingNote = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = context;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 640;
    final isMobile = screenWidth < 640;
    final topSafeArea = MediaQuery.paddingOf(context).top;
    final bottomSafeArea = MediaQuery.paddingOf(context).bottom;

    double getGridWidth() {
      if (screenWidth >= 1600) return 660;
      if (screenWidth >= 1280) return 550;
      if (screenWidth >= 1024) return 460;
      if (screenWidth >= 768) return 390;
      if (screenWidth >= 640) return 330;
      return screenWidth;
    }

    final query = _searchQuery.trim().toLowerCase();
    final displayedNotes = query.isEmpty
        ? _notes
        : _notes.where((n) {
            final titleMatch = n.title.toLowerCase().contains(query);
            final contentMatch = (n.content != null && n.content.toString().toLowerCase().contains(query));
            return titleMatch || contentMatch;
          }).toList();

    return Scaffold(
      backgroundColor: theme.neoAppBg,
      body: Stack(
        children: [
          Column(
            children: [
              // Header (Golden Yellow in Light Mode, Dark Slate in Dark Mode)
              Container(
                padding: EdgeInsets.only(
                  left: isMobile ? 16 : 24,
                  right: isMobile ? 16 : 24,
                  top: 16 + topSafeArea,
                  bottom: 16,
                ),
                decoration: BoxDecoration(
                  color: theme.neoHeaderBg,
                  border: const Border(bottom: BorderSide(color: Colors.black, width: 4)),
                ),
                child: Row(
                  children: [
                    // Pixel font Title in White with black shadows (matching RAMA'S NOPEPADS)
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          key: _appTitleKey,
                          child: Text(
                            settings.appTitle,
                            style: NeoTheme.pixelFont(
                              fontSize: isMobile ? 18 : 22,
                              letterSpacing: isMobile ? 1.0 : 2.0,
                              color: Colors.white,
                              shadows: const [
                                Shadow(color: Colors.black, offset: Offset(3, 3)),
                                Shadow(color: Colors.black, offset: Offset(2, 2)),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Sync Status Indicator
                    Consumer(
                      builder: (context, ref, _) {
                        final status = ref.watch(syncStatusProvider);
                        final user = Supabase.instance.client.auth.currentUser;
                        if (user == null) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              border: Border.all(color: Colors.black, width: 2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cloud_off, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'OFFLINE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        IconData icon;
                        Color color;
                        String tooltip;
                        switch (status) {
                          case SyncStatus.synced:
                            icon = Icons.cloud_done;
                            color = Colors.greenAccent;
                            tooltip = 'Synced with cloud';
                            break;
                          case SyncStatus.syncing:
                            icon = Icons.sync;
                            color = Colors.blueAccent;
                            tooltip = 'Syncing...';
                            break;
                          case SyncStatus.offline:
                            icon = Icons.cloud_off;
                            color = Colors.orangeAccent;
                            tooltip = 'Offline - Tap to sync';
                            break;
                          case SyncStatus.error:
                            icon = Icons.sync_problem;
                            color = Colors.redAccent;
                            tooltip = 'Sync error - Tap to retry';
                            break;
                        }
                        return Tooltip(
                          message: tooltip,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () async {
                              await ref.read(syncServiceProvider).syncAll();
                              _loadData();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black, width: 2),
                              ),
                              child: status == SyncStatus.syncing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.blueAccent,
                                      ),
                                    )
                                  : Icon(icon, color: color, size: 16),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    // Settings Button
                    _HeaderIconButton(
                      key: _settingsKey,
                      icon: Icons.settings,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => SettingsDialog(
                            onReplayTour: _startTour,
                          ),
                        ).then((_) => _loadData());
                      },
                    ),
                    const SizedBox(width: 8),
                    // New Note Button (+)
                    _HeaderAddButton(
                      key: _addNoteKey,
                      onTap: _createNote,
                    ),
                  ],
                ),
              ),

              // Main Body
              Expanded(
                child: Row(
                  children: [
                    // Left Column (Notes Grid) with warm cream background in light mode
                    Container(
                      key: _notesGridKey,
                      width: getGridWidth(),
                      decoration: BoxDecoration(
                        color: theme.neoAppBg,
                        border: const Border(right: BorderSide(color: Colors.black, width: 4)),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16.0 : 24.0,
                        vertical: isMobile ? 16.0 : 24.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Search Bar
                          Row(
                            children: [
                              // Hamburger Menu Button (Golden yellow)
                              _MenuButton(
                                onTap: () {
                                  setState(() => _isSidebarOpen = true);
                                },
                              ),
                              const SizedBox(width: 12),
                              // Search Input Box (Pure White)
                              Expanded(
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: Colors.black, width: 4),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(left: 12.0, right: 8.0),
                                        child: Icon(Icons.search, color: Colors.black54, size: 22),
                                      ),
                                      Expanded(
                                        child: TextField(
                                          controller: _searchController,
                                          onChanged: (val) {
                                            setState(() => _searchQuery = val);
                                          },
                                          style: NeoTheme.sansFont(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'Search notes...',
                                            hintStyle: NeoTheme.sansFont(
                                              color: Colors.black45,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        ),
                                      ),
                                      if (_searchQuery.isNotEmpty)
                                        MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: GestureDetector(
                                            onTap: () {
                                              _searchController.clear();
                                              setState(() => _searchQuery = '');
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 8.0),
                                              child: Icon(Icons.close, size: 20, color: Colors.black54),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Notes List / Grid
                          Expanded(
                            child: _isLoading
                                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE6B905)))
                                : displayedNotes.isEmpty
                                    ? _buildEmptyState(context)
                                    : Builder(builder: (context) {
                                        final pinnedNotes = _currentTab == 'active'
                                            ? displayedNotes.where((n) => n.isPinned).toList()
                                            : <Note>[];
                                        final unpinnedNotes = _currentTab == 'active'
                                            ? displayedNotes.where((n) => !n.isPinned).toList()
                                            : displayedNotes;
                                        final groupedUnpinnedNotes = _groupNotesByTime(unpinnedNotes);

                                        return RawScrollbar(
                                          controller: _scrollController,
                                          thumbColor: const Color(0xFFE6B905),
                                          thickness: 14.0,
                                          trackVisibility: true,
                                          trackColor: context.isDark ? const Color(0xFF18181B) : const Color(0xFFE2E8F0),
                                          trackBorderColor: Colors.black,
                                          thumbVisibility: true,
                                          shape: RoundedRectangleBorder(
                                            side: const BorderSide(color: Colors.black, width: 4),
                                            borderRadius: BorderRadius.circular(0),
                                          ),
                                          child: ListView(
                                            controller: _scrollController,
                                            padding: EdgeInsets.only(bottom: 80 + bottomSafeArea, right: 16),
                                            children: [
                                              SmoothMouseScroll(
                                                controller: _scrollController,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                                  children: [
                                                    if (pinnedNotes.isNotEmpty) ...[
                                                      _buildSectionHeader('Pinned'),
                                                      const SizedBox(height: 12),
                                                      ...pinnedNotes.map((note) => _buildNoteCardWidget(note, settings)),
                                                      const SizedBox(height: 20),
                                                    ],
                                                    ...groupedUnpinnedNotes.map((group) {
                                                      return Column(
                                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                                        children: [
                                                          _buildSectionHeader(group.label),
                                                          const SizedBox(height: 12),
                                                          ...group.notes.map((note) => _buildNoteCardWidget(note, settings)),
                                                          const SizedBox(height: 20),
                                                        ],
                                                      );
                                                    }),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                          ),
                        ],
                      ),
                    ),

                    // Right Column (Motivational Quote) on warm cream background
                    if (isDesktop)
                      Expanded(
                        child: Container(
                          color: theme.neoAppBg,
                          padding: const EdgeInsets.all(48.0),
                          child: Center(
                            child: MotivationalQuote(userName: settings.userName),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Floating Select Mode Action Bar (Bottom Center)
          if (_isSelectMode)
            Positioned(
              bottom: 24 + bottomSafeArea,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6B905),
                    border: Border.all(color: Colors.black, width: 4),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(8, 8))],
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_selectedNotes.length} selected',
                          style: NeoTheme.headingFont(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Select All / Deselect All Button
                        MouseRegion(
                          cursor: displayedNotes.isEmpty ? SystemMouseCursors.basic : SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              if (displayedNotes.isEmpty) return;
                              setState(() {
                                final allSelected = displayedNotes.every((n) => _selectedNotes.contains(n.id));
                                if (allSelected) {
                                  for (final n in displayedNotes) {
                                    _selectedNotes.remove(n.id);
                                  }
                                } else {
                                  _selectedNotes.addAll(displayedNotes.map((n) => n.id));
                                }
                              });
                            },
                            child: Opacity(
                              opacity: displayedNotes.isEmpty ? 0.5 : 1.0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.black, width: 2),
                                  boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
                                ),
                                child: Text(
                                  (displayedNotes.isNotEmpty &&
                                          displayedNotes.every((n) => _selectedNotes.contains(n.id)))
                                      ? 'DESELECT ALL'
                                      : 'SELECT ALL',
                                  style: NeoTheme.headingFont(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Cancel Button
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isSelectMode = false;
                                _selectedNotes.clear();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.black, width: 2),
                                boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
                              ),
                              child: Text(
                                'CANCEL',
                                style: NeoTheme.headingFont(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      // Trash / Delete Forever Button
                      MouseRegion(
                        cursor: _selectedNotes.isEmpty ? SystemMouseCursors.basic : SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () async {
                            if (_selectedNotes.isEmpty) return;
                            setState(() => _isLoading = true);
                            final repo = ref.read(notesRepositoryProvider);
                            for (final noteId in _selectedNotes) {
                              if (_currentTab == 'trash') {
                                await repo.deleteNotePermanently(noteId);
                              } else {
                                await repo.moveNoteToTrash(noteId);
                              }
                            }
                            if (!mounted) return;
                            setState(() {
                              _isSelectMode = false;
                              _selectedNotes.clear();
                            });
                            _loadData();
                          },
                          child: Opacity(
                            opacity: _selectedNotes.isEmpty ? 0.5 : 1.0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                border: Border.all(color: Colors.black, width: 2),
                                boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
                              ),
                              child: Text(
                                _isLoading
                                    ? 'PROCESSING...'
                                    : (_currentTab == 'trash' ? 'DELETE 4EVER' : 'TRASH'),
                                style: NeoTheme.headingFont(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Sidebar Navigation Drawer
          NotesSidebar(
            isOpen: _isSidebarOpen,
            currentTab: _currentTab,
            onTabChanged: (tab) {
              setState(() {
                _currentTab = tab;
                _isLoading = true;
                _isSelectMode = false;
                _selectedNotes.clear();
              });
              _loadData();
            },
            onClose: () {
              setState(() {
                _isSidebarOpen = false;
              });
            },
          ),

          // Onboarding Tour Overlay
          if (_isTourActive)
            OnboardingTourOverlay(
              currentStep: _tourStep,
              steps: _buildTourSteps(),
              onNext: () {
                if (!mounted) return;
                if (_tourStep < _buildTourSteps().length - 1) {
                  setState(() => _tourStep++);
                } else {
                  _completeTour();
                }
              },
              onBack: () {
                if (!mounted) return;
                if (_tourStep > 0) {
                  setState(() => _tourStep--);
                }
              },
              onSkip: _completeTour,
              onClose: _completeTour,
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black, width: 4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: NeoTheme.headingFont(
              color: context.isDark ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              fontSize: 13,
            ),
          ),
          if (!_isSelectMode)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isSelectMode = true;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6B905),
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'SELECT',
                    style: NeoTheme.headingFont(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNoteCardWidget(Note note, SettingsState settings) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: NoteCard(
        note: note,
        tab: _currentTab,
        isSelectMode: _isSelectMode,
        isSelected: _selectedNotes.contains(note.id),
        onToggleSelect: () {
          setState(() {
            if (_selectedNotes.contains(note.id)) {
              _selectedNotes.remove(note.id);
            } else {
              _selectedNotes.add(note.id);
            }
          });
        },
        onTap: () {
          if (kIsWeb || (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)) {
            Navigator.of(context).pushNamed('/editor', arguments: note.id).then((_) => _loadData());
          } else {
            ref.read(multiWindowServiceProvider).openStickyNote(note.id, title: note.title);
          }
        },
        onTogglePin: () async {
          await ref.read(notesRepositoryProvider).togglePin(note.id, !note.isPinned);
          _loadData();
        },
        onToggleArchive: () async {
          await ref.read(notesRepositoryProvider).toggleArchive(note.id, !note.isArchived);
          _loadData();
        },
        onRestore: () async {
          await ref.read(notesRepositoryProvider).restoreNote(note.id);
          _loadData();
        },
        onDelete: () {
          if (settings.confirmBeforeDelete) {
            showDialog(
              context: context,
              builder: (BuildContext ctx) {
                return Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.all(16),
                  child: Container(
                    width: 420,
                    decoration: BoxDecoration(
                      color: context.neoAppBg,
                      border: Border.all(color: Colors.black, width: 4),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(8, 8))],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.isDeleted ? 'DELETE 4EVER?' : 'TRASH NOTE?',
                          style: TextStyle(
                            color: context.neoText,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          note.isDeleted
                              ? 'Are you sure you want to permanently delete "${note.title.isNotEmpty ? note.title : 'Untitled'}"? This cannot be undone.'
                              : 'Move "${note.title.isNotEmpty ? note.title : 'Untitled'}" to Trash?',
                          style: TextStyle(
                            color: context.neoTextMuted,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => Navigator.of(ctx).pop(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: context.isDark ? const Color(0xFF27272A) : Colors.white,
                                    border: Border.all(color: Colors.black, width: 2),
                                    boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
                                  ),
                                  child: Text(
                                    'CANCEL',
                                    style: TextStyle(
                                      color: context.neoText,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  _deleteNote(note.id);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    border: Border.all(color: Colors.black, width: 2),
                                    boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
                                  ),
                                  child: Text(
                                    note.isDeleted ? 'DELETE 4EVER' : 'YES, TRASH IT',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          } else {
            _deleteNote(note.id);
          }
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isTrash = _currentTab == 'trash';
    final isArchive = _currentTab == 'archive';

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        padding: const EdgeInsets.all(28.0),
        decoration: BoxDecoration(
          color: const Color(0xFFE6B905),
          border: Border.all(color: Colors.black, width: 4),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(8, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isTrash
                  ? 'TRASH IS EMPTY'
                  : isArchive
                      ? 'ARCHIVE IS EMPTY'
                      : 'NO NOTES YET',
              style: NeoTheme.headingFont(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isTrash
                  ? 'Nothing here. So clean!'
                  : isArchive
                      ? 'Nothing tucked away yet.'
                      : "Your brain is empty. Let's fix that.",
              style: NeoTheme.sansFont(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (!isTrash && !isArchive) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
                ),
                child: Text(
                  'Click "+" in the header to begin',
                  style: NeoTheme.sansFont(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({super.key, required this.icon, required this.onTap});

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDown = _isHovered || _isPressed;
    final bg = context.isDark ? const Color(0xFF2A2A35) : Colors.white;
    final fg = context.isDark ? Colors.white : Colors.black;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          transform: isDown ? Matrix4.translationValues(2, 2, 0) : Matrix4.identity(),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: Colors.black, width: 2),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black,
                offset: isDown ? const Offset(0, 0) : const Offset(4, 4),
              ),
            ],
          ),
          child: Icon(widget.icon, color: fg, size: 20),
        ),
      ),
    );
  }
}

class _HeaderAddButton extends StatefulWidget {
  final VoidCallback onTap;

  const _HeaderAddButton({super.key, required this.onTap});

  @override
  State<_HeaderAddButton> createState() => _HeaderAddButtonState();
}

class _HeaderAddButtonState extends State<_HeaderAddButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDown = _isHovered || _isPressed;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          transform: isDown ? Matrix4.translationValues(2, 2, 0) : Matrix4.identity(),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFE6B905),
            border: Border.all(color: Colors.black, width: 2),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black,
                offset: isDown ? const Offset(0, 0) : const Offset(4, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.black, size: 22),
        ),
      ),
    );
  }
}

class _MenuButton extends StatefulWidget {
  final VoidCallback onTap;

  const _MenuButton({required this.onTap});

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDown = _isHovered || _isPressed;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          transform: isDown ? Matrix4.translationValues(3, 3, 0) : Matrix4.identity(),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFE6B905),
            border: Border.all(color: Colors.black, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black,
                offset: isDown ? const Offset(0, 0) : const Offset(4, 4),
              ),
            ],
          ),
          child: const Icon(Icons.menu, color: Colors.black),
        ),
      ),
    );
  }
}