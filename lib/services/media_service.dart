import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MediaService {
  MediaService._();
  static final MediaService instance = MediaService._();

  final _picker = ImagePicker();

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

  Future<String> savePngBytes(Uint8List bytes) async {
    final dir = await _mediaDir();
    final target =
        p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}.png');
    await File(target).writeAsBytes(bytes, flush: true);
    return target;
  }

  Future<String> newAudioPath() async {
    final dir = await _mediaDir();
    return p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}.m4a');
  }

  Future<String> _persist(XFile file) async {
    final dir = await _mediaDir();
    final name =
        '${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}';
    final target = p.join(dir.path, name);
    await File(file.path).copy(target);
    return target;
  }

  Future<Directory> _mediaDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'notespot_media'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> deleteMedia(String? path) async {
    if (path == null) return;
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}