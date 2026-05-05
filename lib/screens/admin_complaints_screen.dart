import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/complaint.dart';
import '../providers/auth_provider.dart';
import '../services/complaint_service.dart';
import 'manage_auctions_screen.dart';

class AdminComplaintsScreen extends StatelessWidget {
  AdminComplaintsScreen({super.key, ComplaintService? complaintService})
      : _complaintService = complaintService ?? ComplaintService();

  final ComplaintService _complaintService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Complaint>>(
      stream: _complaintService.streamAllComplaints(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _AdminStateCard(
            icon: Icons.cloud_off_rounded,
            message: 'Unable to load complaints right now.\n${snapshot.error}',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final complaints = snapshot.data!;
        if (complaints.isEmpty) {
          return const _AdminStateCard(
            icon: Icons.support_agent_rounded,
            message: 'No complaints have been raised yet.',
          );
        }

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          itemCount: complaints.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final complaint = complaints[index];
            return _ComplaintAdminCard(
              complaint: complaint,
              onReply: () => _showReplySheet(context, complaint),
            );
          },
        );
      },
    );
  }

  Future<void> _showReplySheet(
      BuildContext context, Complaint complaint) async {
    final controller = TextEditingController(text: complaint.adminReply);
    final formKey = GlobalKey<FormState>();
    final adminId = context.read<AuthProvider>().firebaseUser?.uid;
    if (adminId == null) {
      return;
    }

    final replyMessage = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final palette = AdminUiPalette.of(sheetContext);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reply to complaint',
                  style: GoogleFonts.sora(
                    color: palette.primaryText,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  complaint.message,
                  style: GoogleFonts.manrope(
                    color: palette.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  minLines: 4,
                  maxLines: 7,
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Reply is required';
                    }
                    return null;
                  },
                  style: TextStyle(color: palette.primaryText),
                  decoration: InputDecoration(
                    hintText: 'Write your response...',
                    hintStyle: TextStyle(color: palette.secondaryText),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) {
                        return;
                      }
                      Navigator.of(
                        sheetContext,
                      ).pop(controller.text.trim());
                    },
                    child: const Text(
                      'Resolve complaint',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();

    if (replyMessage == null || !context.mounted) {
      return;
    }

    try {
      await _complaintService.replyToComplaint(
        complaint: complaint,
        adminId: adminId,
        reply: replyMessage,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Reply sent and user notified.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFB3261E),
          content: Text(error.toString()),
        ),
      );
    }
  }
}

class _ComplaintAdminCard extends StatelessWidget {
  const _ComplaintAdminCard({
    required this.complaint,
    required this.onReply,
  });

  final Complaint complaint;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final palette = AdminUiPalette.of(context);
    final statusColor = complaint.isResolved
        ? const Color(0xFF34D399)
        : const Color(0xFFFFC107);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: palette.panelBackground,
        border: Border.all(color: palette.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  complaint.userName,
                  style: GoogleFonts.sora(
                    color: palette.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
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
                  complaint.status.toUpperCase(),
                  style: GoogleFonts.manrope(
                    color: statusColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            complaint.userEmail,
            style: GoogleFonts.manrope(
              color: palette.secondaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            complaint.message,
            style: GoogleFonts.manrope(
              color: palette.primaryText,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          if (complaint.adminReply.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xFF14B8A6).withValues(
                  alpha: palette.isDark ? 0.16 : 0.12,
                ),
              ),
              child: Text(
                complaint.adminReply,
                style: GoogleFonts.manrope(
                  color: palette.primaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                DateFormat('dd MMM, hh:mm a').format(complaint.timestamp),
                style: GoogleFonts.manrope(
                  color: palette.tertiaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFC107).withValues(alpha: 0.22),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: onReply,
                  icon: const Icon(Icons.reply_rounded),
                  label: Text(complaint.isResolved ? 'Update' : 'Reply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminStateCard extends StatelessWidget {
  const _AdminStateCard({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = AdminUiPalette.of(context);
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
                color: palette.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
