import 'dart:developer';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

/// Handles uploading chat images to Firebase Storage.
///
/// Storage path:
///   users/{uid}/chat_images/{chatId}/{timestamp}_{filename}
class ChatStorageService {
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('User is not signed in.');
    return uid;
  }

  /// Uploads [file] and returns the public download URL.
  ///
  /// [chatId] is used to group images by conversation.
  /// Throws on failure — callers should handle the error.
  Future<String> uploadChatImage({
    required XFile file,
    required String chatId,
  }) async {
    try {
      final ext = p.extension(file.name).isNotEmpty
          ? p.extension(file.name)
          : '.jpg';
      final filename = '${DateTime.now().millisecondsSinceEpoch}$ext';
      final storagePath = 'users/$_uid/chat_images/$chatId/$filename';

      final ref = _storage.ref(storagePath);

      final metadata = SettableMetadata(
        contentType: _mimeFromExt(ext),
        customMetadata: {'uploadedBy': _uid, 'chatId': chatId},
      );

      await ref.putFile(File(file.path), metadata);
      return await ref.getDownloadURL();
    } catch (e) {
      log('ChatStorageService.uploadChatImage error: $e');
      rethrow;
    }
  }

  /// Deletes the image at [downloadUrl] from Storage, silently ignoring
  /// "object not found" errors (already deleted or URL changed).
  Future<void> deleteImage(String downloadUrl) async {
    try {
      await _storage.refFromURL(downloadUrl).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        log('ChatStorageService.deleteImage error: $e');
      }
    } catch (e) {
      log('ChatStorageService.deleteImage unexpected error: $e');
    }
  }

  String _mimeFromExt(String ext) {
    switch (ext.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
