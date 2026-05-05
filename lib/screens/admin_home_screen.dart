import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/app_theme_provider.dart';
import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import 'admin_complaints_screen.dart';
import 'admin_dashboard.dart';
import 'admin_users_screen.dart';
import 'notifications_screen.dart';
import 'auction_requests_screen.dart';
import 'manage_auctions_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;

  static const _titles = [
    'Manage Auctions',
    'Auction Requests',
    'Complaints',
    'Users',
    'Admin Dashboard',
  ];

  final _pages = [
    const ManageAuctionsScreen(),
    const AuctionRequestsScreen(),
    AdminComplaintsScreen(),
    AdminUsersScreen(),
    const AdminDashboard(),
  ];

  void _changeTab(int index) {
    if (_selectedIndex == index) {
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    Color(0xFF04111F),
                    Color(0xFF0B2A45),
                    Color(0xFF0F6A71),
                  ]
                : const [
                    Color(0xFFF4FFFD),
                    Color(0xFFE6F4FF),
                    Color(0xFFD9F7EC),
                  ],
          ),
        ),
        child: Stack(
          children: [
            const _AdminBackdrop(),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: _GlassHeader(
                      title: _titles[_selectedIndex],
                      subtitle:
                          authProvider.userProfile?.fullName ?? 'FairBid Admin',
                      adminId: authProvider.firebaseUser?.uid,
                      isDark: isDark,
                      onLogout: () => context.read<AuthProvider>().logout(),
                      onToggleTheme: () =>
                          context.read<AppThemeProvider>().toggleTheme(),
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final offset = Tween<Offset>(
                          begin: const Offset(0.08, 0),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child:
                              SlideTransition(position: offset, child: child),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey(_selectedIndex),
                        child: _pages[_selectedIndex],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: _AdminBottomBar(
                      selectedIndex: _selectedIndex,
                      onSelected: _changeTab,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassHeader extends StatelessWidget {
  const _GlassHeader({
    required this.title,
    required this.subtitle,
    required this.adminId,
    required this.isDark,
    required this.onLogout,
    required this.onToggleTheme,
  });

  final String title;
  final String subtitle;
  final String? adminId;
  final bool isDark;
  final VoidCallback onLogout;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final notificationService = NotificationService();
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.72),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : const Color(0xFFB6D6CC),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.sora(
                        color: isDark ? Colors.white : const Color(0xFF10213A),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: GoogleFonts.manrope(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.72)
                            : const Color(0xFF425466),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: onToggleTheme,
                style: IconButton.styleFrom(
                  backgroundColor: isDark
                      ? const Color(0xFF67E8F9).withValues(alpha: 0.16)
                      : const Color(0xFF0F766E).withValues(alpha: 0.12),
                ),
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: isDark
                      ? const Color(0xFFB6F7FF)
                      : const Color(0xFF0F766E),
                ),
              ),
              const SizedBox(width: 10),
              if (adminId != null) ...[
                StreamBuilder<int>(
                  stream: notificationService.streamAdminUnreadCount(),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton.filledTonal(
                          onPressed: () => showNotificationCenterSheet(
                            context: context,
                            title: 'Admin Notifications',
                            adminInbox: true,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: isDark
                                ? const Color(0xFF67E8F9)
                                    .withValues(alpha: 0.16)
                                : const Color(0xFF0F766E)
                                    .withValues(alpha: 0.12),
                          ),
                          icon: Icon(
                            Icons.notifications_active_outlined,
                            color: isDark
                                ? const Color(0xFFB6F7FF)
                                : const Color(0xFF0F766E),
                          ),
                        ),
                        if (count > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFB7185),
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
                ),
                const SizedBox(width: 10),
              ],
              IconButton.filledTonal(
                onPressed: onLogout,
                style: IconButton.styleFrom(
                  backgroundColor:
                      const Color(0xFFFFC107).withValues(alpha: 0.2),
                ),
                icon:
                    const Icon(Icons.logout_rounded, color: Color(0xFFFFE082)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminBottomBar extends StatelessWidget {
  const _AdminBottomBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.gavel_rounded, 'Auctions'),
      (Icons.pending_actions_rounded, 'Requests'),
      (Icons.support_agent_rounded, 'Support'),
      (Icons.group_rounded, 'Users'),
      (Icons.analytics_rounded, 'Pulse'),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: List.generate(items.length, (index) {
              final isActive = index == selectedIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onSelected(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: isActive
                          ? const Color(0xFFFFC107)
                          : Colors.transparent,
                      boxShadow: [
                        if (isActive)
                          BoxShadow(
                            color:
                                const Color(0xFFFFC107).withValues(alpha: 0.28),
                            blurRadius: 22,
                            spreadRadius: 1,
                          ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          items[index].$1,
                          color: isActive
                              ? const Color(0xFF10213A)
                              : Colors.white.withValues(alpha: 0.78),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          items[index].$2,
                          style: GoogleFonts.manrope(
                            color: isActive
                                ? const Color(0xFF10213A)
                                : Colors.white.withValues(alpha: 0.78),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _AdminBackdrop extends StatelessWidget {
  const _AdminBackdrop();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned(
          top: -80,
          left: -60,
          child: _GlowBall(
            size: 220,
            colors: [Color(0xCC00D1B2), Color(0x0000D1B2)],
          ),
        ),
        Positioned(
          right: -70,
          top: 190,
          child: _GlowBall(
            size: 200,
            colors: [Color(0xAAFFC107), Color(0x00FFC107)],
          ),
        ),
        Positioned(
          right: -100,
          bottom: -110,
          child: _GlowBall(
            size: 260,
            colors: [Color(0xAA3B82F6), Color(0x003B82F6)],
          ),
        ),
      ],
    );
  }
}

class _GlowBall extends StatelessWidget {
  const _GlowBall({
    required this.size,
    required this.colors,
  });

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}
