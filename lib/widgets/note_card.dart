import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.note, this.onTap});
  final Note note;
  final VoidCallback? onTap;

  IconData get _icon => switch (note.type) {
        NoteType.photo => Icons.photo_camera_outlined,
        NoteType.voice => Icons.mic_outlined,
        NoteType.handwriting => Icons.draw_outlined,
        NoteType.text => Icons.edit_note_outlined,
      };

  static bool _isAudio(String path) => path.toLowerCase().endsWith('.m4a');

  Widget _leading() {
    final path = note.mediaPath;
    if (path != null) {
      if (_isAudio(path)) {
        return const CircleAvatar(child: Icon(Icons.graphic_eq));
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(path),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) =>
              CircleAvatar(child: Icon(_icon)),
        ),
      );
    }
    return CircleAvatar(child: Icon(_icon));
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final date = DateFormat.yMMMd(locale).format(note.createdAt);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: _leading(),
        title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          note.content.isEmpty ? date : '${note.content}\n$date',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}