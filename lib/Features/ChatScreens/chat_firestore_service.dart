import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:next_poll/Features/ChatScreens/chat_storage_service.dart';
import 'package:next_poll/Models/chat_conversation.dart';
import 'package:next_poll/Models/chat_model.dart';

/// Firestore path layout:
///   users/{userId}/chats/{chatId}               ← conversation metadata
///   users/{userId}/chats/{chatId}/messages/{id} ← individual messages
///
/// Images are stored in Firebase Storage and referenced by downloadURL
/// in the message document's `imageUrl` field.
class ChatFirestoreService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storageService = ChatStorageService();

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('User is not signed in.');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _chatsCol =>
      _firestore.collection('users').doc(_uid).collection('chats');

  CollectionReference<Map<String, dynamic>> _messagesCol(String chatId) =>
      _chatsCol.doc(chatId).collection('messages');

  // ─── Conversations ───────────────────────────────────────────────────────────

  /// Stream of all conversations for the current user, newest first.
  Stream<List<ChatConversation>> conversationsStream() {
    return _chatsCol
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatConversation.fromMap(d.data(), d.id))
            .toList());
  }

  /// Creates a new conversation document and returns its generated ID.
  Future<String> createConversation({required String firstMessage}) async {
    try {
      final title = firstMessage.length > 40
          ? '${firstMessage.substring(0, 40)}…'
          : firstMessage;

      final ref = await _chatsCol.add({
        'title': title,
        'lastMessage': firstMessage,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'messageCount': 0,
      });
      return ref.id;
    } catch (e) {
      log('ChatFirestoreService.createConversation error: $e');
      rethrow;
    }
  }

  /// Updates conversation metadata after a new message pair is added.
  Future<void> updateConversationMeta({
    required String chatId,
    required String lastMessage,
    required int messageCount,
  }) async {
    try {
      await _chatsCol.doc(chatId).update({
        'lastMessage': lastMessage,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'messageCount': messageCount,
      });
    } catch (e) {
      log('ChatFirestoreService.updateConversationMeta error: $e');
    }
  }

  /// Deletes an entire conversation, all its messages, and any attached images
  /// from Firebase Storage.
  Future<void> deleteConversation(String chatId) async {
    try {
      final snap = await _messagesCol(chatId).get();

      // Delete Storage images for every message that has one.
      await _deleteImagesFromDocs(snap.docs);

      // Batch-delete all message docs + the conversation doc itself.
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_chatsCol.doc(chatId));
      await batch.commit();
    } catch (e) {
      log('ChatFirestoreService.deleteConversation error: $e');
      rethrow;
    }
  }

  // ─── Messages ────────────────────────────────────────────────────────────────

  /// Streams messages for a conversation in chronological order.
  Stream<List<ChatMessage>> messagesStream(String chatId) {
    return _messagesCol(chatId)
        .orderBy('timestamp')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatMessage.fromMap(d.data(), docId: d.id))
            .toList());
  }

  /// Loads messages once (used for history restoration on conversation open).
  Future<List<ChatMessage>> loadMessages(String chatId) async {
    try {
      final snap = await _messagesCol(chatId).orderBy('timestamp').get();
      return snap.docs
          .map((d) => ChatMessage.fromMap(d.data(), docId: d.id))
          .toList();
    } catch (e) {
      log('ChatFirestoreService.loadMessages error: $e');
      return [];
    }
  }

  /// Saves a single message (including optional imageUrl) and returns its doc ID.
  Future<String> saveMessage(String chatId, ChatMessage message) async {
    try {
      // toMap() only includes imageUrl when it is non-null.
      final ref = await _messagesCol(chatId).add(message.toMap());
      return ref.id;
    } catch (e) {
      log('ChatFirestoreService.saveMessage error: $e');
      rethrow;
    }
  }

  /// Deletes all messages in a conversation and any associated Storage images,
  /// then resets the conversation metadata. The conversation doc itself is kept.
  Future<void> clearMessages(String chatId) async {
    try {
      final snap = await _messagesCol(chatId).get();

      // Delete Storage images before removing Firestore docs.
      await _deleteImagesFromDocs(snap.docs);

      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      await _chatsCol.doc(chatId).update({
        'lastMessage': '',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'messageCount': 0,
      });
    } catch (e) {
      log('ChatFirestoreService.clearMessages error: $e');
      rethrow;
    }
  }

  // ─── Private helpers ─────────────────────────────────────────────────────────

  /// Iterates over [docs] and deletes any Storage object referenced by
  /// an `imageUrl` field. Errors per-image are swallowed so one bad URL
  /// does not block the rest of the batch.
  Future<void> _deleteImagesFromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final deletions = <Future<void>>[];
    for (final doc in docs) {
      final url = doc.data()['imageUrl'] as String?;
      if (url != null && url.isNotEmpty) {
        deletions.add(
          _storageService.deleteImage(url).catchError(
            (e) => log('ChatFirestoreService: failed to delete image $url: $e'),
          ),
        );
      }
    }
    if (deletions.isNotEmpty) await Future.wait(deletions);
  }
}
