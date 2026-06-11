import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/category_labels.dart';
import '../../core/timeline_utils.dart';
import '../../l10n/app_localizations.dart';
import '../../models/note.dart';
import '../../services/cloud_ai_service.dart';
import '../../services/db_service.dart';
import '../../services/media_service.dart';
import '../../widgets/note_card.dart';
import '../capture/note_editor_screen.dart';
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
  List<String> _categories = [];
  String? _selectedCategory;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final cats = await DbService.instance.getCategories();
    if (_selectedCategory != null && !cats.contains(_selectedCategory)) {
      _selectedCategory = null;
    }
    final notes = _selectedCategory != null
        ? await DbService.instance.getByCategory(_selectedCategory!)
        : await DbService.instance.getAll();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _notes = notes;
      _loading = false;
    });
  }

  Future<void> _quickPhoto() async {
    final path = await MediaService.instance.capturePhoto();
    if (path == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final langName = Localizations.localeOf(context).languageCode == 'el'
        ? 'Greek' : 'English';
    final now = DateTime.now();
    final stamp = DateFormat('d/M HH:mm').format(now);
    final noteId = await DbService.instance.insert(Note(
      type: NoteType.photo,
      title: '${l10n.photoNote} $stamp',
      mediaPath: path,
      createdAt: now,
      updatedAt: now,
    ));
    unawaited(_enrichPhoto(noteId, path, langName));
    await _loadNotes();
  }

  Future<void> _enrichPhoto(int noteId, String path, String lang) async {
    final analysis = await CloudAiService.instance.analyzeImage(path, lang);
    if (analysis == null) return;
    final note = await DbService.instance.getById(noteId);
    if (note == null) return;
    final autoTitle = RegExp(r'^.+\s\d+/\d+\s\d+:\d+$');
    await DbService.instance.update(Note(
      id: note.id, type: note.type,
      title: analysis.title.isNotEmpty && autoTitle.hasMatch(note.title)
          ? analysis.title : note.title,
      content: analysis.extractedText.isNotEmpty
          ? analysis.extractedText : note.content,
      category: analysis.category, tags: analysis.tags,
      mediaPath: note.mediaPath,
      createdAt: note.createdAt, updatedAt: DateTime.now(),
    ));
    await _loadNotes();
  }

  Future<void> _quickDictation() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _QuickDictationSheet(onSaved: _loadNotes),
    );
  }

  String _bucketLabel(AppLocalizations l10n, TimelineBucket b) =>
      switch (b) {
        TimelineBucket.today => l10n.today,
        TimelineBucket.yesterday => l10n.yesterday,
        TimelineBucket.thisWeek => l10n.thisWeek,
        TimelineBucket.earlier => l10n.earlier,
      };

  Widget _filterRow(AppLocalizations l10n) {
    if (_categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(l10n.allCategories),
              selected: _selectedCategory == null,
              onSelected: (_) {
                setState(() => _selectedCategory = null);
                _loadNotes();
              },
            ),
          ),
          ..._categories.map((c) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(localizedCategory(l10n, c)),
                  selected: _selectedCategory == c,
                  onSelected: (_) {
                    setState(() => _selectedCategory = c);
                    _loadNotes();
                  },
                ),
              )),
        ],
      ),
    );
  }

  Widget _notesBody(AppLocalizations l10n) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_notes.isEmpty) {
      return _EmptyState(message: l10n.noNotesYet, hint: l10n.captureHint);
    }
    final now = DateTime.now();
    final items = <Widget>[];
    TimelineBucket? lastBucket;
    for (final note in _notes) {
      final bucket = bucketFor(note.createdAt, now);
      if (bucket != lastBucket) {
        items.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            _bucketLabel(l10n, bucket),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ));
        lastBucket = bucket;
      }
      items.add(NoteCard(
        note: note,
        onTap: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => NoteDetailScreen(note: note)),
          );
          if (result == true) _loadNotes();
        },
      ));
    }
    return RefreshIndicator(
      onRefresh: _loadNotes,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 88),
        itemCount: items.length,
        itemBuilder: (_, i) => items[i],
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
          Column(children: [
            _filterRow(l10n),
            Expanded(child: _notesBody(l10n)),
          ]),
          const SearchTab(),
          const SettingsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final saved = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
          );
          if (saved == true) _loadNotes();
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: BottomAppBar(
        notchMargin: 8,
        shape: const CircularNotchedRectangle(),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.notes),
              color: _tab == 0 ? Theme.of(context).colorScheme.primary : null,
              onPressed: () => setState(() => _tab = 0),
              tooltip: l10n.notesTab,
            ),
            IconButton(
              icon: const Icon(Icons.search),
              color: _tab == 1 ? Theme.of(context).colorScheme.primary : null,
              onPressed: () => setState(() => _tab = 1),
              tooltip: l10n.searchTab,
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              color: _tab == 2 ? Theme.of(context).colorScheme.primary : null,
              onPressed: () => setState(() => _tab = 2),
              tooltip: l10n.settingsTab,
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.mic_outlined),
              onPressed: _quickDictation,
              tooltip: l10n.voiceNote,
            ),
            IconButton(
              icon: const Icon(Icons.photo_camera_outlined),
              onPressed: _quickPhoto,
              tooltip: l10n.photoNote,
            ),
            const SizedBox(width: 56),
          ],
        ),
      ),
    );
  }
}

