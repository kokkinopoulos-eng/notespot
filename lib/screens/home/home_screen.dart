import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../models/note.dart';
import '../../services/db_service.dart';
import '../../services/media_service.dart';
import '../../widgets/note_card.dart';
import '../capture/voice_capture_screen.dart';
import '../note_detail/note_detail_screen.dart';
import 'search_tab.dart';
import 'settings_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notes = await DbService.instance.getAll();
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  Future<void> _openCaptureSheet() async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.photoNote),
              onTap: () {
                Navigator.pop(sheetContext);
                _addMediaNote(NoteType.photo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic_outlined),
              title: Text(l10n.voiceNote),
              onTap: () {
                Navigator.pop(sheetContext);
                _addVoiceNote();
              },
            ),
            ListTile(
              leading: const Icon(Icons.draw_outlined),
              title: Text(l10n.handwritingNote),
              onTap: () {
                Navigator.pop(sheetContext);
                _addMediaNote(NoteType.handwriting);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note_outlined),
              title: Text(l10n.textNote),
              onTap: () {
                Navigator.pop(sheetContext);
                _addTextNote();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addVoiceNote() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const VoiceCaptureScreen()),
    );
    if (saved == true) await _loadNotes();
  }

  Future<void> _addMediaNote(NoteType type) async {
    final l10n = AppLocalizations.of(context);
    final path = await MediaService.instance.capturePhoto();
    if (path == null || !mounted) return;

    final defaultTitle =
        type == NoteType.photo ? l10n.photoNote : l10n.handwritingNote;
    final stamp = DateFormat('d/M HH:mm').format(DateTime.now());
    final titleCtrl = TextEditingController(text: '$defaultTitle $stamp');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.newNote),
        scrollable: true,
        content: TextField(
          controller: titleCtrl,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.titleLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (saved == true && titleCtrl.text.trim().isNotEmpty) {
      final now = DateTime.now();
      await DbService.instance.insert(Note(
        type: type,
        title: titleCtrl.text.trim(),
        mediaPath: path,
        createdAt: now,
        updatedAt: now,
      ));
      await _loadNotes();
    } else {
      await MediaService.instance.deleteMedia(path);
    }
    titleCtrl.dispose();
  }

  Future<void> _addTextNote() async {
    final l10n = AppLocalizations.of(context);
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.newNote),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.titleLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentCtrl,
              maxLines: 4,
              decoration: InputDecoration(labelText: l10n.contentLabel),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (saved == true && titleCtrl.text.trim().isNotEmpty) {
      final now = DateTime.now();
      await DbService.instance.insert(Note(
        type: NoteType.text,
        title: titleCtrl.text.trim(),
        content: contentCtrl.text.trim(),
        createdAt: now,
        updatedAt: now,
      ));
      await _loadNotes();
    }
    titleCtrl.dispose();
    contentCtrl.dispose();
  }

  Widget _notesBody(AppLocalizations l10n) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_notes.isEmpty) {
      return _EmptyState(message: l10n.noNotesYet, hint: l10n.captureHint);
    }
    return RefreshIndicator(
      onRefresh: _loadNotes,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 88),
        itemCount: _notes.length,
        itemBuilder: (context, i) => NoteCard(
          note: _notes[i],
          onTap: () async {
            final deleted = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => NoteDetailScreen(note: _notes[i]),
              ),
            );
            if (deleted == true) _loadNotes();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('NoteSpot')),
      body: IndexedStack(
        index: _tab,
        children: [
          _notesBody(l10n),
          const SearchTab(),
          const SettingsTab(),
        ],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              onPressed: _openCaptureSheet,
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.notes), label: l10n.notesTab),
          NavigationDestination(
              icon: const Icon(Icons.search), label: l10n.searchTab),
          NavigationDestination(
              icon: const Icon(Icons.settings), label: l10n.settingsTab),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.hint});
  final String message;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.note_add_outlined,
              size: 72, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(hint, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}