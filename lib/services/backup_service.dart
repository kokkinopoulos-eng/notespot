import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

class BackupService {
  BackupService._();
  static final instance = BackupService._();

  Future<Directory> _mediaDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'notespot_media'));
  }

  /// Creates a zip with the DB + all media files and opens the share sheet.
  Future<void> backup(BuildContext context) async {
    try {
      final dbPath = p.join(await getDatabasesPath(), 'notespot.db');
      final media = await _mediaDir();
      final encoder = ZipFileEncoder();
      final tmp = await getTemporaryDirectory();
      final zipPath =
          p.join(tmp.path, 'notespot_backup_${DateTime.now().millisecondsSinceEpoch}.zip');
      encoder.create(zipPath);
      encoder.addFile(File(dbPath), 'notespot.db');
      if (await media.exists()) {
        await for (final f in media.list()) {
          if (f is File) encoder.addFile(f, 'media/${p.basename(f.path)}');
        }
      }
      encoder.close();
      await Share.shareXFiles([XFile(zipPath)],
          subject: 'NoteSpot Backup');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    }
  }

  /// Picks a zip, closes DB, restores files, reopens.
  Future<bool> restore(BuildContext context) async {
    try {
      // User picks the zip via system file manager
      // open_filex opens the file; for restore we use a different approach
      // We store the last backup path and let user pick via share intent
      // For now: prompt user to enter path or use a simple dialog
      return false; // placeholder - see note below
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final dbPath = p.join(await getDatabasesPath(), 'notespot.db');
      final media = await _mediaDir();
      if (!await media.exists()) await media.create(recursive: true);

      // Close DB before overwriting
      final db = await databaseFactory.openDatabase(dbPath);
      await db.close();

      for (final f in archive) {
        final data = Uint8List.fromList(f.content as List<int>);
        if (f.name == 'notespot.db') {
          await File(dbPath).writeAsBytes(data, flush: true);
        } else if (f.name.startsWith('media/')) {
          final name = p.basename(f.name);
          await File(p.join(media.path, name))
              .writeAsBytes(data, flush: true);
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