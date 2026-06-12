import 'dart:io';

import 'package:archive/archive_io.dart';
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

  Future<void> backup(BuildContext context) async {
    try {
      final dbPath = p.join(await getDatabasesPath(), 'notespot.db');
      final media = await _mediaDir();
      final encoder = ZipFileEncoder();
      final tmp = await getTemporaryDirectory();
      final zipPath = p.join(tmp.path,
          'notespot_backup_${DateTime.now().millisecondsSinceEpoch}.zip');
      encoder.create(zipPath);
      encoder.addFile(File(dbPath), 'notespot.db');
      if (await media.exists()) {
        await for (final f in media.list()) {
          if (f is File) encoder.addFile(f, 'media/${p.basename(f.path)}');
        }
      }
      encoder.close();
      await Share.shareXFiles([XFile(zipPath)], subject: 'NoteSpot Backup');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    }
  }

  /// Restore available in v1.1.
  Future<bool> restore(BuildContext context) async {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restore coming in v1.1')),
      );
    }
    return false;
  }
}
