import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import 'db_service.dart';

class BackupService {
  BackupService._();
  static final instance = BackupService._();

  static const _channel = MethodChannel('notespot/picker');

  Future<Directory> _mediaDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'notespot_media'));
  }

  Future<void> backup(BuildContext context) async {
    try {
      final dbPath = p.join(await getDatabasesPath(), 'notespot.db');
      final media = await _mediaDir();
      final encoder = ZipFileEncoder();
      final tmp = await getTemporaryDirectory();
      final zipPath = p.join(tmp.path,
          'notespot_backup_${DateTime.now().millisecondsSinceEpoch}.zip');
      encoder.create(zipPath);
      await encoder.addFile(File(dbPath), 'notespot.db');
      if (await media.exists()) {
        await for (final f in media.list()) {
          if (f is File) {
            await encoder.addFile(f, 'media/${p.basename(f.path)}');
          }
        }
      }
      await encoder.close();
      await Share.shareXFiles([XFile(zipPath)], subject: 'NoteSpot Backup');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    }
  }

  /// Merge restore: imports notes from a backup zip WITHOUT deleting
  /// anything. Notes are matched by created_at; on conflict the newer
  /// updated_at wins. Media files are only copied if missing.
  Future<bool> restore(BuildContext context) async {
    try {
      final bytes = await _channel.invokeMethod<Uint8List>('pickZip');
      if (bytes == null) return false; // user cancelled

      final archive = ZipDecoder().decodeBytes(bytes);
      final media = await _mediaDir();
      if (!await media.exists()) await media.create(recursive: true);

      String? tmpDbPath;
      final tmp = await getTemporaryDirectory();
      for (final f in archive.files) {
        if (!f.isFile) continue;
        debugPrint('[RESTDBG] entry=${f.name} size=${f.size}');
        final data = f.content as List<int>;
        if (f.name == 'notespot.db') {
          tmpDbPath = p.join(tmp.path,
              'restore_${DateTime.now().millisecondsSinceEpoch}.db');
          await File(tmpDbPath).writeAsBytes(data, flush: true);
        } else if (f.name.startsWith('media/')) {
          final dest = File(p.join(media.path, p.basename(f.name)));
          if (!dest.existsSync()) {
            await dest.writeAsBytes(data, flush: true);
            debugPrint('[RESTDBG] media WROTE ${p.basename(f.name)}');
          } else {
            debugPrint('[RESTDBG] media SKIP ${p.basename(f.name)}');
          }
        }
      }
      if (tmpDbPath == null) {
        throw Exception('No database found in backup');
      }

      final src = await openDatabase(tmpDbPath, readOnly: true);
      final rows = await src.query('notes');
      await src.close();
      await File(tmpDbPath).delete();

      final db = await DbService.instance.database;
      for (final r in rows) {
        final row = Map<String, Object?>.from(r);
        final mp = row['media_path'] as String?;
        if (mp != null && mp.isNotEmpty) {
          row['media_path'] = p.join(media.path, p.basename(mp));
        }
        row.remove('id');
        final existing = await db.query('notes',
            where: 'created_at = ?',
            whereArgs: [row['created_at']],
            limit: 1);
        if (existing.isEmpty) {
          await db.insert('notes', row);
        } else {
          final curUpd = (existing.first['updated_at'] as int?) ?? 0;
          final srcUpd = (row['updated_at'] as int?) ?? 0;
          if (srcUpd > curUpd) {
            await db.update('notes', row,
                where: 'id = ?', whereArgs: [existing.first['id']]);
          }
        }
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
      return false;
    }
  }
}
