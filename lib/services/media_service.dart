import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MediaService {
  MediaService._();

  static final MediaService instance = MediaService._();

  final _picker = ImagePicker();

  /// Opens the camera, saves the captured photo into the app's
  /// permanent media folder and returns its path (null if cancelled).
  Future<String?> capturePhoto() async {
    final XFile? shot = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2048,
    );
    if (shot == null) return null;
    return _persist(shot);
  }

  Future<String?> pickFromGallery() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2048,
    );
    if (file == null) return null;
    return _persist(file);
  }

  Future<String> _persist(XFile file) async {
    final docs = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(docs.path, 'notespot_media'));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    final name =
        '${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}';
    final target = p.join(mediaDir.path, name);
    await File(file.path).copy(target);
    return target;
  }

  Future<void> deleteMedia(String? path) async {
    if (path == null) return;
    final f = File(path);
    if (await f.exists()) {
      await f.delete();
    }
  }
}