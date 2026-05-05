import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/auction.dart';
import '../providers/auth_provider.dart';
import '../services/user_home_service.dart';
import 'live_auction_screen.dart';

class AuctionDetailScreen extends StatefulWidget {
  const AuctionDetailScreen({super.key, required this.auction});

  final Auction auction;

  @override
  State<AuctionDetailScreen> createState() => _AuctionDetailScreenState();
}

class _AuctionDetailScreenState extends State<AuctionDetailScreen> {
  final UserHomeService _service = UserHomeService();
  final TextEditingController _messageController = TextEditingController();
  late Timer _timer;
  late Duration _remaining;
  bool _isSavingReminder = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.auction.startTime.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _remaining = widget.auction.startTime.difference(DateTime.now());
      });
    });
  }

  Future<void> _saveReminder() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.firebaseUser?.uid;
    if (userId == null || !authProvider.canInteract) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Your account cannot save reminders right now.'),
        ),
      );
      return;
    }

    setState(() {
      _isSavingReminder = true;
    });
    try {
      await _service.saveAuctionReminder(
        userId: userId,
        auction: widget.auction,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder saved for this auction.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save reminder right now.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingReminder = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.firebaseUser?.uid;
    if (userId == null ||
        widget.auction.sellerId.isEmpty ||
        !authProvider.canInteract) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Your account cannot send messages right now.'),
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _service.sendMessage(
        chatId: _chatId(userId),
        auctionId: widget.auction.id,
        creatorId: widget.auction.sellerId,
        userId: userId,
        userName: authProvider.userProfile?.fullName ?? 'FairBid user',
        message: _messageController.text,
      );
      _messageController.clear();
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  String _chatId(String userId) {
    return UserHomeService.chatIdFor(
      auctionId: widget.auction.id,
      creatorId: widget.auction.sellerId,
      userId: userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userId = authProvider.firebaseUser?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF111827) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF07111F) : const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Auction Details'),
        actions: [
          if (userId != null)
            _ReactionActions(
              auctionId: widget.auction.id,
              userId: userId,
              service: _service,
            ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.auction.title,
                        style: GoogleFonts.sora(
                          color: textColor,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _CategoryPill(label: widget.auction.category),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  widget.auction.description.isEmpty
                      ? 'No description provided.'
                      : widget.auction.description,
                  style: GoogleFonts.manrope(
                    color: textColor.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InfoChip(
                      icon: Icons.currency_rupee_rounded,
                      label:
                          'Starts at ${widget.auction.reservePrice.toStringAsFixed(0)}',
                    ),
                    _InfoChip(
                      icon: Icons.schedule_rounded,
                      label: DateFormat('dd MMM, hh:mm a')
                          .format(widget.auction.startTime),
                    ),
                    _InfoChip(
                      icon: Icons.timer_outlined,
                      label: '${widget.auction.durationHours}h duration',
                    ),
                    _InfoChip(
                      icon: Icons.person_outline_rounded,
                      label: widget.auction.sellerName.isEmpty
                          ? 'Unknown creator'
                          : widget.auction.sellerName,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _CountdownPanel(remaining: _remaining),
                if (widget.auction.hasLocation) ...[
                  const SizedBox(height: 18),
                  _AuctionMapPreview(auction: widget.auction),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _isSavingReminder ? null : _saveReminder,
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _isSavingReminder
                          ? const SizedBox(
                              key: ValueKey('loading'),
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.notifications_active_outlined,
                              key: ValueKey('bell'),
                            ),
                    ),
                    label: const Text('Notify Me'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.tonalIcon(
                    onPressed: widget.auction.status == 'approved' &&
                            !widget.auction.isSold &&
                            !widget.auction.isEnded
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => LiveAuctionScreen(
                                    auctionId: widget.auction.id),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.gavel_rounded),
                    label: const Text('Open Live Room'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _ChatPanel(
            service: _service,
            chatId: userId == null ? null : _chatId(userId),
            controller: _messageController,
            isSending: _isSending,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _messageController.dispose();
    super.dispose();
  }
}

class _ReactionActions extends StatelessWidget {
  const _ReactionActions({
    required this.auctionId,
    required this.userId,
    required this.service,
  });

  final String auctionId;
  final String userId;
  final UserHomeService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: service.streamReaction(auctionId: auctionId, userId: userId),
      builder: (context, snapshot) {
        final reaction = snapshot.data;
        return Row(
          children: [
            _ReactionIconButton(
              icon: Icons.thumb_up_alt_rounded,
              isSelected: reaction == 'like',
              onTap: () => service.toggleReaction(
                auctionId: auctionId,
                userId: userId,
                value: 'like',
              ),
            ),
            _ReactionIconButton(
              icon: Icons.thumb_down_alt_rounded,
              isSelected: reaction == 'dislike',
              onTap: () => service.toggleReaction(
                auctionId: auctionId,
                userId: userId,
                value: 'dislike',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReactionIconButton extends StatefulWidget {
  const _ReactionIconButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_ReactionIconButton> createState() => _ReactionIconButtonState();
}

class _ReactionIconButtonState extends State<_ReactionIconButton> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 140),
      child: IconButton(
        onPressed: () async {
          setState(() {
            _scale = 0.88;
          });
          await Future<void>.delayed(const Duration(milliseconds: 90));
          if (mounted) {
            setState(() {
              _scale = 1;
            });
          }
          widget.onTap();
        },
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Icon(
            widget.icon,
            key: ValueKey(widget.isSelected),
            color: widget.isSelected ? const Color(0xFFFFC107) : null,
          ),
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF14B8A6).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: const Color(0xFF0F766E),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      side: BorderSide.none,
    );
  }
}

class _CountdownPanel extends StatelessWidget {
  const _CountdownPanel({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final safeRemaining = remaining.isNegative ? Duration.zero : remaining;
    final hours = safeRemaining.inHours;
    final minutes = safeRemaining.inMinutes.remainder(60);
    final seconds = safeRemaining.inSeconds.remainder(60);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF101828), Color(0xFF0F766E)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Starts in',
            style: GoogleFonts.manrope(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${hours}h ${minutes}m ${seconds}s',
            style: GoogleFonts.sora(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuctionMapPreview extends StatelessWidget {
  const _AuctionMapPreview({required this.auction});

  final Auction auction;

  @override
  Widget build(BuildContext context) {
    final position = LatLng(auction.latitude!, auction.longitude!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 210,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: position,
            zoom: 15,
          ),
          markers: {
            Marker(
              markerId: const MarkerId('auction-location'),
              position: position,
              infoWindow: InfoWindow(title: auction.title),
            ),
          },
          zoomControlsEnabled: false,
          scrollGesturesEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          myLocationButtonEnabled: false,
        ),
      ),
    );
  }
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.service,
    required this.chatId,
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final UserHomeService service;
  final String? chatId;
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chat with creator',
            style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 280,
            child: chatId == null
                ? const Center(child: Text('Sign in to start a chat.'))
                : StreamBuilder<List<ChatMessage>>(
                    stream: service.streamMessages(chatId!),
                    builder: (context, snapshot) {
                      final messages = snapshot.data ?? const <ChatMessage>[];
                      if (messages.isEmpty) {
                        return const Center(
                          child:
                              Text('No messages yet. Start the conversation.'),
                        );
                      }
                      return ListView.separated(
                        reverse: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: messages.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              constraints: const BoxConstraints(maxWidth: 300),
                              decoration: BoxDecoration(
                                color: const Color(0xFF14B8A6)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message.senderName,
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(message.message),
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
                  controller: controller,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Message',
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: isSending ? null : onSend,
                icon: isSending
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
    );
  }
}
