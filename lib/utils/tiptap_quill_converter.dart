import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart' as quill;

/// Bidirectional converter between Tiptap (ProseMirror JSON) and Flutter Quill Delta
/// Ensures seamless synchronization between MyNotes (web app) and NOPEPADSmobile (Flutter).
class TiptapQuillConverter {
  /// Create a Flutter Quill Document from any content (Tiptap Map/JSON, Quill Delta List/JSON, or plain String)
  static quill.Document quillDocFromContent(dynamic rawContent) {
    if (rawContent == null) {
      return quill.Document();
    }

    // If it's a string, try to decode as JSON first
    dynamic parsed = rawContent;
    if (rawContent is String) {
      final trimmed = rawContent.trim();
      if ((trimmed.startsWith('{') || trimmed.startsWith('[')) &&
          (trimmed.endsWith('}') || trimmed.endsWith(']'))) {
        try {
          parsed = jsonDecode(trimmed);
        } catch (_) {
          parsed = rawContent;
        }
      }
    }

    // 1. Tiptap JSON document: { "type": "doc", "content": [...] }
    if (parsed is Map && parsed['type'] == 'doc') {
      try {
        final deltaOps = tiptapToDeltaOps(Map<String, dynamic>.from(parsed));
        return quill.Document.fromJson(deltaOps);
      } catch (e) {
        // Fallback: extract plain text if delta conversion fails
        final text = extractPlainText(parsed);
        return quill.Document()..insert(0, text.isNotEmpty ? text : '');
      }
    }

    // 2. Quill Delta list: [ { "insert": "..." }, ... ]
    if (parsed is List) {
      try {
        return quill.Document.fromJson(parsed);
      } catch (_) {}
    }

    // 3. Fallback: plain text
    final text = extractPlainText(parsed);
    if (text.isEmpty) {
      return quill.Document();
    }
    return quill.Document()..insert(0, text);
  }

  /// Convert a Flutter Quill Document to a Tiptap JSON document Map ({ "type": "doc", "content": [...] })
  static Map<String, dynamic> contentFromQuillDoc(quill.Document doc) {
    final deltaJson = doc.toDelta().toJson();
    return deltaOpsToTiptap(deltaJson);
  }

