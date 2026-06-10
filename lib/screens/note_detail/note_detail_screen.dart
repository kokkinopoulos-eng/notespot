import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../l10n/app_localizations.dart';
import '../../models/note.dart';
import '../../services/db_service.dart';
import '../../services/media_service.dart';

class NoteDetailScreen extends StatelessWidget {
  const NoteDetailScreen({super.key, required this.note});
  final Note note;

  String _typeLabel(AppLocalizations l10n) => switch (note.type) {
        NoteType.photo => l10n.photoNote,
        NoteType.voice => l10n.voiceNote,
        NoteType.handwriting => l10n.handwritingNote,
        NoteType.text => l10n.textNote,
      };

  Future<void> _share() async {
    final text = '${note.title}\n${note.content}';
    final path = note.mediaPath;
    if (path != null && File(path).existsSync()) {
      await Share.shareXFiles([XFile(path)], text: text);
    } else {
      await Share.share(text);
    }
  }

  Future<void> _delete(BuildContext context, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteConfirmTitle),
        content: Text(l10n.deleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DbService.instance.delete(note.id!);
    await MediaService.instance.deleteMedia(note.mediaPath);
    if (context.mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final date = DateFormat.yMMMd(locale).add_jm().format(note.createdAt);
    final hasImage = (note.type == NoteType.photo ||
            note.type == NoteType.handwriting) &&
        note.mediaPath != null &&
        File(note.mediaPath!).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: Text(note.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: l10n.share,
            onPressed: _share,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.delete,
            onPressed: () => _delete(context, l10n),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage) ...[
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        _FullscreenImage(path: note.mediaPath!),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(note.mediaPath!),
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Chip(label: Text(_typeLabel(l10n))),
                const SizedBox(width: 8),
                Text(date,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        )),
              ],
            ),
            if (note.content.isNotEmpty) ...[
              const SizedBox(height: 12),
              SelectableText(
                note.content,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FullscreenImage extends StatelessWidget {
  const _FullscreenImage({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.file(File(path)),
        ),
      ),
    );
  }
}