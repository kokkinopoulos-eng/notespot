import 'package:flutter/material.dart';

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
    this.isFavorite = false,
    this.canvasBg = const Color(0xFF000000),
    this.ocrText = '',
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
  final bool isFavorite;
  final Color canvasBg;
  final String ocrText;
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
    bool? isFavorite,
    Color? canvasBg,
    String? ocrText,
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
      isFavorite: isFavorite ?? this.isFavorite,
      canvasBg: canvasBg ?? this.canvasBg,
      ocrText: ocrText ?? this.ocrText,
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
        'is_favorite': isFavorite ? 1 : 0,
        'canvas_bg': canvasBg.value,
        'ocr_text': ocrText,
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
        isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
        canvasBg: Color(map['canvas_bg'] as int? ?? 0xFFFFFFFF),
        ocrText: (map['ocr_text'] as String?) ?? '',
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      );
}
