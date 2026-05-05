import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/auction.dart';
import '../providers/auth_provider.dart';
import '../services/admin_service.dart';
import 'manage_auctions_screen.dart';

class AuctionRequestsScreen extends StatefulWidget {
  const AuctionRequestsScreen({super.key});

  @override
  State<AuctionRequestsScreen> createState() => _AuctionRequestsScreenState();
}

class _AuctionRequestsScreenState extends State<AuctionRequestsScreen> {
  final AdminService _adminService = AdminService();

  Future<void> _approveRequest(Auction request) async {
    final confirmed = await _confirmAction(
      title: 'Approve request?',
      description:
          'This will publish "${request.title}" to the live auction marketplace.',
      confirmLabel: 'Approve',
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await _adminService.approveAuctionRequest(
        request: request,
        adminId: context.read<AuthProvider>().firebaseUser?.uid ?? 'admin',
      );
      _showSnackBar('Auction request approved.', isError: false);
    } catch (_) {
      _showSnackBar('Could not approve this request.', isError: true);
    }
  }

  Future<void> _rejectRequest(Auction request) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E213E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text(
            'Reject request?',
            style: GoogleFonts.sora(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You can optionally add a short note for why this request is being rejected.',
                style: GoogleFonts.manrope(
                  color: Colors.white.withValues(alpha: 0.74),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      reasonController.dispose();
      return;
    }

    try {
      await _adminService.rejectAuctionRequest(
        request: request,
        adminId: context.read<AuthProvider>().firebaseUser?.uid ?? 'admin',
        reason: reasonController.text.trim().isEmpty
            ? null
            : reasonController.text.trim(),
      );
      _showSnackBar('Auction request rejected.', isError: false);
    } catch (_) {
      _showSnackBar('Could not reject this request.', isError: true);
    } finally {
      reasonController.dispose();
    }
  }

  Future<bool?> _confirmAction({
    required String title,
    required String description,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E213E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text(
            title,
            style: GoogleFonts.sora(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            description,
            style: GoogleFonts.manrope(
              color: Colors.white.withValues(alpha: 0.74),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF14B8A6),
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Auction>>(
      stream: _adminService.streamPendingAuctionRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const AdminStateCard(
            message: 'We could not load auction requests.',
            icon: Icons.error_outline_rounded,
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!;
        if (requests.isEmpty) {
          return const AdminStateCard(
            message: 'No pending auction requests right now.',
            icon: Icons.pending_actions_rounded,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final request = requests[index];

            return AdminGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          request.title,
                          style: GoogleFonts.sora(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 19,
                          ),
                        ),
                      ),
                      const AuctionStatusBadge(status: 'pending'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    request.description.isEmpty
                        ? 'No description provided.'
                        : request.description,
                    style: GoogleFonts.manrope(
                      color: Colors.white.withValues(alpha: 0.72),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      AdminInfoPill(
                        icon: Icons.person_outline_rounded,
                        label: request.sellerName.isEmpty
                            ? 'Unknown seller'
                            : request.sellerName,
                      ),
                      AdminInfoPill(
                        icon: Icons.mail_outline_rounded,
                        label: request.sellerEmail.isEmpty
                            ? 'No email provided'
                            : request.sellerEmail,
                      ),
                      AdminInfoPill(
                        icon: Icons.currency_rupee_rounded,
                        label:
                            'Reserve ${request.reservePrice.toStringAsFixed(0)}',
                      ),
                      AdminInfoPill(
                        icon: Icons.schedule_rounded,
                        label: DateFormat('dd MMM, hh:mm a')
                            .format(request.createdAt),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _approveRequest(request),
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: const Text('Approve'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () => _rejectRequest(request),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                const Color(0xFFEF4444).withValues(alpha: 0.18),
                            foregroundColor: const Color(0xFFFFB4AB),
                          ),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Reject'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
