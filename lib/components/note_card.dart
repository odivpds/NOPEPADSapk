import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      note.title.isNotEmpty ? note.title : 'Untitled',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (note.isPinned)
                    const Icon(Icons.push_pin, size: 16),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  // Extracting raw text from dynamic content if possible, or just fallback
                  _extractPlainText(note.content),
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat.yMMMd().format(note.updatedAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _extractPlainText(dynamic content) {
    if (content == null) return 'No content';
    // Usually rich text format is stored in Delta or HTML.
    // Assuming simple plain text extraction if it's a string,
    // otherwise placeholder for complex format.
    if (content is String) return content;
    return 'Rich Text Content';
  }
}
