import 'dart:io';
import '../../widgets/eva_avatar.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/category_labels.dart';
import '../../l10n/app_localizations.dart';
import '../../models/note.dart';
import '../../services/custom_category_service.dart';
import '../../services/db_service.dart';
import '../../services/eva_service.dart';
import '../../services/local_analysis_service.dart';
import '../../services/notification_service.dart';
import '../capture/note_editor_screen.dart';
import '../../services/media_service.dart';

// --- Checklist add-item row ---
class _AddChecklistItemRow extends StatefulWidget {
  const _AddChecklistItemRow({required this.onAdd});
  final ValueChanged<String> onAdd;

  @override
  State<_AddChecklistItemRow> createState() => _AddChecklistItemRowState();
}

class _AddChecklistItemRowState extends State<_AddChecklistItemRow> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onAdd(text);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 16),
        const Icon(Icons.add, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              hintText: 'Προσθήκη στοιχείου...',
              border: InputBorder.none,
              isDense: true,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 20),
          onPressed: _submit,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ],
    );
  }
}

// --- Edit dialog ---
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

// --- Audio player card ---
class _AudioPlayerCard extends StatefulWidget {
  const _AudioPlayerCard({required this.path});
  final String path;

  @override
  State<_AudioPlayerCard> createState() => _AudioPlayerCardState();
}

