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
                    return Stack(
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
                  },
                ),
    );
  }
}
