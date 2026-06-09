enum NoteType { photo, voice, handwriting, text }

class Note {
  const Note({
    this.id,
    required this.type,
    required this.title,
    this.content = '',
    this.category = '',
    this.tags = const [],
    this.mediaPath,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final NoteType type;
  final String title;
  final String content;
  final String category;
  final List<String> tags;
  final String? mediaPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note copyWith({
    int? id,
    NoteType? type,
    String? title,
    String? content,
    String? category,
    List<String>? tags,
    String? mediaPath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      mediaPath: mediaPath ?? this.mediaPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'title': title,
        'content': content,
        'category': category,
        'tags': tags.join(','),
        'media_path': mediaPath,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory Note.fromMap(Map<String, dynamic> map) => Note(
        id: map['id'] as int?,
        type: NoteType.values.byName(map['type'] as String),
        title: map['title'] as String,
        content: (map['content'] as String?) ?? '',
        category: (map['category'] as String?) ?? '',
        tags: ((map['tags'] as String?) ?? '')
            .split(',')
            .where((t) => t.isNotEmpty)
            .toList(),
        mediaPath: map['media_path'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      );
}