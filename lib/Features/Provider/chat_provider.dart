import 'dart:developer';
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart' as firebase_ai;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:next_poll/Features/ChatScreens/chat_firestore_service.dart';
import 'package:next_poll/Features/ChatScreens/chat_storage_service.dart';
import 'package:next_poll/Models/chat_model.dart';
import 'package:next_poll/Models/parsed_poll.dart';

class ChatProvider extends ChangeNotifier {
  // ─── State ──────────────────────────────────────────────────────────────────

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isLoadingHistory = false;

  /// The Firestore chat document ID for the current conversation.
  /// Null means no conversation has been opened yet.
  String? _currentChatId;

  /// Set after sendMessage completes if the AI reply contains a poll.
  /// Cleared by [clearLastPoll] once the dialog has been handled.
  ParsedPoll? _lastParsedPoll;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isLoadingHistory => _isLoadingHistory;
  String? get currentChatId => _currentChatId;

  /// Non-null when the most recent AI reply was a poll suggestion.
  ParsedPoll? get lastParsedPoll => _lastParsedPoll;

  /// Call this after the dialog has been shown so it doesn't re-trigger.
  void clearLastPoll() {
    _lastParsedPoll = null;
  }

  // ─── Services ────────────────────────────────────────────────────────────────

  final ChatFirestoreService _firestoreService = ChatFirestoreService();
  final ChatStorageService _storageService = ChatStorageService();

  late final firebase_ai.GenerativeModel _model;
  late firebase_ai.ChatSession _chat;

  // ─── Init ────────────────────────────────────────────────────────────────────

  ChatProvider() {
    _model = firebase_ai.FirebaseAI.googleAI().generativeModel(
      model: 'gemini-flash-latest',
      systemInstruction: firebase_ai.Content.system(
        'You are the AI assistant for NextPoll. '
        'NextPoll lets users create location-based polls. '
        'Each poll contains: '
        'One question/title '
        'Exactly 3 options '
        'Each option has a name and image '
        'Users nearby can vote. '
        'Creators can edit or delete their polls. '
        'Offline-created polls sync automatically when internet returns. '
        'When asked to create a poll, respond exactly:\n'
        '📋 Poll Title: <title>\n'
        'Option 1: <name>\n'
        'Option 2: <name>\n'
        'Option 3: <name>\n'
        'Keep titles concise and options short. '
        'Do not suggest images. '
        'For all other questions, answer normally and explain the app when asked.',
      ),
    );
    _chat = _model.startChat();
  }

  // ─── Load an existing conversation ──────────────────────────────────────────

