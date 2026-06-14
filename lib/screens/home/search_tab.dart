import 'dart:async';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/note.dart';
import '../../services/db_service.dart';
import '../../widgets/note_card.dart';
import '../note_detail/note_detail_screen.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Note> _results = [];
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(value));
  }

  Future<void> _run(String query) async {
    if (query.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }
    final results = await DbService.instance.search(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _controller,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.searchHint,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _controller.clear();
                        _run('');
                      },
                    ),
            ),
          ),
        ),
        Expanded(
          child: !_searched
              ? const SizedBox.shrink()
              : _results.isEmpty
                  ? Center(child: Text(l10n.noResults))
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 16),
                      itemCount: _results.length,
                      itemBuilder: (context, i) => Card(
                        color: _results[i].color != 0
                            ? Color(_results[i].color)
                            : const Color(0xFFF3EEF8),
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: NoteCard(
                          note: _results[i],
                          onTap: () async {
                            final deleted = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    NoteDetailScreen(note: _results[i]),
                              ),
                            );
                            if (deleted == true) _run(_controller.text);
                          },
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}