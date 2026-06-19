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
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).archiveSection)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(AppLocalizations.of(context).archivedNotesEmpty),
                    ],
                  ),
                )
              : ListView.builder(
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
                                  builder: (_) => NoteDetailScreen(note: note),
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
                      direction: DismissDirection.startToEnd,
                      background: Container(
                        color: Colors.red.shade600,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 24),
                        child: const Icon(Icons.delete,
                            color: Colors.white, size: 28),
                      ),
                      confirmDismiss: (_) async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dctx) => AlertDialog(
                            title: const Text('Οριστική διαγραφή;'),
                            content: const Text('Δεν μπορεί να αναιρεθεί.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dctx, false),
                                child: const Text('Άκυρο'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(dctx, true),
                                child: const Text('Διαγραφή',
                                    style: TextStyle(color: Colors.red)),
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
    );
  }
}