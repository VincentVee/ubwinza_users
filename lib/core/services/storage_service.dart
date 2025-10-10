import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
class StorageService {
  StorageService._(); static final I = StorageService._(); final _s = FirebaseStorage.instance;
  Future<String> upload(String path, Uint8List bytes) async { final ref = _s.ref(path); await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg')); return await ref.getDownloadURL(); }
  Future<void> delete(String path) => _s.ref(path).delete();
}