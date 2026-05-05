import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/auction.dart';
import '../providers/app_theme_provider.dart';
import '../providers/auth_provider.dart';
import '../services/local_notification_service.dart';
import '../services/user_home_service.dart';
import 'auction_detail_screen.dart';
import 'create_auction_screen.dart';
import 'live_auction_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final UserHomeService _service = UserHomeService();
  int _selectedIndex = 0;

  late final List<Widget> _tabs = [
    _HomeTab(service: _service),
    _UpcomingAuctionsTab(service: _service),
    CreateAuctionScreen(
      embedded: true,
      onCreated: () => setState(() {
        _selectedIndex = 1;
      }),
    ),
    _MyAuctionsTab(service: _service),
    ProfileScreen(),
  ];

  void _selectTab(int index) {
    if (_selectedIndex == index) {
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBody: true,
      backgroundColor:
          isDark ? const Color(0xFF07111F) : const Color(0xFFF6F8FB),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: IndexedStack(
          key: ValueKey(_selectedIndex),
          index: _selectedIndex,
          children: _tabs,
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _selectTab,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFF0F766E),
            unselectedItemColor:
                isDark ? Colors.white70 : const Color(0xFF6B7280),
            backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
            selectedLabelStyle: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
            unselectedLabelStyle: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.event_available_rounded),
                label: 'Upcoming',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.add_circle_outline_rounded),
                label: 'Create',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                label: 'My Auctions',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.service});

  final UserHomeService service;

  static const List<String> _taglines = [
    'Bid with confidence. Every second counts.',
    'A smarter marketplace is waiting for you.',
    'Track future auctions before the rush begins.',
    'Fair prices, cleaner decisions, better timing.',
    'Your next winning bid starts with preparation.',
    'Discover verified opportunities before they go live.',
    'Stay ready for the auctions that matter.',
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.userProfile;
    final userId = authProvider.firebaseUser?.uid;
    final dayIndex = DateTime.now().difference(DateTime(2026)).inDays.abs() %
        _taglines.length;

    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: _HomeTopBar(service: service, userId: userId),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: _WelcomePanel(
                name: user?.fullName.trim().isNotEmpty == true
                    ? user!.fullName
                    : 'FairBid user',
                tagline: _taglines[dayIndex],
              ),
            ),
          ),
          StreamBuilder<List<Auction>>(
            stream: service.streamFutureAuctions(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    icon: Icons.cloud_off_rounded,
                    message: 'Unable to load auctions right now.',
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final auctions = snapshot.data!;
              if (auctions.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    icon: Icons.event_busy_rounded,
                    message: 'No live or upcoming auctions are available yet.',
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 112),
                sliver: SliverList.separated(
                  itemCount: auctions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final auction = auctions[index];
                    return _AnimatedAuctionCard(
                      index: index,
                      child: _AuctionCard(
                        auction: auction,
                        userId: userId,
                        service: service,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({required this.service, required this.userId});

  final UserHomeService service;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final themeProvider = context.watch<AppThemeProvider>();

    return Row(
      children: [
        Text(
          'FairBid',
          style: GoogleFonts.sora(
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        _CircleIconButton(
          tooltip: 'Theme',
          onPressed: themeProvider.toggleTheme,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            transitionBuilder: (child, animation) {
              return RotationTransition(
                turns: Tween<double>(begin: 0.65, end: 1).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: Icon(
              themeProvider.isDarkMode
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              key: ValueKey(themeProvider.isDarkMode),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _NotificationBell(service: service, userId: userId),
        const SizedBox(width: 10),
        _CircleIconButton(
          tooltip: 'Logout',
          onPressed: authProvider.logout,
          child: const Icon(Icons.logout_rounded),
        ),
      ],
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.service, required this.userId});

  final UserHomeService service;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return _CircleIconButton(
        tooltip: 'Notifications',
        onPressed: () {},
        child: const Icon(Icons.notifications_none_rounded),
      );
    }

    return StreamBuilder<int>(
      stream: service.streamUnreadNotificationCount(userId!),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            _CircleIconButton(
              tooltip: 'Notifications',
              onPressed: () => _showNotificationsSheet(context),
              child: AnimatedScale(
                scale: count > 0 ? 1.08 : 1,
                duration: const Duration(milliseconds: 220),
                child: const Icon(Icons.notifications_none_rounded),
              ),
            ),
            if (count > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    showNotificationCenterSheet(
      context: context,
      title: 'Notifications',
      receiverId: userId,
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({required this.name, required this.tagline});

  final String name;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF0F766E), Color(0xFF111827)]
              : const [Color(0xFFCCFBF1), Color(0xFFFFFFFF)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, $name',
            style: GoogleFonts.sora(
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            tagline,
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuctionCard extends StatelessWidget {
  const _AuctionCard({
    required this.auction,
    required this.userId,
    required this.service,
  });

  final Auction auction;
  final String? userId;
  final UserHomeService service;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF111827) : Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AuctionDetailScreen(auction: auction),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      auction.title,
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _MiniCategory(label: auction.category),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                auction.description.isEmpty
                    ? 'No description provided.'
                    : auction.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.64),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CardFact(
                    icon: Icons.schedule_rounded,
                    label:
                        DateFormat('dd MMM, hh:mm a').format(auction.startTime),
                  ),
                  _CardFact(
                    icon: Icons.currency_rupee_rounded,
                    label: auction.reservePrice.toStringAsFixed(0),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CardReactions(
                auctionId: auction.id,
                userId: userId,
                service: service,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardReactions extends StatelessWidget {
  const _CardReactions({
    required this.auctionId,
    required this.userId,
    required this.service,
  });

  final String auctionId;
  final String? userId;
  final UserHomeService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, int>>(
      stream: service.streamReactionCounts(auctionId),
      builder: (context, countSnapshot) {
        final counts = countSnapshot.data ?? const {'like': 0, 'dislike': 0};
        if (userId == null) {
          return Row(
            children: [
              _ReactionPill(
                icon: Icons.thumb_up_alt_outlined,
                label: '${counts['like'] ?? 0}',
              ),
              const SizedBox(width: 8),
              _ReactionPill(
                icon: Icons.thumb_down_alt_outlined,
                label: '${counts['dislike'] ?? 0}',
              ),
            ],
          );
        }
        return StreamBuilder<String?>(
          stream: service.streamReaction(auctionId: auctionId, userId: userId!),
          builder: (context, reactionSnapshot) {
            final reaction = reactionSnapshot.data;
            return Row(
              children: [
                _ReactionPill(
                  icon: reaction == 'like'
                      ? Icons.thumb_up_alt_rounded
                      : Icons.thumb_up_alt_outlined,
                  label: '${counts['like'] ?? 0}',
                  selected: reaction == 'like',
                  onTap: () => service.toggleReaction(
                    auctionId: auctionId,
                    userId: userId!,
                    value: 'like',
                  ),
                ),
                const SizedBox(width: 8),
                _ReactionPill(
                  icon: reaction == 'dislike'
                      ? Icons.thumb_down_alt_rounded
                      : Icons.thumb_down_alt_outlined,
                  label: '${counts['dislike'] ?? 0}',
                  selected: reaction == 'dislike',
                  onTap: () => service.toggleReaction(
                    auctionId: auctionId,
                    userId: userId!,
                    value: 'dislike',
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded),
              ],
            );
          },
        );
      },
    );
  }
}

class _UpcomingAuctionsTab extends StatelessWidget {
  const _UpcomingAuctionsTab({required this.service});

  final UserHomeService service;

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().firebaseUser?.uid;
    return _ScaffoldedTab(
      title: 'My Upcoming Auctions',
      child: userId == null
          ? const _EmptyState(
              icon: Icons.lock_outline_rounded,
              message: 'Sign in again to view your upcoming auctions.',
            )
          : StreamBuilder<List<AuctionReminder>>(
              stream: service.streamMyReminders(userId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const _EmptyState(
                    icon: Icons.cloud_off_rounded,
                    message: 'Unable to load reminders right now.',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final reminders = snapshot.data!;
                if (reminders.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.notifications_none_rounded,
                    message: 'Auction reminders you save will appear here.',
                  );
                }
                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 112),
                  itemCount: reminders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _AnimatedAuctionCard(
                      index: index,
                      child: _ReminderTile(
                        reminder: reminders[index],
                        userId: userId,
                        service: service,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _MyAuctionsTab extends StatelessWidget {
  const _MyAuctionsTab({required this.service});

  final UserHomeService service;

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().firebaseUser?.uid;
    return _ScaffoldedTab(
      title: 'My Auctions',
      child: userId == null
          ? const _EmptyState(
              icon: Icons.lock_outline_rounded,
              message: 'Sign in again to manage your auctions.',
            )
          : StreamBuilder<List<ManagedAuction>>(
              stream: service.streamMyManagedAuctions(userId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const _EmptyState(
                    icon: Icons.cloud_off_rounded,
                    message: 'Unable to load your auctions.',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final auctions = snapshot.data!;
                if (auctions.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.inventory_2_outlined,
                    message: 'Auction requests you create will appear here.',
                  );
                }
                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 112),
                  itemCount: auctions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _OwnerAuctionTile(
                      item: auctions[index],
                      service: service,
                    );
                  },
                );
              },
            ),
    );
  }
}

class _ReminderTile extends StatefulWidget {
  const _ReminderTile({
    required this.reminder,
    required this.userId,
    required this.service,
  });

  final AuctionReminder reminder;
  final String userId;
  final UserHomeService service;

  @override
  State<_ReminderTile> createState() => _ReminderTileState();
}

class _ReminderTileState extends State<_ReminderTile> {
  late Timer _timer;
  late Duration _remaining;
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.reminder.startsAt.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _tick() async {
    if (!mounted) {
      return;
    }
    final remaining = widget.reminder.startsAt.difference(DateTime.now());
    setState(() {
      _remaining = remaining.isNegative ? Duration.zero : remaining;
    });
    if (!_hasTriggered && remaining <= Duration.zero) {
      _hasTriggered = true;
      await LocalNotificationService.instance.showAuctionStartingNow(
        id: widget.reminder.auctionId.hashCode.abs(),
        title: widget.reminder.title,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.reminder.title} is starting now.')),
      );
    }
  }

  Future<void> _cancel() async {
    await widget.service.cancelAuctionReminder(
      userId: widget.userId,
      auctionId: widget.reminder.auctionId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          widget.reminder.title,
          style: GoogleFonts.sora(fontWeight: FontWeight.w800),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(
              DateFormat('dd MMM yyyy, hh:mm a')
                  .format(widget.reminder.startsAt),
            ),
            const SizedBox(height: 6),
            Text(
              'Starts in: ${_formatDuration(_remaining)}',
              style: GoogleFonts.manrope(
                color: const Color(0xFF0F766E),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          tooltip: 'Cancel reminder',
          onPressed: _cancel,
          icon: const Icon(Icons.close_rounded),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}

class _OwnerAuctionTile extends StatelessWidget {
  const _OwnerAuctionTile({required this.item, required this.service});

  final ManagedAuction item;
  final UserHomeService service;
  Auction get auction => item.auction;

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete auction?'),
        content: Text('This removes "${auction.title}" from FairBid.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    await service.deleteMyAuctionRequest(auction.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auction deleted.')),
      );
    }
  }

  Future<void> _edit(BuildContext context) async {
    if (!item.canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only pending auction requests can be edited.'),
        ),
      );
      return;
    }

    final titleController = TextEditingController(text: auction.title);
    final priceController =
        TextEditingController(text: auction.reservePrice.toStringAsFixed(0));
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit auction'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) =>
                    value?.trim().isEmpty == true ? 'Title required' : null,
              ),
              TextFormField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Starting price'),
                validator: (value) => double.tryParse(value ?? '') == null
                    ? 'Invalid price'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) {
                return;
              }
              await service.updateMyAuctionRequest(
                auction.copyWith(
                  title: titleController.text.trim(),
                  reservePrice: double.parse(priceController.text),
                  currentPrice: double.parse(priceController.text),
                ),
              );
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    titleController.dispose();
    priceController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stateLabel = switch (auction.state) {
      'LIVE' => 'LIVE',
      'PAUSED' => 'PAUSED',
      'SOLD' => 'SOLD',
      'ENDED' => 'ENDED',
      _ => item.collection == 'auctions'
          ? 'APPROVED'
          : auction.status.toUpperCase(),
    };

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          auction.title,
          style: GoogleFonts.sora(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${auction.category} - ${DateFormat('dd MMM, hh:mm a').format(auction.startTime)} - $stateLabel',
        ),
        trailing: Wrap(
          spacing: 8,
          children: [
            if (item.canJoinLive)
              IconButton(
                tooltip: 'Open live room',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LiveAuctionScreen(auctionId: auction.id),
                    ),
                  );
                },
                icon: const Icon(Icons.play_circle_outline_rounded),
              ),
            IconButton(
              tooltip: 'Edit',
              onPressed: item.canEdit ? () => _edit(context) : null,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: item.canDelete ? () => _delete(context) : null,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScaffoldedTab extends StatelessWidget {
  const _ScaffoldedTab({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.sora(
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _AnimatedAuctionCard extends StatelessWidget {
  const _AnimatedAuctionCard({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (index.clamp(0, 5) * 55)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(width: 44, height: 44, child: Center(child: child)),
        ),
      ),
    );
  }
}

class _MiniCategory extends StatelessWidget {
  const _MiniCategory({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107).withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: const Color(0xFF9A6700),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CardFact extends StatelessWidget {
  const _CardFact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionPill extends StatefulWidget {
  const _ReactionPill({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_ReactionPill> createState() => _ReactionPillState();
}

class _ReactionPillState extends State<_ReactionPill> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 140),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: widget.onTap == null
            ? null
            : () async {
                setState(() {
                  _scale = 0.92;
                });
                await Future<void>.delayed(const Duration(milliseconds: 80));
                if (mounted) {
                  setState(() {
                    _scale = 1;
                  });
                }
                widget.onTap?.call();
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? const Color(0xFF14B8A6).withValues(alpha: 0.18)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 17,
                color: widget.selected ? const Color(0xFF0F766E) : null,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: const Color(0xFF0F766E)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.68),
              ),
            ),
          ],
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
