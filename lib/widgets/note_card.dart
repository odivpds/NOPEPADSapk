import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/note.dart';
import 'package:intl/intl.dart';

class NoteCard extends StatefulWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDown = _isHovered || _isPressed;
    final shadowOffset = isDown ? const Offset(2, 2) : const Offset(6, 6);
    final transform = isDown ? Matrix4.translationValues(4, 4, 0) : Matrix4.identity();

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
          duration: const Duration(milliseconds: 150),
          transform: transform,
          margin: const EdgeInsets.only(bottom: 24, right: 6), // Margin for shadow
          decoration: BoxDecoration(
            color: const Color(0xFF27272A),
            border: Border.all(color: Colors.black, width: 4),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black,
                offset: shadowOffset,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias, // Ensures inner containers respect borderRadius
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Section (Yellow)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: const BoxDecoration(
                  color: Color(0xFFFDE047), // Bright Yellow
                  border: Border(bottom: BorderSide(color: Colors.black, width: 4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.push_pin, size: 20, color: Colors.black),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.note.title.isNotEmpty ? widget.note.title : 'Untitled',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      DateFormat('d MMM, HH:mm').format(widget.note.updatedAt),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              // Body Section (Dark)
              if (widget.note.content != null)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: const Color(0xFF27272A), // Dark grey
                  child: Text(
                    _getPlainTextPreview(widget.note.content!),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPlainTextPreview(dynamic rawContent) {
    if (rawContent == null) return '';
    
    // Recursive function to extract all "text" or "insert" values from JSON
    String extractTextFromJson(dynamic node) {
      if (node is String) {
        return '';
      }
      if (node is List) {
        return node.map((e) => extractTextFromJson(e)).where((e) => e.isNotEmpty).join(' ');
      }
      if (node is Map) {
        String result = '';
        if (node.containsKey('text') && node['text'] is String) {
          result += node['text'] + ' ';
        } else if (node.containsKey('insert') && node['insert'] is String) {
          result += node['insert'] + ' ';
        }
        
        if (node.containsKey('content')) {
          result += extractTextFromJson(node['content']);
        } else {
          for (var value in node.values) {
            if (value is Map || value is List) {
              result += extractTextFromJson(value);
            }
          }
        }
        return result;
      }
      return '';
    }

    try {
      if (rawContent is String) {
        // If it looks like JSON, parse it first
        if (rawContent.trim().startsWith('{') || rawContent.trim().startsWith('[')) {
          final decoded = jsonDecode(rawContent);
          final extracted = extractTextFromJson(decoded).trim();
          if (extracted.isNotEmpty) return extracted.replaceAll('\n', ' ');
        }
        // Otherwise strip HTML
        return rawContent.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      } else {
        // It's already a Map or List (e.g. JSONB from Supabase)
        final extracted = extractTextFromJson(rawContent).trim();
        if (extracted.isNotEmpty) return extracted.replaceAll('\n', ' ');
      }
    } catch (_) {}

    // Fallback
    return rawContent.toString().replaceAll(RegExp(r'<[^>]*>'), '');
  }
}
