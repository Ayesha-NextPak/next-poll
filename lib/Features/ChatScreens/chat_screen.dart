import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:next_poll/Features/HomeScreens/create_poll_screen.dart';
import 'package:next_poll/Features/Provider/chat_provider.dart';
import 'package:next_poll/Features/Provider/poll_provider.dart';
import 'package:next_poll/Models/chat_model.dart';
import 'package:next_poll/Models/parsed_poll.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatefulWidget {
  /// Pass [chatId] + [title] when opening an existing conversation.
  /// Leave both null to start a fresh chat.
  const ChatScreen({super.key, this.chatId, this.title});

  final String? chatId;
  final String? title;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(ChatProvider provider, XFile? pendingImage) {
    final text = _controller.text.trim();
    if (text.isEmpty && pendingImage == null) return;
    _controller.clear();
    provider.sendMessage(text, image: pendingImage).then((_) {
      _scrollToBottom();
      // If the AI returned a poll suggestion, show the "Add this poll?" dialog.
      final poll = provider.lastParsedPoll;
      if (poll != null && mounted) {
        provider.clearLastPoll();
        _showAddPollDialog(poll);
      }
    });
    _scrollToBottom();
  }

  /// Shows a confirmation dialog when the AI suggests a poll.
  /// On "Yes" → pre-populate PollProvider and navigate to CreatePollScreen.
  void _showAddPollDialog(ParsedPoll poll) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.poll_outlined, color: colorScheme.primary, size: 22),
            const SizedBox(width: 8),
            const Text('Add this poll?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The AI created a poll for you. Want to open the create screen with it pre-filled?',
            ),
            const SizedBox(height: 12),
            // Preview card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    poll.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  for (int i = 0; i < poll.options.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        '${i + 1}. ${poll.options[i]}',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        // Pre-populate the form and navigate to the create screen.
        context.read<PollProvider>().prePopulate(
              title: poll.title,
              options: poll.options,
            );
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreatePollScreen(currentId: uid),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.inversePrimary,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primary,
              radius: 18,
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title ?? 'AI Assistant',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Consumer<ChatProvider>(
                  builder: (_, provider, __) => Text(
                    provider.isLoadingHistory
                        ? 'Loading...'
                        : provider.isLoading
                            ? 'Typing...'
                            : 'Online',
                    style: TextStyle(
                      fontSize: 12,
                      color: provider.isLoadingHistory || provider.isLoading
                          ? colorScheme.primary
                          : Colors.green.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        // actions: [
        //   Consumer<ChatProvider>(
        //     builder: (_, provider, __) => provider.messages.isEmpty
        //         ? const SizedBox.shrink()
        //         : IconButton(
        //             tooltip: 'Clear chat',
        //             icon: const Icon(Icons.delete_outline),
        //             onPressed: () => _confirmClear(context, provider),
        //           ),
        //   ),
        // ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (_, provider, __) {
                if (provider.isLoadingHistory) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.messages.isEmpty) {
                  return _EmptyState(colorScheme: colorScheme);
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  itemCount: provider.messages.length +
                      (provider.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (provider.isLoading &&
                        index == provider.messages.length) {
                      return const _TypingIndicator();
                    }
                    return _MessageBubble(
                        message: provider.messages[index]);
                  },
                );
              },
            ),
          ),

          // ── Input bar owns its own state (pending image) ──────────────────
          _InputBar(
            controller: _controller,
            onSend: (pendingImage) => _sendMessage(
              context.read<ChatProvider>(),
              pendingImage,
            ),
          ),
        ],
      ),
    );
  }

  // void _confirmClear(BuildContext context, ChatProvider provider) {
  //   showDialog(
  //     context: context,
  //     builder: (_) => AlertDialog(
  //       title: const Text('Clear conversation?'),
  //       content: const Text('This will delete all messages in this chat.'),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('Cancel'),
  //         ),
  //         FilledButton(
  //           onPressed: () async {
  //             Navigator.pop(context);
  //             await provider.clearChat();
  //           },
  //           child: const Text('Clear'),
  //         ),
  //       ],
  //     ),
  //   );
  // }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colorScheme});
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome,
                size: 64,
                color: colorScheme.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'How can I help you?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask me anything',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message bubble — renders optional image above the text
