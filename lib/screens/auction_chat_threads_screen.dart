import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/widgets/app_state_widgets.dart';
import '../services/user_home_service.dart';

class AuctionChatThreadsScreen extends StatefulWidget {
  const AuctionChatThreadsScreen({
    super.key,
    required this.auctionId,
    required this.auctionTitle,
    required this.currentUserId,
    required this.currentUserName,
    required this.service,
  });

  final String auctionId;
  final String auctionTitle;
  final String currentUserId;
  final String currentUserName;
  final UserHomeService service;

  @override
  State<AuctionChatThreadsScreen> createState() =>
      _AuctionChatThreadsScreenState();
}

class _AuctionChatThreadsScreenState extends State<AuctionChatThreadsScreen> {
  final TextEditingController _composerController = TextEditingController();
  bool _isSending = false;

  Future<void> _openThread(AuctionChatThread thread) async {
    _composerController.clear();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SizedBox(
            height: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chat with ${thread.otherParticipant(widget.currentUserId)}',
                  style: GoogleFonts.sora(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: StreamBuilder<List<ChatMessage>>(
                    stream: widget.service.streamMessagesForViewer(
                      chatId: thread.id,
                      viewerId: widget.currentUserId,
                    ),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const AppLoadingIndicator(
                          label: 'Loading messages...',
                        );
                      }

                      final messages = snapshot.data!;
                      if (messages.isEmpty) {
                        return const AppMessageState(
                          icon: Icons.chat_bubble_outline_rounded,
                          message: 'No messages yet in this thread.',
                        );
                      }

                      return ListView.separated(
                        reverse: true,
                        itemCount: messages.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMine =
                              message.senderId == widget.currentUserId;
                          return Align(
                            alignment: isMine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 300),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isMine
                                    ? const Color(0xFF14B8A6)
                                        .withValues(alpha: 0.16)
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isMine ? 'You' : message.senderName,
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(message.message),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        DateFormat('dd MMM, hh:mm a')
                                            .format(message.createdAt),
                                        style: GoogleFonts.manrope(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.58),
                                        ),
                                      ),
                                      if (isMine) ...[
                                        const SizedBox(width: 8),
                                        Icon(
                                          message.isSeen
                                              ? Icons.done_all_rounded
                                              : message.isDelivered
                                                  ? Icons.done_rounded
                                                  : Icons.schedule_rounded,
                                          size: 15,
                                          color: message.isSeen
                                              ? const Color(0xFF0F766E)
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.55),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _composerController,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Reply to this bidder',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      onPressed: _isSending ? null : () => _sendReply(thread),
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendReply(AuctionChatThread thread) async {
    final text = _composerController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _isSending = true;
    });
    try {
      await widget.service.sendMessage(
        chatId: thread.id,
        auctionId: widget.auctionId,
        creatorId: widget.currentUserId,
        userId: widget.currentUserId,
        receiverId: thread.otherParticipant(widget.currentUserId),
        userName: widget.currentUserName,
        message: text,
      );
      _composerController.clear();
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.auctionTitle)),
      body: StreamBuilder<List<AuctionChatThread>>(
        stream: widget.service.streamAuctionChatsForParticipant(
          auctionId: widget.auctionId,
          participantId: widget.currentUserId,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const AppMessageState(
              icon: Icons.cloud_off_rounded,
              message: 'Unable to load chat threads right now.',
            );
          }
          if (!snapshot.hasData) {
            return const AppLoadingIndicator(
              label: 'Loading conversations...',
            );
          }

          final threads = snapshot.data!;
          if (threads.isEmpty) {
            return const AppMessageState(
              icon: Icons.mark_chat_read_outlined,
              message:
                  'Bidder conversations for this auction will appear here.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: threads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final thread = threads[index];
              final counterpart = thread.otherParticipant(widget.currentUserId);
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  onTap: () => _openThread(thread),
                  leading: CircleAvatar(
                    child: Text(counterpart.characters.first.toUpperCase()),
                  ),
                  title: Text(
                    counterpart,
                    style: GoogleFonts.sora(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        thread.lastMessage.isEmpty
                            ? 'Open the conversation'
                            : thread.lastMessage,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('dd MMM, hh:mm a').format(thread.updatedAt),
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.58),
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _composerController.dispose();
    super.dispose();
  }
}
