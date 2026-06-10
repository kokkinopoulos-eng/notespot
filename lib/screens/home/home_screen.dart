import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/category_labels.dart';
import '../../core/timeline_utils.dart';
import '../../l10n/app_localizations.dart';
import '../../models/note.dart';
import '../../services/db_service.dart';
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
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              onPressed: () async {
                final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NoteEditorScreen()),
                );
                if (saved == true) _loadNotes();
              },
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