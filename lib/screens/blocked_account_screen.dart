import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class BlockedAccountScreen extends StatelessWidget {
  const BlockedAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final name = authProvider.userProfile?.fullName ?? 'FairBid user';

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF190E11), Color(0xFF5A1B1B), Color(0xFF1F2937)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: Colors.white.withValues(alpha: 0.08),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 34,
                      backgroundColor: Color(0x33FB7185),
                      child: Icon(
                        Icons.block_rounded,
                        color: Color(0xFFFB7185),
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Account Restricted',
                      style: GoogleFonts.sora(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$name can no longer access FairBid features because this account is blocked.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        color: Colors.white.withValues(alpha: 0.80),
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: () => context.read<AuthProvider>().logout(),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