  /// Opens an existing conversation: loads persisted messages and rebuilds
  /// the Gemini session history (text-only parts for context).
  Future<void> loadConversation(String chatId) async {
    if (_currentChatId == chatId) return;

    _currentChatId = chatId;
    _messages.clear();
    _isLoadingHistory = true;
    notifyListeners();

    try {
      final history = await _firestoreService.loadMessages(chatId);
      _messages.addAll(history);

      // Rebuild Gemini session from text history so context is preserved.
      // Images are shown in the UI but are not re-sent to the model on reload.
      _chat = _model.startChat(
        history: history.map((m) {
          final textPart = firebase_ai.TextPart(
            m.text.isNotEmpty ? m.text : '[image]',
          );
          return m.sender == MessageSender.user
              ? firebase_ai.Content.multi([textPart])
              : firebase_ai.Content.model([textPart]);
        }).toList(),
      );
    } catch (e) {
      log('ChatProvider.loadConversation error: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  // ─── Send a message ──────────────────────────────────────────────────────────

  /// Sends a message to Gemini, optionally with an [image].
  ///
  /// Flow:
  ///   1. Create Firestore conversation doc if this is the first message.
  ///   2. Upload image to Firebase Storage (if provided) → get download URL.
  ///   3. Add user message to the local list immediately.
  ///   4. Persist user message to Firestore.
  ///   5. Build multimodal [Content] and send to Gemini.
  ///   6. Persist AI reply and update conversation metadata.
  Future<void> sendMessage(String text, {XFile? image}) async {
    final trimmed = text.trim();

    // Need at least text or an image.
    if (trimmed.isEmpty && image == null) return;

    // ── 1. Create conversation doc on first message ───────────────────────────
    if (_currentChatId == null) {
      final firstMessage = trimmed.isNotEmpty ? trimmed : '📷 Image';
      try {
        _currentChatId = await _firestoreService.createConversation(
          firstMessage: firstMessage,
        );
      } catch (e) {
        log('ChatProvider: failed to create conversation: $e');
        _messages.add(
          ChatMessage(
            text: 'Could not start conversation. Please try again.',
            sender: MessageSender.ai,
            timestamp: DateTime.now(),
          ),
        );
        notifyListeners();
        return;
      }
    }

    final chatId = _currentChatId!;

    // ── 2. Upload image first so the URL is ready before the message lands ────
    String? uploadedImageUrl;
    if (image != null) {
      // Show loading state while uploading.
      _isLoading = true;
      notifyListeners();

      try {
        uploadedImageUrl = await _storageService.uploadChatImage(
          file: image,
          chatId: chatId,
        );
      } catch (e) {
        log('ChatProvider: image upload failed: $e');
        _isLoading = false;
        _messages.add(
          ChatMessage(
            text: 'Image upload failed. Please try again.',
            sender: MessageSender.ai,
            timestamp: DateTime.now(),
          ),
        );
        notifyListeners();
        return;
      }
    }

    // ── 3. Add user message to local list immediately ─────────────────────────
    final userMsg = ChatMessage(
      text: trimmed,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
      imageUrl: uploadedImageUrl,
    );
    _messages.add(userMsg);
    _isLoading = true;
    notifyListeners();

    // ── 4. Persist user message (fire-and-forget) ─────────────────────────────
    _firestoreService.saveMessage(chatId, userMsg).catchError((e) {
      log('ChatProvider: failed to save user message: $e');
      return "ChatProvider: failed to save user message: $e";
    });

    // ── 5. Build multimodal content and send to Gemini ────────────────────────
    try {
      final parts = <firebase_ai.Part>[];

      // Add image bytes when an image is attached.
      if (image != null) {
        final bytes = await File(image.path).readAsBytes();
        final mimeType = _mimeFromPath(image.path);
        parts.add(firebase_ai.InlineDataPart(mimeType, bytes));
      }

      // Always include a text part (Gemini requires at least one Part).
      parts.add(
        firebase_ai.TextPart(
          trimmed.isNotEmpty ? trimmed : 'What is in this image?',
        ),
      );

      final response = await _chat.sendMessage(
        firebase_ai.Content.multi(parts),
      );
      final reply = response.text ?? 'No response from AI.';

      final aiMsg = ChatMessage(
        text: reply,
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
      );
      _messages.add(aiMsg);

      // Check if the reply contains an AI-generated poll suggestion.
      _lastParsedPoll = _parsePoll(reply);

      // ── 6. Persist AI reply + update metadata ─────────────────────────────
      _firestoreService.saveMessage(chatId, aiMsg).catchError((e) {
        log('ChatProvider: failed to save AI message: $e');
        return "ChatProvider: failed to save AI message: $e";
      });

      _firestoreService
          .updateConversationMeta(
            chatId: chatId,
            lastMessage: trimmed.isNotEmpty ? trimmed : '📷 Image',
            messageCount: _messages.length,
          )
          .catchError(
            (e) => log('ChatProvider: failed to update conversation meta: $e'),
          );
    } catch (e) {
      log('ChatProvider.sendMessage error: $e');
      _messages.add(
        ChatMessage(
          text: 'Something went wrong. Please try again.',
          sender: MessageSender.ai,
          timestamp: DateTime.now(),
        ),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Clear / reset ───────────────────────────────────────────────────────────

  /// Clears all messages from the current conversation in Firestore and locally.
  // Future<void> clearChat() async {
  //   if (_currentChatId != null) {
  //     await _firestoreService
  //         .clearMessages(_currentChatId!)
  //         .catchError((e) => log('ChatProvider.clearChat error: $e'));
  //   }
  //   _messages.clear();
  //   _chat = _model.startChat();
  //   notifyListeners();
  // }

  /// Resets the provider so a fresh conversation can begin.
  void resetForNewChat() {
    _currentChatId = null;
    _messages.clear();
    _lastParsedPoll = null;
    _chat = _model.startChat();
    notifyListeners();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  String _mimeFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Tries to parse [text] as an AI-generated poll.
  ///
  /// Expected format (from the system prompt):
  ///   📋 Poll Title: <title>
  ///   Option 1: <name>
  ///   Option 2: <name>
  ///   Option 3: <name>
  ///
  /// Returns a [ParsedPoll] on success, null otherwise.
  ParsedPoll? _parsePoll(String text) {
    try {
      final titleMatch =
          RegExp(r'📋\s*Poll Title:\s*(.+)', caseSensitive: false)
              .firstMatch(text);
      if (titleMatch == null) return null;

      final title = titleMatch.group(1)!.trim();

      final options = <String>[];
      for (int i = 1; i <= 3; i++) {
        final optMatch =
            RegExp('Option $i:\\s*(.+)', caseSensitive: false).firstMatch(text);
        if (optMatch == null) return null;
        options.add(optMatch.group(1)!.trim());
      }

      return ParsedPoll(title: title, options: options);
    } catch (_) {
      return null;
    }
  }
}