  /// Convert Tiptap JSON to Quill Delta operations list
  static List<dynamic> tiptapToDeltaOps(Map<String, dynamic> tiptapDoc) {
    final ops = <Map<String, dynamic>>[];

    void processInline(dynamic node) {
      if (node is! Map) return;
      final type = node['type'];
      if (type == 'text') {
        final text = node['text'] as String? ?? '';
        if (text.isEmpty) return;

        final attrs = <String, dynamic>{};
        final marks = node['marks'] as List?;
        if (marks != null) {
          for (final mark in marks) {
            if (mark is Map) {
              final mtype = mark['type'];
              if (mtype == 'bold') attrs['bold'] = true;
              if (mtype == 'italic') attrs['italic'] = true;
              if (mtype == 'underline') attrs['underline'] = true;
              if (mtype == 'strike') attrs['strike'] = true;
              if (mtype == 'code') attrs['code'] = true;
            }
          }
        }

        final op = <String, dynamic>{'insert': text};
        if (attrs.isNotEmpty) op['attributes'] = attrs;
        ops.add(op);
      } else if (type == 'hardBreak') {
        ops.add({'insert': '\n'});
      }
    }

    void processBlock(dynamic node) {
      if (node is! Map) return;
      final type = node['type'] as String?;
      final content = node['content'] as List?;

      if (type == 'doc') {
        if (content != null) {
          for (final child in content) {
            processBlock(child);
          }
        }
      } else if (type == 'paragraph') {
        if (content != null && content.isNotEmpty) {
          for (final inline in content) {
            processInline(inline);
          }
        }
        ops.add({'insert': '\n'});
      } else if (type == 'heading') {
        final level = (node['attrs'] as Map?)?['level'] as int? ?? 1;
        if (content != null && content.isNotEmpty) {
          for (final inline in content) {
            processInline(inline);
          }
        }
        ops.add({
          'insert': '\n',
          'attributes': {'header': level}
        });
      } else if (type == 'bulletList' || type == 'orderedList') {
        final isOrdered = type == 'orderedList';
        if (content != null) {
          for (final item in content) {
            if (item is Map && item['type'] == 'listItem') {
              final itemContent = item['content'] as List?;
              if (itemContent != null) {
                for (final subBlock in itemContent) {
                  if (subBlock is Map) {
                    final subInlines = subBlock['content'] as List?;
                    if (subInlines != null) {
                      for (final inline in subInlines) {
                        processInline(inline);
                      }
                    }
                    ops.add({
                      'insert': '\n',
                      'attributes': {'list': isOrdered ? 'ordered' : 'bullet'}
                    });
                  }
                }
              }
            }
          }
        }
      } else if (type == 'taskList') {
        if (content != null) {
          for (final item in content) {
            if (item is Map && item['type'] == 'taskItem') {
              final checked = (item['attrs'] as Map?)?['checked'] == true;
              final itemContent = item['content'] as List?;
              if (itemContent != null) {
                for (final subBlock in itemContent) {
                  if (subBlock is Map) {
                    final subInlines = subBlock['content'] as List?;
                    if (subInlines != null) {
                      for (final inline in subInlines) {
                        processInline(inline);
                      }
                    }
                    ops.add({
                      'insert': '\n',
                      'attributes': {'list': checked ? 'checked' : 'unchecked'}
                    });
                  }
                }
              }
            }
          }
        }
      } else if (type == 'codeBlock') {
        if (content != null) {
          for (final inline in content) {
            processInline(inline);
          }
        }
        ops.add({
          'insert': '\n',
          'attributes': {'code-block': true}
        });
      } else if (type == 'blockquote') {
        if (content != null) {
          for (final subBlock in content) {
            if (subBlock is Map) {
              final subInlines = subBlock['content'] as List?;
              if (subInlines != null) {
                for (final inline in subInlines) {
                  processInline(inline);
                }
              }
              ops.add({
                'insert': '\n',
                'attributes': {'blockquote': true}
              });
            }
          }
        }
      } else {
        // Unknown block: process content if any
        if (content != null) {
          for (final child in content) {
            processBlock(child);
          }
        }
      }
    }

    processBlock(tiptapDoc);

    if (ops.isEmpty) {
      ops.add({'insert': '\n'});
    } else {
      // Ensure the delta ends with a newline
      final last = ops.last['insert'];
      if (last is String && !last.endsWith('\n')) {
        ops.add({'insert': '\n'});
      }
    }

    return ops;
  }

