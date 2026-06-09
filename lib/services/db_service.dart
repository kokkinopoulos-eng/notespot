import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../core/search_utils.dart';
import '../models/note.dart';

class DbService {
  DbService._();

  static final DbService instance = DbService._();

  static const _dbName = 'notespot.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(path, version: _dbVersion, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL DEFAULT '',
        tags TEXT NOT NULL DEFAULT '',
        media_path TEXT,
        search_text TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_notes_category ON notes(category)');
    await db.execute('CREATE INDEX idx_notes_created ON notes(created_at)');
  }

  Map<String, dynamic> _withSearchText(Note note) {
    final map = note.toMap();
    map['search_text'] = normalizeForSearch(
        '${note.title} ${note.content} ${note.category} ${note.tags.join(' ')}');
    return map;
  }

  Future<int> insert(Note note) async {
    final db = await database;
    final map = _withSearchText(note)..remove('id');
    return db.insert('notes', map);
  }

  Future<int> update(Note note) async {
    final db = await database;
    return db.update(
      'notes',
      _withSearchText(note),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await database;
    return db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Note>> getAll() async {
    final db = await database;
    final rows = await db.query('notes', orderBy: 'created_at DESC');
    return rows.map(Note.fromMap).toList();
  }

  Future<List<Note>> getByCategory(String category) async {
    final db = await database;
    final rows = await db.query(
      'notes',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'created_at DESC',
    );
    return rows.map(Note.fromMap).toList();
  }

  Future<List<Note>> search(String query) async {
    final db = await database;
    final terms = normalizeForSearch(query.trim())
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) return getAll();
    final where = terms.map((_) => 'search_text LIKE ?').join(' AND ');
    final args = terms.map((t) => '%$t%').toList();
    final rows = await db.query(
      'notes',
      where: where,
      whereArgs: args,
      orderBy: 'created_at DESC',
    );
    return rows.map(Note.fromMap).toList();
  }
}