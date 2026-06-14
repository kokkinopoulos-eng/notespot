import 'package:flutter/material.dart';
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
      appBar: AppBar(title: const Text('Αρχείο')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('Δεν υπάρχουν αρχειοθετημένες σημειώσεις'),
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
                    return Card(
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
                    );
                  },
                ),
    );
  }
}
