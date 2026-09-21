import 'package:flutter/material.dart';
import '../theme.dart';

class NotesSidebar extends StatefulWidget {
  final bool isOpen;
  final String currentTab;
  final ValueChanged<String> onTabChanged;
  final VoidCallback onClose;

  const NotesSidebar({
    super.key,
    required this.isOpen,
    required this.currentTab,
    required this.onTabChanged,
    required this.onClose,
  });

  @override
  State<NotesSidebar> createState() => _NotesSidebarState();
}

class _NotesSidebarState extends State<NotesSidebar> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Overlay
        if (widget.isOpen)
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              color: Colors.black54,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

        // Sidebar
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          left: widget.isOpen ? 0 : -300,
          top: 0,
          bottom: 0,
          width: 256, // w-64 is 256px
          child: Container(
            decoration: BoxDecoration(
              color: context.neoBackground,
              border: Border(
                right: BorderSide(
                  color: Colors.black,
                  width: widget.isOpen ? 4 : 0,
                ),
              ),
              boxShadow: widget.isOpen
                  ? const [
                      BoxShadow(
                        color: Colors.black,
                        offset: Offset(4, 0),
                      ),
                    ]
                  : [],
            ),
            padding: const EdgeInsets.only(top: 80, left: 16, right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SidebarTabItem(
                  id: 'active',
                  label: 'Notes',
                  icon: Icons.description,
                  isActive: widget.currentTab == 'active',
                  onTap: () {
                    widget.onTabChanged('active');
                    if (MediaQuery.of(context).size.width < 768) {
                      widget.onClose();
                    }
                  },
                ),
                _SidebarTabItem(
                  id: 'archive',
                  label: 'Archive',
                  icon: Icons.archive,
                  isActive: widget.currentTab == 'archive',
                  onTap: () {
                    widget.onTabChanged('archive');
                    if (MediaQuery.of(context).size.width < 768) {
                      widget.onClose();
                    }
                  },
                ),
                _SidebarTabItem(
                  id: 'trash',
                  label: 'Trash',
                  icon: Icons.delete,
                  isActive: widget.currentTab == 'trash',
                  onTap: () {
                    widget.onTabChanged('trash');
                    if (MediaQuery.of(context).size.width < 768) {
                      widget.onClose();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarTabItem extends StatefulWidget {
  final String id;
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarTabItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_SidebarTabItem> createState() => _SidebarTabItemState();
}

class _SidebarTabItemState extends State<_SidebarTabItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          transform: Matrix4.translationValues(
            widget.isActive ? 4 : (_isHovered ? -4 : 0),
            widget.isActive ? 4 : (_isHovered ? -4 : 0),
            0,
          ),
          decoration: BoxDecoration(
            color: widget.isActive ? const Color(0xFFFDE047) : Colors.white,
            border: Border.all(color: Colors.black, width: 4),
            boxShadow: widget.isActive
                ? []
                : [
                    BoxShadow(
                      color: Colors.black,
                      offset: _isHovered ? const Offset(6, 6) : const Offset(4, 4),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: Colors.black, size: 24),
              const SizedBox(width: 16),
              Text(
                widget.label.toUpperCase(),
                style: NeoTheme.headingFont(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}