  /// Convert Quill Delta operations list to Tiptap JSON document
  static Map<String, dynamic> deltaOpsToTiptap(List<dynamic> deltaOps) {
    final docContent = <Map<String, dynamic>>[];
    var currentInlines = <Map<String, dynamic>>[];

    for (final op in deltaOps) {
      if (op is! Map) continue;
      final insertVal = op['insert'];
      if (insertVal is! String) continue;

      final attrs = op['attributes'] as Map<String, dynamic>? ?? {};
      final lines = insertVal.split('\n');

      for (var i = 0; i < lines.length; i++) {
        final text = lines[i];
        if (text.isNotEmpty) {
          final marks = <Map<String, dynamic>>[];
          if (attrs['bold'] == true) marks.add({'type': 'bold'});
          if (attrs['italic'] == true) marks.add({'type': 'italic'});
          if (attrs['underline'] == true) marks.add({'type': 'underline'});
          if (attrs['strike'] == true) marks.add({'type': 'strike'});
          if (attrs['code'] == true) marks.add({'type': 'code'});

          final node = <String, dynamic>{
            'type': 'text',
            'text': text,
          };
          if (marks.isNotEmpty) {
            node['marks'] = marks;
          }
          currentInlines.add(node);
        }

        // When a newline occurs, it closes the current block
        if (i < lines.length - 1) {
          // Determine block type from attributes attached to the newline
          if (attrs.containsKey('header')) {
            final level = attrs['header'] is int
                ? attrs['header'] as int
                : int.tryParse(attrs['header'].toString()) ?? 1;
            final heading = <String, dynamic>{
              'type': 'heading',
              'attrs': {'level': level},
            };
            if (currentInlines.isNotEmpty) {
              heading['content'] = List<Map<String, dynamic>>.from(currentInlines);
            }
            docContent.add(heading);
          } else if (attrs['list'] == 'bullet') {
            final p = <String, dynamic>{'type': 'paragraph'};
            if (currentInlines.isNotEmpty) {
              p['content'] = List<Map<String, dynamic>>.from(currentInlines);
            }
            final listItem = {
              'type': 'listItem',
              'content': [p],
            };

            // Group into existing bulletList if previous block is bulletList
            if (docContent.isNotEmpty && docContent.last['type'] == 'bulletList') {
              (docContent.last['content'] as List).add(listItem);
            } else {
              docContent.add({
                'type': 'bulletList',
                'content': [listItem],
              });
            }
          } else if (attrs['list'] == 'ordered') {
            final p = <String, dynamic>{'type': 'paragraph'};
            if (currentInlines.isNotEmpty) {
              p['content'] = List<Map<String, dynamic>>.from(currentInlines);
            }
            final listItem = {
              'type': 'listItem',
              'content': [p],
            };

            if (docContent.isNotEmpty && docContent.last['type'] == 'orderedList') {
              (docContent.last['content'] as List).add(listItem);
            } else {
              docContent.add({
                'type': 'orderedList',
                'content': [listItem],
              });
            }
          } else if (attrs['list'] == 'checked' || attrs['list'] == 'unchecked') {
            final isChecked = attrs['list'] == 'checked';
            final p = <String, dynamic>{'type': 'paragraph'};
            if (currentInlines.isNotEmpty) {
              p['content'] = List<Map<String, dynamic>>.from(currentInlines);
            }
            final taskItem = {
              'type': 'taskItem',
              'attrs': {'checked': isChecked},
              'content': [p],
            };

            if (docContent.isNotEmpty && docContent.last['type'] == 'taskList') {
              (docContent.last['content'] as List).add(taskItem);
            } else {
              docContent.add({
                'type': 'taskList',
                'content': [taskItem],
              });
            }
          } else {
            // Standard paragraph
            final p = <String, dynamic>{'type': 'paragraph'};
            if (currentInlines.isNotEmpty) {
              p['content'] = List<Map<String, dynamic>>.from(currentInlines);
            }
            docContent.add(p);
          }

          currentInlines = [];
        }
      }
    }

    if (currentInlines.isNotEmpty) {
      docContent.add({
        'type': 'paragraph',
        'content': currentInlines,
      });
    }

    if (docContent.isEmpty) {
      docContent.add({'type': 'paragraph'});
    }

    return {
      'type': 'doc',
      'content': docContent,
    };
  }

  /// Extracts pure plain text from any content structure (Tiptap, Quill, String)
  static String extractPlainText(dynamic rawContent) {
    if (rawContent == null) return '';

    dynamic data = rawContent;
    if (rawContent is String) {
      final trimmed = rawContent.trim();
      if ((trimmed.startsWith('{') || trimmed.startsWith('[')) &&
          (trimmed.endsWith('}') || trimmed.endsWith(']'))) {
        try {
          data = jsonDecode(trimmed);
        } catch (_) {
          return rawContent.replaceAll(RegExp(r'<[^>]*>'), '').trim();
        }
      } else {
        return rawContent.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      }
    }

    String extract(dynamic node) {
      if (node == null) return '';
      if (node is String) return node;
      if (node is List) {
        return node.map(extract).where((s) => s.isNotEmpty).join(' ');
      }
      if (node is Map) {
        String result = '';
        if (node.containsKey('text') && node['text'] is String) {
          result += node['text'] + ' ';
        } else if (node.containsKey('insert') && node['insert'] is String) {
          result += node['insert'];
        }

        if (node.containsKey('content')) {
          result += extract(node['content']);
        }

        if (['paragraph', 'heading', 'listItem', 'taskItem'].contains(node['type'])) {
          result += ' ';
        }
        return result;
      }
      return '';
    }

    final result = extract(data).trim();
    // Normalize excessive newlines/spaces for clean previews
    return result;
  }
}
