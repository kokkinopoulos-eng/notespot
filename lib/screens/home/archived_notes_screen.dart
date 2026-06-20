import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/note.dart';
import '../../services/db_service.dart';
import '../../widgets/note_card.dart';
import '../note_detail/note_detail_screen.dart';

class ArchivedNotesScreen extends StatefulWidget {
  const ArchivedNotesScreen({super.key});

  @override
  State<ArchivedNotesScreen> createState() => _ArchivedNotesScreenState();
}

class _ArchivedNotesScreenState extends State<ArchivedNotesScreen> {
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notes = await DbService.instance.getArchived();
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.archiveSection)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(l10n.archivedNotesEmpty),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: const [
                            Icon(Icons.arrow_back,
                                size: 13, color: Colors.red),
                            SizedBox(width: 4),
                            Text('Διαγραφή',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.red)),
                          ]),
                          Row(children: const [
                            Text('Επαναφορά',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.green)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward,
                                size: 13, color: Colors.green),
                          ]),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _notes.length,
                        itemBuilder: (ctx, i) {
                          final note = _notes[i];
                          final cardColor = note.color != 0
                              ? Color(note.color)
                              : const Color(0xFFF3EEF8);
                          final stack = Stack(
                            children: [
                              Card(
                                color: cardColor,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: NoteCard(
                                  note: note,
                                  onTap: () async {
                                    await Navigator.push(
                                      ctx,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            NoteDetailScreen(note: note),
                                      ),
                                    );
                                    _load();
                                  },
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 20,
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  size: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          );
                          return Dismissible(
                            key: ValueKey(note.id ?? -1),
                            direction: DismissDirection.horizontal,
                            background: Container(
                              color: Colors.red.shade600,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 24),
                              child: const Icon(Icons.delete,
                                  color: Colors.white, size: 28),
                            ),
                            secondaryBackground: Container(
                              color: Colors.green.shade600,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              child: const Icon(Icons.unarchive,
                                  color: Colors.white, size: 28),
                            ),
                            confirmDismiss: (dir) async {
                              if (dir == DismissDirection.endToStart) {
                                await DbService.instance.update(note.copyWith(
                                    isArchived: false,
                                    updatedAt: DateTime.now()));
                                if (!mounted) return true;
                                setState(() =>
                                    _notes.removeWhere((n) => n.id == note.id));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          '\u0395\u03c0\u03b1\u03bd\u03b1\u03c6\u03ad\u03c1\u03b8\u03b7\u03ba\u03b5 \u03c3\u03c4\u03b9\u03c2 \u03c3\u03b7\u03bc\u03b5\u03b9\u03ce\u03c3\u03b5\u03b9\u03c2')),
                                );
                                return true;
                              }
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (dctx) => AlertDialog(
                                  title: const Text(
                                      '\u039f\u03c1\u03b9\u03c3\u03c4\u03b9\u03ba\u03ae \u03b4\u03b9\u03b1\u03b3\u03c1\u03b1\u03c6\u03ae;'),
                                  content: const Text(
                                      '\u0394\u03b5\u03bd \u03bc\u03c0\u03bf\u03c1\u03b5\u03af \u03bd\u03b1 \u03b1\u03bd\u03b1\u03b9\u03c1\u03b5\u03b8\u03b5\u03af.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dctx, false),
                                      child: const Text(
                                          '\u0386\u03ba\u03c5\u03c1\u03bf'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dctx, true),
                                      child: const Text(
                                          '\u0394\u03b9\u03b1\u03b3\u03c1\u03b1\u03c6\u03ae',
                                          style: TextStyle(
                                              color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await DbService.instance.delete(note.id!);
                                if (!mounted) return true;
                                setState(() =>
                                    _notes.removeWhere((n) => n.id == note.id));
                                return true;
                              }
                              return false;
                            },
                            child: stack,
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}