// ---------------------------------------------------------------------------

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == MessageSender.user;
    final colorScheme = Theme.of(context).colorScheme;
    final hasImage = message.imageUrl != null && message.imageUrl!.isNotEmpty;
    final hasText = message.text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // AI avatar
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primary,
              child: const Icon(Icons.auto_awesome,
                  size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // ── Bubble ────────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: isUser
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  // Clip so the image respects the rounded corners.
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Image (if present) ───────────────────────────
                      if (hasImage)
                        _ChatImage(
                          imageUrl: message.imageUrl!,
                          isUser: isUser,
                        ),

                      // ── Text (if present) ────────────────────────────
                      if (hasText)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            14,
                            hasImage ? 8 : 10,
                            14,
                            10,
                          ),
                          child: Text(
                            message.text,
                            style: TextStyle(
                              color: isUser
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurface,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Timestamp ────────────────────────────────────────────
                const SizedBox(height: 4),
                Text(
                  DateFormat('h:mm a').format(message.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),

          // User avatar
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.secondaryContainer,
              child: Icon(Icons.person,
                  size: 16, color: colorScheme.onSecondaryContainer),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat image widget — tappable for full-screen view
// ---------------------------------------------------------------------------

class _ChatImage extends StatelessWidget {
  const _ChatImage({required this.imageUrl, required this.isUser});
  final String imageUrl;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
          maxHeight: 240,
        ),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              height: 160,
              child: Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => const SizedBox(
            height: 80,
            child: Center(
              child: Icon(Icons.broken_image_outlined, size: 32),
            ),
          ),
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenImagePage(imageUrl: imageUrl),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full-screen image viewer
// ---------------------------------------------------------------------------

class _FullScreenImagePage extends StatelessWidget {
  const _FullScreenImagePage({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Typing indicator
// ---------------------------------------------------------------------------

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: colorScheme.primary,
            child: const Icon(Icons.auto_awesome,
                size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final delay = i / 3;
                  final t = (_controller.value - delay).clamp(0.0, 1.0);
                  final opacity = 0.3 +
                      0.7 *
                          (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Opacity(
                      opacity: opacity,
                      child: CircleAvatar(
                        radius: 4,
                        backgroundColor: colorScheme.onSurface,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Input bar — stateful so it can hold the pending image pick
// ---------------------------------------------------------------------------

class _InputBar extends StatefulWidget {
  const _InputBar({required this.controller, required this.onSend});

  final TextEditingController controller;

  /// Called with the pending [XFile?] when the user taps Send.
  /// The bar clears the pending image after calling this.
  final void Function(XFile? image) onSend;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  XFile? _pendingImage;
  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked != null) {
      setState(() => _pendingImage = picked);
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearImage() => setState(() => _pendingImage = null);

  void _handleSend() {
    final image = _pendingImage;
    // Clear image before calling onSend so the UI updates immediately.
    setState(() => _pendingImage = null);
    widget.onSend(image);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Image preview chip ─────────────────────────────────────────
            if (_pendingImage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_pendingImage!.path),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Remove button
                      Positioned(
                        top: -8,
                        right: -8,
                        child: GestureDetector(
                          onTap: _clearImage,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: colorScheme.error,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorScheme.surface,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.close,
                              size: 12,
                              color: colorScheme.onError,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Text field row ─────────────────────────────────────────────
            Row(
              children: [
                // Attach image button
                IconButton(
                  onPressed: _showImageSourceSheet,
                  tooltip: 'Attach image',
                  icon: Icon(
                    Icons.attach_file_rounded,
                    color: _pendingImage != null
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),

                // Text input
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _handleSend(),
                    decoration: InputDecoration(
                      hintText: _pendingImage != null
                          ? 'Add a caption… (optional)'
                          : 'Message AI Assistant…',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Send button
                Consumer<ChatProvider>(
                  builder: (_, provider, __) => FilledButton(
                    onPressed: provider.isLoading ? null : _handleSend,
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(14),
                    ),
                    child: const Icon(Icons.send_rounded),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
