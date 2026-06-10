import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/category_labels.dart';
import '../../l10n/app_localizations.dart';
import '../../models/note.dart';
import '../../services/db_service.dart';
import '../../services/media_service.dart';

// --- Edit dialog (pure StatefulWidget) ---

class _EditNoteDialog extends StatefulWidget {
  const _EditNoteDialog({required this.title, required this.content});
  final String title;
  final String content;

  @override
  State<_EditNoteDialog> createState() => _EditNoteDialogState();
}

class _EditNoteDialogState extends State<_EditNoteDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.title);
    _contentCtrl = TextEditingController(text: widget.content);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.edit),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.titleLabel),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentCtrl,
            maxLines: 6,
            decoration: InputDecoration(labelText: l10n.contentLabel),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            (_titleCtrl.text.trim(), _contentCtrl.text.trim()),
          ),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

// --- NoteDetailScreen ---

class NoteDetailScreen extends StatefulWidget {
  const NoteDetailScreen({super.key, required this.note});
  final Note note;

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  late Note _note;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
  }

  String _typeLabel(AppLocalizations l10n) => switch (_note.type) {
        NoteType.photo => l10n.photoNote,
        NoteType.voice => l10n.voiceNote,
        NoteType.handwriting => l10n.handwritingNote,
        NoteType.text => l10n.textNote,
      };

  Future<void> _share() async {
    final text = '${_note.title}\n${_note.content}';
    final path = _note.mediaPath;
    if (path != null && File(path).existsSync()) {
      await Share.shareXFiles([XFile(path)], text: text);
    } else {
      await Share.share(text);
    }
  }

  Future<void> _edit(AppLocalizations l10n) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) =>
          _EditNoteDialog(title: _note.title, content: _note.content),
    );
    if (result == null || !mounted) return;
    final (newTitle, newContent) = result;
    if (newTitle.isEmpty) return;
    final updated = Note(
      id: _note.id,
      type: _note.type,
      title: newTitle,
      content: newContent,
      category: _note.category,
      tags: _note.tags,
      mediaPath: _note.mediaPath,
      createdAt: _note.createdAt,
      updatedAt: DateTime.now(),
    );
    await DbService.instance.update(updated);
    if (!mounted) return;
    setState(() => _note = updated);
  }

  Future<void> _delete(AppLocalizations l10n) async {
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
    await DbService.instance.delete(_note.id!);
    await MediaService.instance.deleteMedia(_note.mediaPath);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final date = DateFormat.yMMMd(locale).add_jm().format(_note.createdAt);
    final hasImage = (_note.type == NoteType.photo ||
            _note.type == NoteType.handwriting) &&
        _note.mediaPath != null &&
        File(_note.mediaPath!).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _note.title,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.edit,
            onPressed: () => _edit(l10n),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: l10n.share,
            onPressed: _share,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.delete,
            onPressed: () => _delete(l10n),
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
                        _FullscreenImage(path: _note.mediaPath!),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_note.mediaPath!),
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              date,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Chip(label: Text(_typeLabel(l10n))),
                if (_note.category.isNotEmpty)
                  Chip(
                    label: Text(localizedCategory(l10n, _note.category)),
                    avatar: const Icon(Icons.folder_outlined, size: 16),
                  ),
                ..._note.tags.map((t) => Chip(
                      label: Text(t),
                      visualDensity: VisualDensity.compact,
                    )),
              ],
            ),
            if (_note.content.isNotEmpty) ...[
              const SizedBox(height: 12),
              SelectableText(
                _note.content,
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