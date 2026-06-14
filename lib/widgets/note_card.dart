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
        NoteType.checklist => Icons.checklist_outlined,
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

  Widget? _trailing() {
    final icons = <Widget>[];
    if (note.isPinned) {
      icons.add(const Icon(Icons.push_pin, size: 14, color: Color(0xFF6B4FA0)));
    }
    if (note.expiresAt != null) {
      icons.add(const Icon(Icons.schedule, size: 14, color: Colors.grey));
    }
    if (icons.isEmpty) return null;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: icons,
    );
  }

  Widget _checklistPreview(String date) {
    final lines = note.content
        .split('\n')
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return Text(date);
    final total = lines.length;
    final done = lines.where((l) => l.startsWith('[x] ')).length;
    final preview = lines.take(2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...preview.map((line) {
          final checked = line.startsWith('[x] ');
          final text = checked
              ? line.substring(4)
              : line.startsWith('[ ] ')
                  ? line.substring(4)
                  : line;
          return Row(
            children: [
              Icon(
                checked ? Icons.check_box_outlined : Icons.check_box_outline_blank,
                size: 13,
                color: checked ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: checked ? Colors.grey : null,
                      decoration:
                          checked ? TextDecoration.lineThrough : null,
                    )),
              ),
            ],
          );
        }),
        Text('$done/$total · $date',
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final date = DateFormat.yMMMd(locale).format(note.createdAt);
    final Widget subtitle = note.type == NoteType.checklist
        ? _checklistPreview(date)
        : Text(
            note.content.isEmpty ? date : '${note.content}\n$date',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );
    return ListTile(
      onTap: onTap,
      leading: _leading(),
      title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle,
      trailing: _trailing(),
    );
  }
}
