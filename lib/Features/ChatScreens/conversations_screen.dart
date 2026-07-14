import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:next_poll/Features/ChatScreens/chat_firestore_service.dart';
import 'package:next_poll/Features/ChatScreens/chat_screen.dart';
import 'package:next_poll/Features/Provider/chat_provider.dart';
import 'package:next_poll/Models/chat_conversation.dart';
import 'package:provider/provider.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final service = ChatFirestoreService();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.inversePrimary,
        title: const Text(
          'AI Chats',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNewChat(context),
        icon: const Icon(Icons.add),
        label: const Text('New Chat'),
      ),
      body: StreamBuilder<List<ChatConversation>>(
        stream: service.conversationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load chats.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.error),
              ),
            );
          }

          final conversations = snapshot.data ?? [];

          if (conversations.isEmpty) {
            return _EmptyConversations(
              colorScheme: colorScheme,
              onNewChat: () => _openNewChat(context),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: conversations.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final conv = conversations[index];
              return _ConversationTile(
                conversation: conv,
                onTap: () => _openExistingChat(context, conv),
                onDelete: () => _confirmDelete(context, service, conv),
              );
            },
          );
        },
      ),
    );
  }

  // ─── Navigation helpers ────────────────────────────────────────────────────

  void _openNewChat(BuildContext context) {
    context.read<ChatProvider>().resetForNewChat();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  void _openExistingChat(BuildContext context, ChatConversation conv) {
    context.read<ChatProvider>().loadConversation(conv.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(chatId: conv.id, title: conv.title),
      ),
    );
  }

  // ─── Delete confirmation ──────────────────────────────────────────────────

  void _confirmDelete(
    BuildContext context,
    ChatFirestoreService service,
    ChatConversation conv,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: Text(
          '"${conv.title}" and all its messages will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await service.deleteConversation(conv.id);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete conversation.'),
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─── Conversation tile ─────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
    required this.onDelete,
  });

  final ChatConversation conversation;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final updated = conversation.updatedAt;

    // Show time if today, otherwise show date.
    final timeLabel = updated.day == now.day &&
            updated.month == now.month &&
            updated.year == now.year
        ? DateFormat('h:mm a').format(updated)
        : DateFormat('MMM d').format(updated);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: colorScheme.primaryContainer,
        child: Icon(
          Icons.auto_awesome,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        conversation.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: conversation.lastMessage.isEmpty
          ? null
          : Text(
              conversation.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            timeLabel,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          if (conversation.messageCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${conversation.messageCount}',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      onTap: onTap,
      onLongPress: onDelete,
    );
  }
}

// ─── Empty state ───────────────────────────────────────────────────────────────

class _EmptyConversations extends StatelessWidget {
  const _EmptyConversations({
    required this.colorScheme,
    required this.onNewChat,
  });

  final ColorScheme colorScheme;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 72,
              color: colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to start chatting with the AI assistant.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onNewChat,
              icon: const Icon(Icons.add),
              label: const Text('New Chat'),
            ),
          ],
        ),
      ),
    );
  }
}