class _AudioPlayerCardState extends State<_AudioPlayerCard> {
  final _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _toggle() async {
    if (_state == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.play(DeviceFileSource(widget.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _state == PlayerState.playing;
    final total = _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: _toggle,
            ),
            Expanded(
              child: Slider(
                value: _position.inSeconds.toDouble().clamp(0, total),
                max: total,
                onChanged: (v) => _player.seek(Duration(seconds: v.toInt())),
              ),
            ),
            Text(
              '${_fmt(_position)} / ${_fmt(_duration)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
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
  bool _evaLearnChecked = true;
  String? _evaMessage;
  int _evaMessageGen = 0;

  // Preset colors for picker (0 = none/default)
  static const _presetColors = [
    0,
    0xFFFFCDD2, // red-light
    0xFFFFE0B2, // orange-light
    0xFFFFF9C4, // yellow-light
    0xFFC8E6C9, // green-light
    0xFFBBDEFB, // blue-light
    0xFFE1BEE7, // purple-light
    0xFFF8BBD0, // pink-light
  ];

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _reloadAfterEnrichment();
  }

  /// When a note is freshly created, background analysis (base rules + Eva)
  /// may set its category a moment after this screen opens. Re-read the note
  /// from the DB a few times so the Eva dropdown reflects the final category.
  Future<void> _reloadAfterEnrichment() async {
    if (_note.id == null) return;
    for (var i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      final fresh = await DbService.instance.getById(_note.id!);
      if (fresh == null) return;
      // Update if category/tags/ocr changed (enrichment finished).
      if (fresh.category != _note.category ||
          fresh.tags.length != _note.tags.length ||
          fresh.ocrText != _note.ocrText) {
        if (mounted) setState(() => _note = fresh);
        return;
      }
    }
  }

  String _typeLabel(AppLocalizations l10n) => switch (_note.type) {
        NoteType.photo => l10n.photoNote,
        NoteType.voice => l10n.voiceNote,
        NoteType.handwriting => l10n.handwritingNote,
        NoteType.text => l10n.textNote,
        NoteType.checklist => 'Λίστα',
      };

  static bool _isAudio(String? path) =>
      path != null && path.toLowerCase().endsWith('.m4a');

  Future<void> _onEvaCategoryPicked(String cat) async {
    final noteText = '${_note.content} ${_note.ocrText}'.trim();
    final updated = _note.copyWith(
      category: cat,
      categoryLocked: true,
      updatedAt: DateTime.now(),
    );
    await DbService.instance.update(updated);
    if (_evaLearnChecked && noteText.isNotEmpty) {
      await EvaService.instance.train(noteText, cat);
    }
    if (mounted) setState(() => _note = updated);
  }

  Future<void> _share() async {
    final text = '${_note.title}\n${_note.content}';
    final path = _note.mediaPath;
    if (path != null && !_isAudio(path) && File(path).existsSync()) {
      await Share.shareXFiles([XFile(path)], text: text);
    } else {
      await Share.share(text);
    }
  }

  Future<void> _addToCalendar() async {
    final title = Uri.encodeComponent(_note.title.isNotEmpty ? _note.title : 'SpotNote');
    final details = Uri.encodeComponent(_note.content.isNotEmpty ? _note.content : '');
    final now = DateTime.now();
    final start = '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}T${now.hour.toString().padLeft(2,'0')}${now.minute.toString().padLeft(2,'0')}00';
    final end = '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}T${(now.hour+1).toString().padLeft(2,'0')}${now.minute.toString().padLeft(2,'0')}00';
    final uri = Uri.parse('content://com.android.calendar/time/$start');
    final intentUri = Uri.parse(
      'intent://${Uri.encodeComponent('SpotNote')}#Intent;action=android.intent.action.INSERT;type=vnd.android.cursor.item/event;S.title=$title;S.description=$details;S.beginTime=${now.millisecondsSinceEpoch};S.endTime=${now.millisecondsSinceEpoch + 3600000};end'
    );
    if (await canLaunchUrl(intentUri)) {
      await launchUrl(intentUri);
    } else {
      await launchUrl(Uri.parse('https://calendar.google.com/calendar/r/eventedit?text=$title&details=$details'));
    }
  }

  Future<void> _edit(AppLocalizations l10n) async {
    if (_note.type == NoteType.checklist) return; // edited inline
    final hasInk = _note.mediaPath != null &&
        File(_note.mediaPath!).existsSync() &&
        !_note.mediaPath!.endsWith('.m4a');
    if (hasInk) {
      final savedId = await Navigator.push<int>(
        context,
        MaterialPageRoute(builder: (_) => NoteEditorScreen(editNote: _note)),
      );
      if (savedId != null && mounted) {
        final refreshed = await DbService.instance.getById(_note.id!);
        if (refreshed != null && mounted) setState(() => _note = refreshed);
      }
      return;
    }
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) =>
          _EditNoteDialog(title: _note.title, content: _note.content),
    );
    if (result == null || !mounted) return;
    final (newTitle, newContent) = result;
    if (newTitle.isEmpty) return;
    final updated = _note.copyWith(
      title: newTitle,
      content: newContent,
      updatedAt: DateTime.now(),
    );
    await DbService.instance.update(updated);
    if (!mounted) return;
    setState(() => _note = updated);
  }

  Future<void> _toggleFavorite() async {
    final updated = _note.copyWith(isFavorite: !_note.isFavorite);
    await DbService.instance.update(updated);
    if (mounted) setState(() => _note = updated);
  }

  Future<void> _togglePin() async {
    final updated = _note.copyWith(isPinned: !_note.isPinned);
    await DbService.instance.update(updated);
    if (mounted) setState(() => _note = updated);
  }

  Future<void> _toggleArchive() async {
    final updated = _note.copyWith(
      isArchived: !_note.isArchived,
      updatedAt: DateTime.now(),
    );
    await DbService.instance.update(updated);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _togglePrivate() async {
    final updated = _note.copyWith(
      isPrivate: !_note.isPrivate,
      updatedAt: DateTime.now(),
    );
    await DbService.instance.update(updated);
    if (mounted) setState(() => _note = updated);
  }

  Future<void> _showColorPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Χρώμα σημείωσης',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: _presetColors.map((c) {
                  final selected = c == _note.color;
                  return GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      final updated = _note.copyWith(
                          color: c, updatedAt: DateTime.now());
                      await DbService.instance.update(updated);
                      if (mounted) setState(() => _note = updated);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c == 0 ? Colors.white : Color(c),
                        border: Border.all(
                          color: selected
                              ? Theme.of(ctx).colorScheme.primary
                              : Colors.grey.shade300,
                          width: selected ? 3 : 1,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: c == 0
                          ? const Icon(Icons.block_outlined,
                              size: 18, color: Colors.grey)
                          : selected
                              ? const Icon(Icons.check,
                                  size: 18, color: Colors.black54)
                              : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showExpiryPicker() async {
    final now = DateTime.now();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Αυτόματη διαγραφή',
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('Ποτέ (για πάντα)'),
              selected: _note.expiresAt == null,
              onTap: () {
                Navigator.pop(ctx);
                _applyExpiry(null);
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('1 ημέρα'),
              onTap: () {
                Navigator.pop(ctx);
                _applyExpiry(now.add(const Duration(days: 1)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('1 εβδομάδα'),
              onTap: () {
                Navigator.pop(ctx);
                _applyExpiry(now.add(const Duration(days: 7)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('1 μήνας'),
              onTap: () {
                Navigator.pop(ctx);
                _applyExpiry(now.add(const Duration(days: 30)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Επιλογή ημερομηνίας...'),
              onTap: () async {
                Navigator.pop(ctx);
                final date = await showDatePicker(
                  context: context,
                  initialDate: now.add(const Duration(days: 1)),
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 365 * 5)),
                );
                if (date == null || !mounted) return;
                final time = await showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 8, minute: 0),
                  initialEntryMode: TimePickerEntryMode.input,
                );
                if (time == null || !mounted) return;
                _applyExpiry(DateTime(
                    date.year, date.month, date.day, time.hour, time.minute));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReminderPicker() async {
    final now = DateTime.now();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Υπενθύμιση',
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_off_outlined),
              title: const Text('Καμία υπενθύμιση'),
              selected: _note.reminderAt == null,
              onTap: () {
                Navigator.pop(ctx);
                _applyReminder(null);
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Σε 1 ώρα'),
              onTap: () {
                Navigator.pop(ctx);
                _applyReminder(now.add(const Duration(hours: 1)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Σε 3 ώρες'),
              onTap: () {
                Navigator.pop(ctx);
                _applyReminder(now.add(const Duration(hours: 3)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.bedtime_outlined),
              title: const Text('Απόψε στις 20:00'),
              onTap: () {
                Navigator.pop(ctx);
                _applyReminder(DateTime(now.year, now.month, now.day, 20, 0));
              },
            ),
            ListTile(
              leading: const Icon(Icons.wb_sunny_outlined),
              title: const Text('Αύριο στις 9:00'),
              onTap: () {
                Navigator.pop(ctx);
                _applyReminder(
                    DateTime(now.year, now.month, now.day + 1, 9, 0));
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Επιλογή ώρας (σήμερα)...'),
              onTap: () async {
                Navigator.pop(ctx);
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(
                      now.add(const Duration(hours: 1))),
                  initialEntryMode: TimePickerEntryMode.input,
                );
                if (time == null || !mounted) return;
                var dt = DateTime(
                    now.year, now.month, now.day, time.hour, time.minute);
                if (dt.isBefore(now)) {
                  dt = dt.add(const Duration(days: 1));
                }
                _applyReminder(dt);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Επιλογή ημερομηνίας & ώρας...'),
              onTap: () async {
                Navigator.pop(ctx);
                final date = await showDatePicker(
                  context: context,
                  initialDate: now.add(const Duration(days: 1)),
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 365 * 5)),
                );
                if (date == null || !mounted) return;
                final time = await showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 9, minute: 0),
                  initialEntryMode: TimePickerEntryMode.input,
                );
                if (time == null || !mounted) return;
                _applyReminder(DateTime(
                    date.year, date.month, date.day, time.hour, time.minute));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyReminder(DateTime? reminderAt) async {
    if (_note.id != null) {
      if (reminderAt != null) {
        final ok = await NotificationService.instance
            .trySchedule(_note.id!, _note.title, reminderAt);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Η υπενθύμιση αποθηκεύτηκε αλλά ίσως χρειάζεται άδεια ειδοποιήσεων στις ρυθμίσεις.'),
            ),
          );
        }
      } else {
        await NotificationService.instance.cancelReminder(_note.id!);
      }
    }
    final updated = Note(
      id: _note.id,
      type: _note.type,
      title: _note.title,
      content: _note.content,
      category: _note.category,
      tags: _note.tags,
      mediaPath: _note.mediaPath,
      isFavorite: _note.isFavorite,
      canvasBg: _note.canvasBg,
      ocrText: _note.ocrText,
      isPinned: _note.isPinned,
      isArchived: _note.isArchived,
      color: _note.color,
      reminderAt: reminderAt,
      expiresAt: _note.expiresAt,
      categoryLocked: _note.categoryLocked,
      isPrivate: _note.isPrivate,
      createdAt: _note.createdAt,
      updatedAt: DateTime.now(),
    );
    await DbService.instance.update(updated);
    if (mounted) setState(() => _note = updated);
  }

  Future<void> _applyExpiry(DateTime? expiry) async {
    // Use full constructor so expiresAt: null actually clears the field
    // (copyWith with nullable ?? can't distinguish null-to-clear from not-provided)
    final updated = Note(
      id: _note.id,
      type: _note.type,
      title: _note.title,
      content: _note.content,
      category: _note.category,
      tags: _note.tags,
      mediaPath: _note.mediaPath,
      isFavorite: _note.isFavorite,
      canvasBg: _note.canvasBg,
      ocrText: _note.ocrText,
      isPinned: _note.isPinned,
      isArchived: _note.isArchived,
      color: _note.color,
      reminderAt: _note.reminderAt,
      expiresAt: expiry,
      categoryLocked: _note.categoryLocked,
      isPrivate: _note.isPrivate,
      createdAt: _note.createdAt,
      updatedAt: DateTime.now(),
    );
    await DbService.instance.update(updated);
    if (mounted) setState(() => _note = updated);
  }

  // --- Checklist helpers ---

  List<(bool, String)> _parseChecklistItems(String content) => content
      .split('\n')
      .where((l) => l.isNotEmpty)
      .map((l) {
        if (l.startsWith('[x] ')) return (true, l.substring(4));
        if (l.startsWith('[ ] ')) return (false, l.substring(4));
        return (false, l);
      })
      .toList();

  String _rebuildContent(List<(bool, String)> items) =>
      items.map((e) => '${e.$1 ? '[x]' : '[ ]'} ${e.$2}').join('\n');

  Future<void> _toggleChecklistItem(int index, bool checked) async {
    final items = _parseChecklistItems(_note.content);
    if (index >= items.length) return;
    items[index] = (checked, items[index].$2);
    final updated = _note.copyWith(
      content: _rebuildContent(items),
      updatedAt: DateTime.now(),
    );
    await DbService.instance.update(updated);
    if (mounted) setState(() => _note = updated);
  }

  Future<void> _addChecklistItem(String text) async {
    final items = _parseChecklistItems(_note.content);
    items.add((false, text));
    final updated = _note.copyWith(
      content: _rebuildContent(items),
      updatedAt: DateTime.now(),
    );
    await DbService.instance.update(updated);
    if (mounted) setState(() => _note = updated);
  }

  Future<void> _removeChecklistItem(int index) async {
    final items = _parseChecklistItems(_note.content);
    if (index >= items.length) return;
    items.removeAt(index);
    final updated = _note.copyWith(
      content: _rebuildContent(items),
      updatedAt: DateTime.now(),
    );
    await DbService.instance.update(updated);
    if (mounted) setState(() => _note = updated);
  }

  Widget _buildChecklist() {
    final items = _parseChecklistItems(_note.content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...items.asMap().entries.map((e) {
          final idx = e.key;
          final (checked, text) = e.value;
          return CheckboxListTile(
            value: checked,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(text,
                style: checked
                    ? const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey)
                    : null),
            secondary: IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => _removeChecklistItem(idx),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            onChanged: (v) => _toggleChecklistItem(idx, v ?? false),
          );
        }),
        const Divider(height: 8),
        _AddChecklistItemRow(onAdd: _addChecklistItem),
      ],
    );
  }

  Future<void> _print() async {
    final doc = pw.Document();
    final hasImage = _note.mediaPath != null &&
        File(_note.mediaPath!).existsSync() &&
        !_note.mediaPath!.endsWith('.m4a');
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(_note.title,
              style: pw.TextStyle(
                  fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (_note.content.isNotEmpty)
            pw.Text(_note.content,
                style: const pw.TextStyle(fontSize: 13)),
          if (hasImage) ...[
            pw.SizedBox(height: 12),
            pw.Image(pw.MemoryImage(
                File(_note.mediaPath!).readAsBytesSync())),
          ],
        ],
      ),
    ));
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
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
    final isEl = Localizations.localeOf(context).languageCode == 'el';
    final date = DateFormat.yMMMd(locale).add_jm().format(_note.createdAt);
    final path = _note.mediaPath;
    final hasAudio = _isAudio(path) && path != null && File(path).existsSync();
    final hasImage = !hasAudio && path != null && File(path).existsSync();
    final expiryLabel = _note.expiresAt == null
        ? 'Για πάντα'
        : 'Λήγει: ${DateFormat('d/M/yy HH:mm').format(_note.expiresAt!)}';
    final reminderLabel = _note.reminderAt == null
        ? 'Καμία υπενθύμιση'
        : 'Υπενθύμιση: ${DateFormat('d/M/yy HH:mm').format(_note.reminderAt!)}';

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
            icon: Icon(
              _note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: _note.isPinned
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: _note.isPinned ? 'Ξεκαρφίτσωμα' : 'Καρφίτσωμα',
            onPressed: _togglePin,
          ),
          IconButton(
            icon: Icon(
              _note.isFavorite ? Icons.star : Icons.star_border,
              color: _note.isFavorite ? Colors.amber : null,
            ),
            tooltip: _note.isFavorite
                ? 'Αφαίρεση από αγαπημένα'
                : 'Προσθήκη στα αγαπημένα',
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: Icon(
              _note.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
              color: _note.isArchived
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: _note.isArchived ? 'Επαναφορά από αρχείο' : 'Αρχειοθέτηση',
            onPressed: _toggleArchive,
          ),
          IconButton(
            icon: Icon(
              _note.isPrivate ? Icons.lock : Icons.lock_open_outlined,
              color: _note.isPrivate
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: _note.isPrivate ? 'Αφαίρεση κλειδώματος' : 'Ιδιωτική σημείωση',
            onPressed: _togglePrivate,
          ),
          if (_note.type != NoteType.checklist)
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'print') _print();
              if (v == 'calendar') _addToCalendar();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'print', child: Row(children: [Icon(Icons.print_outlined), SizedBox(width: 12), Text('Print')])),
              const PopupMenuItem(value: 'calendar', child: Row(children: [Icon(Icons.calendar_today_outlined), SizedBox(width: 12), Text('Add to Calendar')])),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewPadding.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasAudio) _AudioPlayerCard(path: path),
            if (hasImage) ...[
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => _FullscreenImage(path: path)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(path),
                      width: double.infinity, fit: BoxFit.fitWidth),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Content shown first for immediate readability
            if (_note.type == NoteType.checklist)
              _buildChecklist()
            else if (_note.content.isNotEmpty)
              SelectableText(
                _note.content,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 8),
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
                ..._note.tags
                    .map((t) => Chip(
                          label: Text(t),
                          visualDensity: VisualDensity.compact,
                        )),
              ],
            ),
            const SizedBox(height: 12),
            // Color picker row
            InkWell(
              onTap: _showColorPicker,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _note.color == 0
                            ? Colors.white
                            : Color(_note.color),
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _note.color == 0
                          ? const Icon(Icons.block_outlined,
                              size: 12, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _note.color == 0 ? 'Χρώμα σημείωσης' : 'Χρώμα: επιλεγμένο',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Icon(Icons.arrow_drop_down, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Expiry row
            InkWell(
              onTap: _showExpiryPicker,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _note.expiresAt == null
                          ? Icons.all_inclusive
                          : Icons.schedule,
                      size: 18,
                      color: _note.expiresAt == null
                          ? Colors.grey
                          : Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      expiryLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _note.expiresAt == null
                                ? null
                                : Theme.of(context).colorScheme.error,
                          ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Reminder row
            InkWell(
              onTap: _showReminderPicker,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _note.reminderAt == null
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                      size: 18,
                      color: _note.reminderAt == null
                          ? Colors.grey
                          : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      reminderLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _note.reminderAt == null
                                ? null
                                : Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Eva section
            _EvaSection(
              currentCategory:
                  _note.category.isNotEmpty ? _note.category : 'other',
              learnChecked: _evaLearnChecked,
              isEl: isEl,
              isLocked: _note.categoryLocked,
              onCategoryPicked: _onEvaCategoryPicked,
              onLearnChanged: (v) =>
                  setState(() => _evaLearnChecked = v ?? true),
            ),
          ],
        ),
          ),
          // Floating Eva helper (bottom-left), tappable for a tip.
          Positioned(
            right: 8,
            top: 70,
            child: EvaAvatar(
              size: 110,
              floating: true,
              mood: EvaMood.idle,
              onTap: () {
                final isEl =
                    Localizations.localeOf(context).languageCode == 'el';
                final msg = isEl
                    ? 'Με λένε Eva! Μαθαίνω να ταξινομώ τις σημειώσεις σου όταν διορθώνεις την κατηγορία.'
                    : "I'm Eva! I learn to sort your notes when you fix the category.";
                _evaMessageGen++;
                final gen = _evaMessageGen;
                setState(() => _evaMessage = msg);
                Future.delayed(const Duration(seconds: 5), () {
                  if (mounted && gen == _evaMessageGen) {
                    setState(() => _evaMessage = null);
                  }
                });
              },
            ),
          ),
          if (_evaMessage != null)
            Positioned(
              right: 120,
              top: 110,
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: GestureDetector(
                    onTap: () => setState(() => _evaMessage = null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        _evaMessage!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- Eva category section ---
class _EvaSection extends StatefulWidget {
  const _EvaSection({
    required this.currentCategory,
    required this.learnChecked,
    required this.isEl,
    required this.isLocked,
    required this.onCategoryPicked,
    required this.onLearnChanged,
  });

  final String currentCategory;
  final bool learnChecked;
  final bool isEl;
  final bool isLocked;
  final ValueChanged<String> onCategoryPicked;
  final ValueChanged<bool?> onLearnChanged;

  @override
  State<_EvaSection> createState() => _EvaSectionState();
}

class _EvaSectionState extends State<_EvaSection> {
  List<String> _customCats = [];
  late String _selectedCat;

  static const _addSentinel = '__add_custom__';

  @override
  void initState() {
    super.initState();
    _selectedCat = widget.currentCategory;
    _loadCustomCats();
  }

  @override
  void didUpdateWidget(_EvaSection old) {
    super.didUpdateWidget(old);
    if (old.currentCategory != widget.currentCategory) {
      setState(() => _selectedCat = widget.currentCategory);
    }
  }

  Future<void> _loadCustomCats() async {
    final cats = await CustomCategoryService.instance.getCategories();
    if (mounted) setState(() => _customCats = cats);
  }

  Future<void> _showAddDialog() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.isEl ? 'Νέα κατηγορία' : 'New category'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: widget.isEl ? 'Όνομα κατηγορίας' : 'Category name',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(widget.isEl ? 'Άκυρο' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(widget.isEl ? 'Προσθήκη' : 'Add'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty) return;
    await CustomCategoryService.instance.addCategory(name);
    await _loadCustomCats();
    widget.onCategoryPicked(name);
    if (mounted) setState(() => _selectedCat = name);
  }

  Future<void> _deleteCustomCat(String name) async {
    await CustomCategoryService.instance.removeCategory(name);
    if (_selectedCat == name) {
      widget.onCategoryPicked('other');
      setState(() => _selectedCat = 'other');
    }
    await _loadCustomCats();
  }

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.secondary;
    final bodySmall = Theme.of(context).textTheme.bodySmall;
    final isEl = widget.isEl;

    // Build all dropdown items: Eva built-ins + custom + "+" sentinel
    final allCatKeys = {
      ...LocalAnalysisService.kCategories,
      ..._customCats,
    };
    // If the note's category is a custom one not in SharedPreferences, still include it
    final orphanCat = !allCatKeys.contains(_selectedCat) && _selectedCat.isNotEmpty
        ? _selectedCat
        : null;
    final effectiveSelected = allCatKeys.contains(_selectedCat)
        ? _selectedCat
        : orphanCat ?? 'other';

    final items = <DropdownMenuItem<String>>[
      ...LocalAnalysisService.kCategories.map((cat) => DropdownMenuItem(
            value: cat,
            child: Text(categoryLabel(cat, greek: isEl)),
          )),
      if (orphanCat != null)
        DropdownMenuItem(value: orphanCat, child: Text(orphanCat)),
      ..._customCats.map((cat) => DropdownMenuItem(
            value: cat,
            child: Text(cat),
          )),
      DropdownMenuItem(
        value: _addSentinel,
        child: Row(
          children: [
            const Icon(Icons.add, size: 16),
            const SizedBox(width: 6),
            Text(isEl ? 'Νέα κατηγορία...' : 'New category...'),
          ],
        ),
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 2),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: secondary.withValues(alpha: 0.5), width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: secondary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.isLocked
                      ? (isEl ? 'Κατηγορία (χειροκίνητη)' : 'Category (manual)')
                      : (isEl
                          ? 'Η Eva πρότεινε αυτή την κατηγορία'
                          : 'Eva suggested this category'),
                  style: bodySmall?.copyWith(
                    color: secondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          DropdownButton<String>(
            value: effectiveSelected,
            isDense: true,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            style: bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            items: items,
            onChanged: (v) {
              if (v == null) return;
              if (v == _addSentinel) {
                _showAddDialog();
                return;
              }
              widget.onCategoryPicked(v);
              setState(() => _selectedCat = v);
            },
          ),
          if (_customCats.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: _customCats
                  .map((cat) => Chip(
                        label: Text(cat,
                            style: const TextStyle(fontSize: 12)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () => _deleteCustomCat(cat),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ],
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: widget.learnChecked,
            visualDensity: VisualDensity.compact,
            title: Text(
              isEl ? 'Βοήθησε την Eva να μάθει' : 'Help Eva learn',
              style: bodySmall,
            ),
            onChanged: widget.onLearnChanged,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
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