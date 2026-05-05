import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/user_management_service.dart';

class AdminUsersScreen extends StatelessWidget {
  AdminUsersScreen({super.key, UserManagementService? userManagementService})
      : _userManagementService =
            userManagementService ?? UserManagementService();

  final UserManagementService _userManagementService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      stream: _userManagementService.streamUsers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _AdminUsersStateCard(
            icon: Icons.cloud_off_rounded,
            message: 'Unable to load users right now.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!;
        if (users.isEmpty) {
          return const _AdminUsersStateCard(
            icon: Icons.group_off_rounded,
            message: 'No users found.',
          );
        }

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            return _UserAdminCard(
              user: users[index],
              onNotify: () => _showNotifyDialog(context, users[index]),
              onToggleStatus: () => _toggleUserStatus(context, users[index]),
            );
          },
        );
      },
    );
  }

  Future<void> _showNotifyDialog(BuildContext context, UserModel user) async {
    final controller = TextEditingController();
    final adminId = context.read<AuthProvider>().firebaseUser?.uid;
    if (adminId == null) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'Send notification',
            style: GoogleFonts.sora(fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Write a message for ${user.fullName}',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (controller.text.trim().isEmpty) {
                  return;
                }
                await _userManagementService.sendNotificationToUser(
                  receiverId: user.uid,
                  senderId: adminId,
                  title: 'FairBid admin message',
                  message: controller.text.trim(),
                );
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    behavior: SnackBarBehavior.floating,
                    content: Text('Notification sent to user.'),
                  ),
                );
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  Future<void> _toggleUserStatus(BuildContext context, UserModel user) async {
    final adminId = context.read<AuthProvider>().firebaseUser?.uid;
    if (adminId == null) {
      return;
    }
    if (user.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Admin accounts cannot be blocked from this screen.'),
        ),
      );
      return;
    }

    await _userManagementService.updateUserStatus(
      user: user,
      blocked: !user.isBlocked,
      adminId: adminId,
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          user.isBlocked
              ? 'User restored and notified.'
              : 'User blocked and notified.',
        ),
      ),
    );
  }
}

class _UserAdminCard extends StatelessWidget {
  const _UserAdminCard({
    required this.user,
    required this.onNotify,
    required this.onToggleStatus,
  });

  final UserModel user;
  final VoidCallback onNotify;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        user.isBlocked ? const Color(0xFFFB7185) : const Color(0xFF34D399);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: statusColor.withValues(alpha: 0.16),
                child: Text(
                  user.fullName.isEmpty ? 'U' : user.fullName[0].toUpperCase(),
                  style: GoogleFonts.sora(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: GoogleFonts.sora(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: GoogleFonts.manrope(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: statusColor.withValues(alpha: 0.16),
                ),
                child: Text(
                  user.isBlocked ? 'BLOCKED' : 'ACTIVE',
                  style: GoogleFonts.manrope(
                    color: statusColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onNotify,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Notify'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side:
                        BorderSide(color: Colors.white.withValues(alpha: 0.22)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.25),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: FilledButton.icon(
                    onPressed: onToggleStatus,
                    style: FilledButton.styleFrom(
                      backgroundColor: statusColor.withValues(alpha: 0.92),
                      foregroundColor: const Color(0xFF08111F),
                    ),
                    icon: Icon(
                      user.isBlocked
                          ? Icons.lock_open_rounded
                          : Icons.block_rounded,
                    ),
                    label: Text(user.isBlocked ? 'Restore' : 'Block'),
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

class _AdminUsersStateCard extends StatelessWidget {
  const _AdminUsersStateCard({
    required this.icon,
    required this.message,
  });

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
    );
  }
}
