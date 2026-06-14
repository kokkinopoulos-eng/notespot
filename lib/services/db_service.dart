import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../core/search_utils.dart';
import '../models/note.dart';

class DbService {
  DbService._();
  static final DbService instance = DbService._();

  static const _dbName = 'notespot.db';
  static const _dbVersion = 5;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(path, version: _dbVersion, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      await db.execute(
          'ALTER TABLE notes ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0');
    }
    if (oldV < 3) {
      await db.execute(
          'ALTER TABLE notes ADD COLUMN canvas_bg INTEGER NOT NULL DEFAULT 4294967295');
    }
    if (oldV < 4) {
      await db.execute(
          "ALTER TABLE notes ADD COLUMN ocr_text TEXT NOT NULL DEFAULT ''");
    }
    if (oldV < 5) {
      await db.execute(
          'ALTER TABLE notes ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE notes ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE notes ADD COLUMN color INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE notes ADD COLUMN reminder_at INTEGER');
      await db.execute(
          'ALTER TABLE notes ADD COLUMN expires_at INTEGER');
    }
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
        is_favorite INTEGER NOT NULL DEFAULT 0,
        canvas_bg INTEGER NOT NULL DEFAULT 4294967295,
        ocr_text TEXT NOT NULL DEFAULT '',
        is_pinned INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        color INTEGER NOT NULL DEFAULT 0,
        reminder_at INTEGER,
        expires_at INTEGER,
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
        '${note.title} ${note.content} ${note.category} ${note.tags.join(' ')} ${note.ocrText}');
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

  Future<Note?> getById(int id) async {
    final db = await database;
    final rows =
        await db.query('notes', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Note.fromMap(rows.first);
  }

  Future<List<Note>> getFavorites() async {
    final db = await database;
    final rows = await db.query('notes',
        where: 'is_favorite = 1 AND is_archived = 0',
        orderBy: 'updated_at DESC');
    return rows.map(Note.fromMap).toList();
  }

  Future<List<Note>> getAll() async {
    final db = await database;
    final rows = await db.query('notes',
        where: 'is_archived = 0',
        orderBy: 'is_pinned DESC, created_at DESC');
    return rows.map(Note.fromMap).toList();
  }

  Future<List<Note>> getArchived() async {
    final db = await database;
    final rows = await db.query('notes',
        where: 'is_archived = 1', orderBy: 'created_at DESC');
    return rows.map(Note.fromMap).toList();
  }

  Future<void> purgeExpired() async {
    final db = await database;
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    await db.delete('notes',
        where: 'expires_at IS NOT NULL AND expires_at < ?',
        whereArgs: [nowMillis]);
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

  Future<List<String>> getCategories() async {
    final db = await database;
    final rows = await db.rawQuery(
      "SELECT DISTINCT category FROM notes WHERE category != '' ORDER BY category",
    );
    return rows.map((r) => r['category'] as String).toList();
  }

  Future<List<Note>> search(String query) async {
    final db = await database;
    final terms = normalizeForSearch(query.trim())
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) return getAll();
    final termWhere = terms.map((_) => 'search_text LIKE ?').join(' AND ');
    final where = 'is_archived = 0 AND $termWhere';
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