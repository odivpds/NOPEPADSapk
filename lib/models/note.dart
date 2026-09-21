import 'dart:convert';

class Note {
  final String id;
  final String userId;
  final String title;
  final dynamic content; // Storing as dynamic (Map for Tiptap JSON or String)
  final String color;
  final bool isPinned;
  final bool isArchived;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced; // Track whether this note has been synced to cloud

  Note({
    required this.id,
    required this.userId,
    required this.title,
    this.content,
    this.color = 'Default',
    this.isPinned = false,
    this.isArchived = false,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
  });

  /// Create from Supabase JSON response
  factory Note.fromJson(Map<String, dynamic> json) {
    dynamic content = json['content'];
    if (content is String &&
        (content.trim().startsWith('{') || content.trim().startsWith('['))) {
      try {
        content = jsonDecode(content);
      } catch (_) {}
    }

    return Note(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? '',
      content: content,
      color: json['color'] as String? ?? 'Default',
      isPinned: json['is_pinned'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      isDeleted: json['is_deleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isSynced: true, // Data from cloud is already synced
    );
  }

  /// Create from SQLite row (booleans stored as integers)
  factory Note.fromSqlite(Map<String, dynamic> row) {
    dynamic content = row['content'];
    if (content is String &&
        (content.trim().startsWith('{') || content.trim().startsWith('['))) {
      try {
        content = jsonDecode(content);
      } catch (_) {}
    }

    return Note(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      title: row['title'] as String? ?? '',
      content: content,
      color: row['color'] as String? ?? 'Default',
      isPinned: (row['is_pinned'] as int? ?? 0) == 1,
      isArchived: (row['is_archived'] as int? ?? 0) == 1,
      isDeleted: (row['is_deleted'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      isSynced: (row['is_synced'] as int? ?? 0) == 1,
    );
  }

  /// Convert to Supabase JSON (for cloud operations)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'content': content,
      'color': color,
      'is_pinned': isPinned,
      'is_archived': isArchived,
      'is_deleted': isDeleted,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convert to SQLite map (booleans as integers, content serialized if Map/List)
  Map<String, dynamic> toSqlite() {
    dynamic sqliteContent = content;
    if (content != null && content is! String) {
      sqliteContent = jsonEncode(content);
    }

    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'content': sqliteContent,
      'color': color,
      'is_pinned': isPinned ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  Note copyWith({
    String? id,
    String? userId,
    String? title,
    dynamic content,
    String? color,
    bool? isPinned,
    bool? isArchived,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return Note(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      color: color ?? this.color,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
