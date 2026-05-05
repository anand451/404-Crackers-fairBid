import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/auction.dart';
import '../models/auction_watcher.dart';
import '../models/bid.dart';
import '../models/payment_record.dart';
import '../providers/auth_provider.dart';
import '../services/auction_service.dart';

class LiveAuctionScreen extends StatefulWidget {
  const LiveAuctionScreen({
    super.key,
    required this.auctionId,
  });

  final String auctionId;

  @override
  State<LiveAuctionScreen> createState() => _LiveAuctionScreenState();
}

class _LiveAuctionScreenState extends State<LiveAuctionScreen> {
  final AuctionService _auctionService = AuctionService();
  final TextEditingController _bidController = TextEditingController();
  late Timer _ticker;
  DateTime _now = DateTime.now();
  bool _isSubmittingBid = false;
  bool _isRunningSellerAction = false;
  bool _isSubmittingPayment = false;
  String? _watcherUserId;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _now = DateTime.now();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.firebaseUser?.uid;
      if (userId == null) {
        return;
      }
      _watcherUserId = userId;
      try {
        await _auctionService.upsertWatcher(
          auctionId: widget.auctionId,
          userId: userId,
          userName: authProvider.userProfile?.fullName ?? 'FairBid user',
        );
      } catch (_) {
        // Presence is best-effort. The auction screen should remain usable.
      }
    });
  }

  Future<void> _placeBid(Auction auction) async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.firebaseUser?.uid;
    final userName = authProvider.userProfile?.fullName ?? 'FairBid user';
    final amount = double.tryParse(_bidController.text.trim());

    if (userId == null || !authProvider.canInteract) {
      _showSnackBar('Your account cannot place bids right now.', isError: true);
      return;
    }
    if (amount == null || amount <= 0) {
      _showSnackBar('Enter a valid bid amount.', isError: true);
      return;
    }

    setState(() {
      _isSubmittingBid = true;
    });
    try {
      await _auctionService.placeBid(
        auctionId: auction.id,
        bidderId: userId,
        bidderName: userName,
        amount: amount,
      );
      _bidController.clear();
      _showSnackBar('Bid placed successfully.');
    } catch (error) {
      _showSnackBar(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingBid = false;
        });
      }
    }
  }

  Future<void> _runSellerAction(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    setState(() {
      _isRunningSellerAction = true;
    });
    try {
      await action();
      _showSnackBar(successMessage);
    } catch (error) {
      _showSnackBar(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isRunningSellerAction = false;
        });
      }
    }
  }

  Future<void> _launchUpi(Auction auction) async {
    final amount = auction.finalPrice ?? auction.currentPrice;
    if (auction.upiId.trim().isEmpty) {
      _showSnackBar('Seller UPI ID is missing for this auction.',
          isError: true);
      return;
    }

    final uri = _auctionService.buildUpiPaymentUri(
      auction: auction,
      amount: amount,
    );
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _showSnackBar('No UPI app was available to open.', isError: true);
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('Unable to open a UPI app right now.', isError: true);
      }
    }
  }

  Future<void> _submitPayment(Auction auction) async {
    final authProvider = context.read<AuthProvider>();
    final buyerId = authProvider.firebaseUser?.uid;
    final buyerName = authProvider.userProfile?.fullName ?? 'Buyer';
    if (buyerId == null) {
      return;
    }

    setState(() {
      _isSubmittingPayment = true;
    });
    try {
      await _auctionService.submitWinnerPayment(
        auction: auction,
        buyerId: buyerId,
        buyerName: buyerName,
      );
      _showSnackBar('Payment recorded and receipt generated.');
    } catch (error) {
      _showSnackBar(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingPayment = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? const Color(0xFFB3261E) : const Color(0xFF0F766E),
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUserId = authProvider.firebaseUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        title: const Text('Live Auction'),
        actions: [
          if (currentUserId != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  authProvider.userProfile?.fullName ?? 'Viewer',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
      body: StreamBuilder<Auction?>(
        stream: _auctionService.watchAuctionById(widget.auctionId),
        builder: (context, auctionSnapshot) {
          if (auctionSnapshot.hasError) {
            return const _LiveStateCard(
              icon: Icons.cloud_off_rounded,
              message: 'Unable to load the live auction right now.',
            );
          }
          if (!auctionSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final auction = auctionSnapshot.data;
          if (auction == null) {
            return const _LiveStateCard(
              icon: Icons.gavel_rounded,
              message: 'This auction is no longer available.',
            );
          }

          final isSeller = currentUserId == auction.sellerId;
          final isWinner =
              currentUserId != null && currentUserId == auction.winnerId;
          final effectiveState = _effectiveState(auction);
          final canBid = auction.status == 'approved' &&
              effectiveState == 'LIVE' &&
              !isSeller &&
              authProvider.canInteract;

          return StreamBuilder<List<Bid>>(
            stream: _auctionService.streamAuctionBids(auction.id),
            builder: (context, bidSnapshot) {
              final bids = bidSnapshot.data ?? const <Bid>[];
              final topBid = bids.isNotEmpty ? bids.first : null;

              return StreamBuilder<List<AuctionWatcher>>(
                stream: _auctionService.streamAuctionWatchers(auction.id),
                builder: (context, watcherSnapshot) {
                  final watchers =
                      watcherSnapshot.data ?? const <AuctionWatcher>[];

                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                    children: [
                      _AuctionHero(
                        auction: auction,
                        effectiveState: effectiveState,
                        now: _now,
                        watcherCount: watchers.length,
                      ),
                      const SizedBox(height: 16),
                      _WatchersPanel(watchers: watchers),
                      const SizedBox(height: 16),
                      if (isSeller)
                        _SellerControlsPanel(
                          auction: auction,
                          effectiveState: effectiveState,
                          isBusy: _isRunningSellerAction,
                          onStart: () => _runSellerAction(
                            () => _auctionService.startAuction(
                              auction: auction,
                              sellerId: auction.sellerId,
                            ),
                            successMessage: auction.isPaused
                                ? 'Auction resumed.'
                                : 'Auction started.',
                          ),
                          onPause: () => _runSellerAction(
                            () => _auctionService.pauseAuction(
                              auction: auction,
                              sellerId: auction.sellerId,
                            ),
                            successMessage: 'Auction paused.',
                          ),
                          onEnd: () => _runSellerAction(
                            () => _auctionService.endAuction(
                              auction: auction,
                              sellerId: auction.sellerId,
                            ),
                            successMessage: 'Auction ended.',
                          ),
                          onSellHighest: topBid == null
                              ? null
                              : () => _runSellerAction(
                                    () => _auctionService.sellAuction(
                                      auction: auction,
                                      bid: topBid,
                                      sellerId: auction.sellerId,
                                    ),
                                    successMessage:
                                        'Auction sold to the highest bidder.',
                                  ),
                        ),
                      if (isSeller) const SizedBox(height: 16),
                      _BidsPanel(
                        auction: auction,
                        effectiveState: effectiveState,
                        currentUserId: currentUserId,
                        bids: bids,
                        onSellBid: !isSeller
                            ? null
                            : (bid) => _runSellerAction(
                                  () => _auctionService.sellAuction(
                                    auction: auction,
                                    bid: bid,
                                    sellerId: auction.sellerId,
                                  ),
                                  successMessage:
                                      'Auction sold to ${bid.userName}.',
                                ),
                      ),
                      const SizedBox(height: 16),
                      if (canBid)
                        _BidComposer(
                          controller: _bidController,
                          currentPrice: auction.currentPrice,
                          isSubmitting: _isSubmittingBid,
                          onSubmit: () => _placeBid(auction),
                        )
                      else
                        _BidStatusCard(
                          effectiveState: effectiveState,
                          isSeller: isSeller,
                          isWinner: isWinner,
                        ),
                      if (auction.isSold) ...[
                        const SizedBox(height: 16),
                        StreamBuilder<PaymentRecord?>(
                          stream: auction.winnerId == null
                              ? Stream<PaymentRecord?>.value(null)
                              : _auctionService.watchPaymentForAuctionAndBuyer(
                                  auctionId: auction.id,
                                  buyerId: auction.winnerId!,
                                ),
                          builder: (context, paymentSnapshot) {
                            return _PaymentPanel(
                              auction: auction,
                              isWinner: isWinner,
                              isSeller: isSeller,
                              payment: paymentSnapshot.data,
                              isSubmittingPayment: _isSubmittingPayment,
                              onLaunchUpi: () => _launchUpi(auction),
                              onSubmitPayment: () => _submitPayment(auction),
                            );
                          },
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _effectiveState(Auction auction) {
    if (auction.state == 'LIVE' && !auction.endTime.isAfter(_now)) {
      return 'ENDED';
    }
    return auction.state;
  }

  @override
  void dispose() {
    _ticker.cancel();
    final watcherUserId = _watcherUserId;
    if (watcherUserId != null) {
      unawaited(
        _auctionService.removeWatcher(
          auctionId: widget.auctionId,
          userId: watcherUserId,
        ),
      );
    }
    _bidController.dispose();
    super.dispose();
  }
}

class _AuctionHero extends StatelessWidget {
  const _AuctionHero({
    required this.auction,
    required this.effectiveState,
    required this.now,
    required this.watcherCount,
  });

  final Auction auction;
  final String effectiveState;
  final DateTime now;
  final int watcherCount;

  @override
  Widget build(BuildContext context) {
    final amount = auction.finalPrice ?? auction.currentPrice;
    final remaining = effectiveState == 'PAUSED'
        ? Duration(seconds: auction.remainingSeconds)
        : auction.endTime.difference(now);
    final safeRemaining = remaining.isNegative ? Duration.zero : remaining;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14B8A6), Color(0xFF123B74), Color(0xFF07111F)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14B8A6).withValues(alpha: 0.22),
            blurRadius: 28,
            spreadRadius: 2,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auction.title,
                      style: GoogleFonts.sora(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      auction.description.isEmpty
                          ? 'Live auction room'
                          : auction.description,
                      style: GoogleFonts.manrope(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _StateBadge(label: effectiveState),
            ],
          ),
          const SizedBox(height: 22),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: amount),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Text(
                'Rs ${value.toStringAsFixed(0)}',
                style: GoogleFonts.sora(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  shadows: const [
                    Shadow(
                      offset: Offset(0, 3),
                      blurRadius: 14,
                      color: Colors.black45,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroPill(
                icon: Icons.person_outline_rounded,
                label: auction.sellerName.isEmpty
                    ? 'Unknown seller'
                    : auction.sellerName,
              ),
              _HeroPill(
                icon: Icons.visibility_outlined,
                label: '$watcherCount watching',
              ),
              _HeroPill(
                icon: Icons.timer_outlined,
                label: _countdownLabel(effectiveState, safeRemaining, auction),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _countdownLabel(
    String effectiveState,
    Duration remaining,
    Auction auction,
  ) {
    if (effectiveState == 'SOLD') {
      return 'Sold';
    }
    if (effectiveState == 'ENDED') {
      return 'Ended';
    }
    if (effectiveState == 'PENDING') {
      return 'Ready to start';
    }
    if (effectiveState == 'PAUSED') {
      return 'Paused at ${_formatDuration(remaining)}';
    }
    return _formatDuration(remaining);
  }
}

class _WatchersPanel extends StatelessWidget {
  const _WatchersPanel({required this.watchers});

  final List<AuctionWatcher> watchers;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Watchers',
      child: watchers.isEmpty
          ? Text(
              'No one else is watching yet.',
              style: GoogleFonts.manrope(
                color: Colors.white.withValues(alpha: 0.68),
                fontWeight: FontWeight.w600,
              ),
            )
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: watchers
                  .map(
                    (watcher) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor:
                                const Color(0xFFFFC107).withValues(alpha: 0.18),
                            child: Text(
                              watcher.userName.isEmpty
                                  ? 'W'
                                  : watcher.userName[0].toUpperCase(),
                              style: GoogleFonts.sora(
                                color: const Color(0xFFFFE082),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            watcher.userName,
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _SellerControlsPanel extends StatelessWidget {
  const _SellerControlsPanel({
    required this.auction,
    required this.effectiveState,
    required this.isBusy,
    required this.onStart,
    required this.onPause,
    required this.onEnd,
    required this.onSellHighest,
  });

  final Auction auction;
  final String effectiveState;
  final bool isBusy;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onEnd;
  final VoidCallback? onSellHighest;

  @override
  Widget build(BuildContext context) {
    final canStart = effectiveState == 'PENDING' || effectiveState == 'PAUSED';
    final canPause = effectiveState == 'LIVE';
    final canEnd = effectiveState == 'LIVE' ||
        effectiveState == 'PAUSED' ||
        effectiveState == 'PENDING';
    final canSell = onSellHighest != null &&
        (effectiveState == 'LIVE' || effectiveState == 'PAUSED');

    return _SectionCard(
      title: 'Seller Controls',
      glowColor: const Color(0xFFFFC107),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: !canStart || isBusy ? null : onStart,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(effectiveState == 'PAUSED' ? 'Resume' : 'Start'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: !canPause || isBusy ? null : onPause,
                  icon: const Icon(Icons.pause_rounded),
                  label: const Text('Pause'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: !canEnd || isBusy ? null : onEnd,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        const Color(0xFFEF4444).withValues(alpha: 0.18),
                    foregroundColor: const Color(0xFFFFD2CF),
                  ),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('End'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: canSell
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFFC107)
                                  .withValues(alpha: 0.26),
                              blurRadius: 20,
                              spreadRadius: 1,
                            ),
                          ]
                        : const [],
                  ),
                  child: FilledButton.icon(
                    onPressed: !canSell || isBusy ? null : onSellHighest,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC107),
                      foregroundColor: const Color(0xFF10213A),
                    ),
                    icon: const Icon(Icons.sell_rounded),
                    label: const Text('Sell Highest'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BidsPanel extends StatelessWidget {
  const _BidsPanel({
    required this.auction,
    required this.effectiveState,
    required this.currentUserId,
    required this.bids,
    required this.onSellBid,
  });

  final Auction auction;
  final String effectiveState;
  final String? currentUserId;
  final List<Bid> bids;
  final ValueChanged<Bid>? onSellBid;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Real-Time Bids',
      child: bids.isEmpty
          ? Text(
              effectiveState == 'LIVE'
                  ? 'Waiting for the first bid...'
                  : 'No bids have been placed yet.',
              style: GoogleFonts.manrope(
                color: Colors.white.withValues(alpha: 0.68),
                fontWeight: FontWeight.w600,
              ),
            )
          : Column(
              children: bids.asMap().entries.map((entry) {
                final index = entry.key;
                final bid = entry.value;
                final isHighest = index == 0;
                final isCurrentUser = currentUserId == bid.userId;
                final canSellBid = onSellBid != null &&
                    bid.userId != auction.sellerId &&
                    (effectiveState == 'LIVE' || effectiveState == 'PAUSED');

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: isHighest
                        ? LinearGradient(
                            colors: [
                              const Color(0xFFFFC107).withValues(alpha: 0.22),
                              const Color(0xFF14B8A6).withValues(alpha: 0.16),
                            ],
                          )
                        : null,
                    color:
                        isHighest ? null : Colors.white.withValues(alpha: 0.06),
                    border: Border.all(
                      color: isHighest
                          ? const Color(0xFFFFE082).withValues(alpha: 0.48)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                    boxShadow: isHighest
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFFC107)
                                  .withValues(alpha: 0.18),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                          ]
                        : const [],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isHighest
                            ? const Color(0xFFFFC107).withValues(alpha: 0.22)
                            : Colors.white.withValues(alpha: 0.08),
                        child: Text(
                          '#${index + 1}',
                          style: GoogleFonts.sora(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    isCurrentUser
                                        ? '${bid.userName} (You)'
                                        : bid.userName,
                                    style: GoogleFonts.manrope(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (isHighest) ...[
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.bolt_rounded,
                                    size: 18,
                                    color: Color(0xFFFFE082),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('dd MMM, hh:mm:ss a')
                                  .format(bid.timestamp),
                              style: GoogleFonts.manrope(
                                color: Colors.white.withValues(alpha: 0.62),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Rs ${bid.bidAmount.toStringAsFixed(0)}',
                            style: GoogleFonts.sora(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (canSellBid) ...[
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: () => onSellBid?.call(bid),
                              child: const Text('Sell'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _BidComposer extends StatelessWidget {
  const _BidComposer({
    required this.controller,
    required this.currentPrice,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final double currentPrice;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Place a Bid',
      glowColor: const Color(0xFF14B8A6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current highest bid: Rs ${currentPrice.toStringAsFixed(0)}',
            style: GoogleFonts.manrope(
              color: Colors.white.withValues(alpha: 0.74),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Your bid amount',
              prefixText: 'Rs ',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              labelStyle: const TextStyle(color: Colors.white70),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF14B8A6).withValues(alpha: 0.24),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: FilledButton.icon(
                onPressed: isSubmitting ? null : onSubmit,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.gavel_rounded),
                label: Text(isSubmitting ? 'Submitting...' : 'Place Bid'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BidStatusCard extends StatelessWidget {
  const _BidStatusCard({
    required this.effectiveState,
    required this.isSeller,
    required this.isWinner,
  });

  final String effectiveState;
  final bool isSeller;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    final message = switch (effectiveState) {
      'PENDING' => isSeller
          ? 'Use seller controls to start the auction.'
          : 'The seller has not started this auction yet.',
      'PAUSED' => 'Bidding is paused by the seller.',
      'SOLD' => isWinner
          ? 'You won this auction. Complete payment below.'
          : 'This auction has already been sold.',
      'ENDED' => 'This auction has ended.',
      _ => isSeller
          ? 'Sellers cannot bid on their own auctions.'
          : 'Bidding is unavailable right now.',
    };

    return _SectionCard(
      title: 'Bid Status',
      child: Text(
        message,
        style: GoogleFonts.manrope(
          color: Colors.white.withValues(alpha: 0.74),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PaymentPanel extends StatelessWidget {
  const _PaymentPanel({
    required this.auction,
    required this.isWinner,
    required this.isSeller,
    required this.payment,
    required this.isSubmittingPayment,
    required this.onLaunchUpi,
    required this.onSubmitPayment,
  });

  final Auction auction;
  final bool isWinner;
  final bool isSeller;
  final PaymentRecord? payment;
  final bool isSubmittingPayment;
  final VoidCallback onLaunchUpi;
  final VoidCallback onSubmitPayment;

  @override
  Widget build(BuildContext context) {
    final amount = auction.finalPrice ?? auction.currentPrice;
    final uri = AuctionService().buildUpiPaymentUri(
      auction: auction,
      amount: amount,
    );

    return _SectionCard(
      title: payment == null ? 'Settlement' : 'Receipt',
      glowColor: const Color(0xFFFFC107),
      child: payment != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Receipt ${payment!.receiptNumber}',
                  style: GoogleFonts.sora(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Auction: ${payment!.auctionTitle}',
                  style: GoogleFonts.manrope(
                    color: Colors.white.withValues(alpha: 0.80),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Amount: Rs ${payment!.amount.toStringAsFixed(0)}',
                  style: GoogleFonts.manrope(
                    color: Colors.white.withValues(alpha: 0.80),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Recorded: ${DateFormat('dd MMM yyyy, hh:mm a').format(payment!.timestamp)}',
                  style: GoogleFonts.manrope(
                    color: Colors.white.withValues(alpha: 0.80),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Status: ${payment!.status.toUpperCase()}',
                  style: GoogleFonts.manrope(
                    color: const Color(0xFF99F6E4),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWinner
                      ? 'Pay the seller through any UPI app, then confirm payment.'
                      : isSeller
                          ? 'Waiting for the winner to complete UPI payment.'
                          : 'The winning bidder can complete payment here.',
                  style: GoogleFonts.manrope(
                    color: Colors.white.withValues(alpha: 0.74),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                if (isWinner) ...[
                  Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: QrImageView(
                          data: uri.toString(),
                          size: 180,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'UPI ID: ${auction.upiId}',
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Amount: Rs ${amount.toStringAsFixed(0)}',
                    style: GoogleFonts.manrope(
                      color: Colors.white.withValues(alpha: 0.80),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onLaunchUpi,
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Open UPI App'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed:
                              isSubmittingPayment ? null : onSubmitPayment,
                          icon: isSubmittingPayment
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.verified_rounded),
                          label: Text(
                            isSubmittingPayment
                                ? 'Recording...'
                                : 'I Have Paid',
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (isSeller) ...[
                  Text(
                    'Winner: ${auction.winnerName ?? 'Unknown'}',
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Final amount: Rs ${amount.toStringAsFixed(0)}',
                    style: GoogleFonts.manrope(
                      color: Colors.white.withValues(alpha: 0.80),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.glowColor,
  });

  final String title;
  final Widget child;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withValues(alpha: 0.10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: glowColor == null
            ? const []
            : [
                BoxShadow(
                  color: glowColor!.withValues(alpha: 0.16),
                  blurRadius: 22,
                  spreadRadius: 1,
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.sora(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFFFE082)),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (label) {
      'LIVE' => (
          const Color(0xFF10B981).withValues(alpha: 0.18),
          const Color(0xFFA7F3D0),
        ),
      'PAUSED' => (
          const Color(0xFFF59E0B).withValues(alpha: 0.18),
          const Color(0xFFFDE68A),
        ),
      'SOLD' => (
          const Color(0xFFFFC107).withValues(alpha: 0.18),
          const Color(0xFFFFF3C4),
        ),
      'ENDED' => (
          const Color(0xFFEF4444).withValues(alpha: 0.18),
          const Color(0xFFFECACA),
        ),
      _ => (
          Colors.white.withValues(alpha: 0.12),
          Colors.white,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: foreground,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _LiveStateCard extends StatelessWidget {
  const _LiveStateCard({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _SectionCard(
          title: 'Live Auction',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: const Color(0xFFFFD54F)),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final safe = duration.isNegative ? Duration.zero : duration;
  final hours = safe.inHours.toString().padLeft(2, '0');
  final minutes = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
