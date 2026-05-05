import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'admin_dashboard.dart';
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
    'Admin Dashboard',
  ];

  final _pages = const [
    ManageAuctionsScreen(),
    AuctionRequestsScreen(),
    AdminDashboard(),
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF04111F),
              Color(0xFF0B2A45),
              Color(0xFF0F6A71),
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
                      onLogout: () => context.read<AuthProvider>().logout(),
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
    required this.onLogout,
  });

  final String title;
  final String subtitle;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: Colors.white.withValues(alpha: 0.10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
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
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: GoogleFonts.manrope(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
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
      (Icons.analytics_rounded, 'Dashboard'),
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
