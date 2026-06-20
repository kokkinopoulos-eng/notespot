import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/note.dart';
import '../../services/db_service.dart';
import '../note_detail/note_detail_screen.dart';
import '../../widgets/note_card.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notes = await DbService.instance.getTrashed();
    if (!mounted) return;
    setState(() { _notes = notes; _loading = false; });
  }

  Future<void> _restore(Note note) async {
    await DbService.instance.restoreFromTrash(note.id!);
    if (!mounted) return;
    setState(() => _notes.removeWhere((n) => n.id == note.id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Επαναφέρθηκε στις σημειώσεις')),
    );
  }

  Future<void> _deletePermanent(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Οριστική διαγραφή;'),
        content: const Text('Δεν μπορεί να αναιρεθεί.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Άκυρο'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Διαγραφή',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await DbService.instance.deletePermanent(note.id!);
    if (!mounted) return;
    setState(() => _notes.removeWhere((n) => n.id == note.id));
  }

  Future<void> _emptyTrash() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Άδειασμα κάδου;'),
        content: const Text('Όλες οι σημειώσεις θα διαγραφούν οριστικά.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Άκυρο'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Άδειασμα',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    for (final n in List.of(_notes)) {
      await DbService.instance.deletePermanent(n.id!);
    }
    if (!mounted) return;
    setState(() => _notes.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Κάδος ανακύκλωσης'),
        actions: [
          if (_notes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Άδειασμα κάδου',
              onPressed: _emptyTrash,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('Ο κάδος είναι άδειος'),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        'Οι σημειώσεις διαγράφονται οριστικά μετά από 30 ημέρες.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _notes.length,
                        itemBuilder: (ctx, i) {
                          final note = _notes[i];
                          final daysLeft = note.deletedAt == null
                              ? 30
                              : 30 -
                                  DateTime.now()
                                      .difference(note.deletedAt!)
                                      .inDays;
                          final cardColor = note.color != 0
                              ? Color(note.color)
                              : const Color(0xFFF3EEF8);
                          return Dismissible(
                            key: ValueKey(note.id),
                            direction: DismissDirection.horizontal,
                            background: Container(
                              color: Colors.green.shade600,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 24),
                              child: const Icon(Icons.restore,
                                  color: Colors.white, size: 28),
                            ),
                            secondaryBackground: Container(
                              color: Colors.red.shade600,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              child: const Icon(Icons.delete_forever,
                                  color: Colors.white, size: 28),
                            ),
                            confirmDismiss: (dir) async {
                              if (dir == DismissDirection.startToEnd) {
                                await _restore(note);
                                return true;
                              } else {
                                await _deletePermanent(note);
                                return false;
                              }
                            },
                            child: Stack(
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
                                  child: Text(
                                    '${daysLeft}η',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: daysLeft <= 3
                                          ? Colors.red
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}