// ─── Quick Dictation Sheet ───────────────────────────────────────────────────

enum _SheetMode { dictation, record }

class _QuickDictationSheet extends StatefulWidget {
  const _QuickDictationSheet({required this.onSaved});
  final VoidCallback onSaved;

  @override
  State<_QuickDictationSheet> createState() => _QuickDictationSheetState();
}

class _QuickDictationSheetState extends State<_QuickDictationSheet> {
  _SheetMode _mode = _SheetMode.dictation;

  // Dictation
  final _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _listening = false;
  String _transcript = '';
  String _partial = '';

  // Record
  final _recorder = AudioRecorder();
  bool _recording = false;
  String? _recordPath;
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.cancel();
    _recorder.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(onStatus: _onStatus);
    if (mounted) setState(() {});
  }

  void _onStatus(String status) {
    if (!mounted) return;
    setState(() => _listening = _speech.isListening);
  }

  void _onResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() {
      if (result.finalResult) {
        _transcript = ('$_transcript ${result.recognizedWords}').trim();
        _partial = '';
      } else {
        _partial = result.recognizedWords;
      }
    });
  }

  Future<void> _toggleDictation() async {
    if (_listening) {
      await _speech.stop();
      return;
    }
    final localeId = Localizations.localeOf(context).languageCode == 'el'
        ? 'el-GR' : 'en-US';
    await _speech.listen(
      onResult: _onResult,
      localeId: localeId,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
      ),
      pauseFor: const Duration(seconds: 5),
      listenFor: const Duration(minutes: 2),
    );
    if (mounted) setState(() => _listening = true);
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      _timer?.cancel();
      final path = await _recorder.stop();
      setState(() {
        _recording = false;
        _recordPath = path;
      });
    } else {
      final path = await MediaService.instance.newAudioPath();
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      setState(() {
        _recording = true;
        _recordPath = null;
        _seconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
    }
  }

  Future<void> _switchMode(_SheetMode m) async {
    if (m == _mode) return;
    if (_listening) await _speech.stop();
    if (_recording) {
      _timer?.cancel();
      final path = await _recorder.stop();
      if (path != null) await MediaService.instance.deleteMedia(path);
      setState(() { _recording = false; _recordPath = null; _seconds = 0; });
    }
    setState(() => _mode = m);
  }

  Future<void> _saveDictation() async {
    final text = ('$_transcript $_partial').trim();
    if (text.isEmpty) return;
    await _speech.stop();
    final l10n = AppLocalizations.of(context);
    final langName = Localizations.localeOf(context).languageCode == 'el'
        ? 'Greek' : 'English';
    final now = DateTime.now();
    final stamp = DateFormat('d/M HH:mm').format(now);
    final noteId = await DbService.instance.insert(Note(
      type: NoteType.voice,
      title: '${l10n.voiceNote} $stamp',
      content: text,
      createdAt: now,
      updatedAt: now,
    ));
    unawaited(_enrichText(noteId, text, langName));
    if (!mounted) return;
    Navigator.pop(context);
    widget.onSaved();
  }

  Future<void> _saveRecording() async {
    final path = _recordPath;
    if (path == null) return;
    final l10n = AppLocalizations.of(context);
    final langName = Localizations.localeOf(context).languageCode == 'el'
        ? 'Greek' : 'English';
    final now = DateTime.now();
    final stamp = DateFormat('d/M HH:mm').format(now);
    final noteId = await DbService.instance.insert(Note(
      type: NoteType.voice,
      title: '${l10n.voiceNote} $stamp',
      mediaPath: path,
      createdAt: now,
      updatedAt: now,
    ));
    unawaited(_enrichAudio(noteId, path, langName));
    if (!mounted) return;
    Navigator.pop(context);
    widget.onSaved();
  }

  Future<void> _cancelRecording() async {
    if (_recording) {
      _timer?.cancel();
      final path = await _recorder.stop();
      if (path != null) await MediaService.instance.deleteMedia(path);
    } else if (_recordPath != null) {
      await MediaService.instance.deleteMedia(_recordPath);
    }
  }

  Future<void> _enrichText(int noteId, String text, String lang) async {
    final analysis = await CloudAiService.instance.analyzeText(text, lang);
    if (analysis == null) return;
    final note = await DbService.instance.getById(noteId);
    if (note == null) return;
    await DbService.instance.update(Note(
      id: note.id, type: note.type, title: note.title,
      content: note.content, category: analysis.category,
      tags: analysis.tags, mediaPath: note.mediaPath,
      createdAt: note.createdAt, updatedAt: DateTime.now(),
    ));
  }

  Future<void> _enrichAudio(int noteId, String path, String lang) async {
    final analysis = await CloudAiService.instance.analyzeAudio(path, lang);
    if (analysis == null) return;
    final note = await DbService.instance.getById(noteId);
    if (note == null) return;
    await DbService.instance.update(Note(
      id: note.id, type: note.type, title: note.title,
      content: analysis.extractedText.isNotEmpty
          ? analysis.extractedText : note.content,
      category: analysis.category, tags: analysis.tags,
      mediaPath: note.mediaPath,
      createdAt: note.createdAt, updatedAt: DateTime.now(),
    ));
  }

  String _fmtSecs(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dictText = ('$_transcript $_partial').trim();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mode toggle
            SegmentedButton<_SheetMode>(
              segments: [
                ButtonSegment(
                  value: _SheetMode.dictation,
                  label: Text(l10n.dictation),
                  icon: const Icon(Icons.record_voice_over),
                ),
                ButtonSegment(
                  value: _SheetMode.record,
                  label: Text(l10n.recordAudio),
                  icon: const Icon(Icons.fiber_manual_record),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => _switchMode(s.first),
            ),
            const SizedBox(height: 16),

            if (_mode == _SheetMode.dictation) ...[
              if (dictText.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(dictText,
                      style: Theme.of(context).textTheme.bodyLarge),
                ),
              if (_listening)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(l10n.listening,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ),
              FloatingActionButton.large(
                heroTag: 'dictation_fab',
                onPressed: _speechAvailable ? _toggleDictation : null,
                backgroundColor:
                    _listening ? Theme.of(context).colorScheme.error : null,
                child: Icon(_listening ? Icons.stop : Icons.mic),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: dictText.isEmpty ? null : _saveDictation,
                    child: Text(l10n.save),
                  ),
                ],
              ),
            ] else ...[
              // Record mode
              Text(
                _fmtSecs(_seconds),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
              ),
              const SizedBox(height: 8),
              if (_recordPath != null && !_recording)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Icon(Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary, size: 32),
                ),
              const SizedBox(height: 8),
              FloatingActionButton.large(
                heroTag: 'record_fab',
                onPressed: _toggleRecord,
                backgroundColor:
                    _recording ? Theme.of(context).colorScheme.error : null,
                child: Icon(_recording ? Icons.stop : Icons.fiber_manual_record),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () async {
                      await _cancelRecording();
                      if (mounted) Navigator.pop(context);
                    },
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: (_recordPath != null && !_recording)
                        ? _saveRecording
                        : null,
                    child: Text(l10n.save),
                  ),
                ],
              ),
            ],
          ],
        ),
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