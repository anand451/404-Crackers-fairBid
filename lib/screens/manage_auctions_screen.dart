import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/auction.dart';
import '../services/admin_service.dart';

class ManageAuctionsScreen extends StatefulWidget {
  const ManageAuctionsScreen({super.key});

  @override
  State<ManageAuctionsScreen> createState() => _ManageAuctionsScreenState();
}

class _ManageAuctionsScreenState extends State<ManageAuctionsScreen> {
  final AdminService _adminService = AdminService();

  Future<void> _confirmDelete(Auction auction) async {
    final shouldDelete = await _showConfirmationDialog(
      title: 'Delete auction?',
      description:
          'This will permanently remove "${auction.title}" from the marketplace.',
      confirmLabel: 'Delete',
      accentColor: const Color(0xFFFF6B6B),
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    try {
      await _adminService.deleteAuction(auction.id);
      _showSnackBar('Auction deleted successfully.', isError: false);
    } catch (_) {
      _showSnackBar('Unable to delete auction right now.', isError: true);
    }
  }

  Future<void> _confirmStatusChange(Auction auction, String status) async {
    final isApprove = status == 'approved';
    final confirmed = await _showConfirmationDialog(
      title: isApprove ? 'Approve auction?' : 'Reject auction?',
      description: isApprove
          ? 'This will make "${auction.title}" visible to buyers.'
          : 'This will mark "${auction.title}" as rejected.',
      confirmLabel: isApprove ? 'Approve' : 'Reject',
      accentColor:
          isApprove ? const Color(0xFF34D399) : const Color(0xFFFF6B6B),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await _adminService.updateAuctionStatus(
        auctionId: auction.id,
        status: status,
      );
      _showSnackBar(
        isApprove ? 'Auction approved.' : 'Auction rejected.',
        isError: false,
      );
    } catch (_) {
      _showSnackBar('Could not update auction status.', isError: true);
    }
  }

  Future<void> _showEditDialog(Auction auction) async {
    final titleController = TextEditingController(text: auction.title);
    final descriptionController =
        TextEditingController(text: auction.description);
    final reserveController = TextEditingController(
      text: auction.reservePrice.toStringAsFixed(0),
    );
    final currentController = TextEditingController(
      text: auction.currentPrice.toStringAsFixed(0),
    );
    DateTime selectedEndTime = auction.endTime;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final palette = AdminUiPalette.of(dialogContext);
        return AlertDialog(
          backgroundColor: palette.dialogBackground,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text(
            'Edit Auction',
            style: GoogleFonts.sora(
              color: palette.primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _DialogField(
                        controller: titleController,
                        label: 'Title',
                        validator: (value) => (value?.trim().isEmpty ?? true)
                            ? 'Title required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _DialogField(
                        controller: descriptionController,
                        label: 'Description',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      _DialogField(
                        controller: reserveController,
                        label: 'Reserve price',
                        keyboardType: TextInputType.number,
                        validator: (value) =>
                            double.tryParse(value ?? '') == null
                                ? 'Invalid price'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      _DialogField(
                        controller: currentController,
                        label: 'Current price',
                        keyboardType: TextInputType.number,
                        validator: (value) =>
                            double.tryParse(value ?? '') == null
                                ? 'Invalid price'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Ends ${DateFormat('dd MMM yyyy, hh:mm a').format(selectedEndTime)}',
                          style: GoogleFonts.manrope(color: palette.primaryText),
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedEndTime,
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date == null || !context.mounted) {
                              return;
                            }
                            final time = await showTimePicker(
                              context: context,
                              initialTime:
                                  TimeOfDay.fromDateTime(selectedEndTime),
                            );
                            if (time == null || !context.mounted) {
                              return;
                            }
                            setState(() {
                              selectedEndTime = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          },
                          child: const Text('Change'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
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
                try {
                  final updatedAuction = auction.copyWith(
                    title: titleController.text.trim(),
                    description: descriptionController.text.trim(),
                    reservePrice: double.parse(reserveController.text),
                    currentPrice: double.parse(currentController.text),
                    endTime: selectedEndTime,
                  );
                  await _adminService.updateAuction(updatedAuction);
                  if (!dialogContext.mounted || !mounted) {
                    return;
                  }
                  Navigator.of(dialogContext).pop();
                  _showSnackBar('Auction details updated.', isError: false);
                } catch (_) {
                  if (!mounted) {
                    return;
                  }
                  _showSnackBar(
                    'Could not update auction details.',
                    isError: true,
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    reserveController.dispose();
    currentController.dispose();
  }

  Future<void> _showComments(Auction auction) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final palette = AdminUiPalette.of(context);
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: palette.sheetBackground,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border.all(color: palette.panelBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comments',
                    style: GoogleFonts.sora(
                      color: palette.primaryText,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (auction.comments.isEmpty)
                    Text(
                      'No user comments have been attached to this auction yet.',
                      style: GoogleFonts.manrope(
                        color: palette.secondaryText,
                      ),
                    )
                  else
                    SizedBox(
                      height: 320,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemBuilder: (context, index) {
                          final comment = auction.comments[index];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: palette.tileBackground,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comment.userName,
                                  style: GoogleFonts.manrope(
                                    color: palette.primaryText,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  comment.message,
                                  style: GoogleFonts.manrope(
                                    color: palette.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemCount: auction.comments.length,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool?> _showConfirmationDialog({
    required String title,
    required String description,
    required String confirmLabel,
    required Color accentColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final palette = AdminUiPalette.of(context);
        return AlertDialog(
          backgroundColor: palette.dialogBackground,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text(
            title,
            style: GoogleFonts.sora(
              color: palette.primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            description,
            style: GoogleFonts.manrope(
              color: palette.secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: accentColor),
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
      stream: _adminService.streamAllAuctions(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const AdminStateCard(
            message: 'Unable to load auctions right now.',
            icon: Icons.error_outline_rounded,
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final auctions = snapshot.data!;
        if (auctions.isEmpty) {
          return const AdminStateCard(
            message: 'No auctions have been approved yet.',
            icon: Icons.gavel_rounded,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          itemCount: auctions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final palette = AdminUiPalette.of(context);
            final auction = auctions[index];
            return AdminGlassCard(
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
                                color: palette.primaryText,
                                fontWeight: FontWeight.w700,
                                fontSize: 19,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              auction.description.isEmpty
                                  ? 'No description provided.'
                                  : auction.description,
                              style: GoogleFonts.manrope(
                                color: palette.secondaryText,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      AuctionStatusBadge(
                        status: auction.isSold ||
                                auction.isEnded ||
                                auction.isLive ||
                                auction.isPaused
                            ? auction.state.toLowerCase()
                            : auction.status,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      AdminInfoPill(
                        icon: Icons.person_outline_rounded,
                        label: auction.sellerName.isEmpty
                            ? 'Unknown seller'
                            : auction.sellerName,
                      ),
                      AdminInfoPill(
                        icon: Icons.currency_rupee_rounded,
                        label:
                            'Reserve ${auction.reservePrice.toStringAsFixed(0)}',
                      ),
                      AdminInfoPill(
                        icon: Icons.bolt_rounded,
                        label:
                            'Current ${auction.currentPrice.toStringAsFixed(0)}',
                      ),
                      if (auction.finalPrice != null)
                        AdminInfoPill(
                          icon: Icons.payments_rounded,
                          label:
                              'Final ${auction.finalPrice!.toStringAsFixed(0)}',
                        ),
                      AdminInfoPill(
                        icon: Icons.account_balance_wallet_outlined,
                        label: auction.paymentStatus.toUpperCase(),
                      ),
                      AdminInfoPill(
                        icon: Icons.schedule_rounded,
                        label: DateFormat('dd MMM, hh:mm a')
                            .format(auction.endTime),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showComments(auction),
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                          label: Text('Comments (${auction.comments.length})'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showEditDialog(auction),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: auction.isApproved
                              ? null
                              : () => _confirmStatusChange(auction, 'approved'),
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: const Text('Approve'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: auction.isRejected
                              ? null
                              : () => _confirmStatusChange(auction, 'rejected'),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                const Color(0xFFEF4444).withValues(
                                  alpha: palette.isDark ? 0.16 : 0.12,
                                ),
                            foregroundColor: palette.isDark
                                ? const Color(0xFFFFB4AB)
                                : const Color(0xFFB42318),
                          ),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        onPressed: () => _confirmDelete(auction),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFEF4444).withValues(
                                alpha: palette.isDark ? 0.16 : 0.12,
                              ),
                        ),
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: palette.isDark
                              ? const Color(0xFFFFB4AB)
                              : const Color(0xFFB42318),
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

class AdminGlassCard extends StatelessWidget {
  const AdminGlassCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = AdminUiPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: palette.panelBackground,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: palette.panelBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

class AuctionStatusBadge extends StatelessWidget {
  const AuctionStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final palette = AdminUiPalette.of(context);
    final (background, foreground) = switch (status) {
      'approved' => (
          const Color(0xFF14B8A6).withValues(
            alpha: palette.isDark ? 0.20 : 0.14,
          ),
          palette.isDark ? const Color(0xFF99F6E4) : const Color(0xFF0F766E),
        ),
      'live' => (
          const Color(0xFF14B8A6).withValues(
            alpha: palette.isDark ? 0.20 : 0.14,
          ),
          palette.isDark ? const Color(0xFF99F6E4) : const Color(0xFF0F766E),
        ),
      'paused' => (
          const Color(0xFFFFC107).withValues(
            alpha: palette.isDark ? 0.20 : 0.18,
          ),
          palette.isDark ? const Color(0xFFFFE082) : const Color(0xFF92400E),
        ),
      'sold' => (
          const Color(0xFFF97316).withValues(
            alpha: palette.isDark ? 0.20 : 0.16,
          ),
          palette.isDark ? const Color(0xFFFFD7B5) : const Color(0xFFC2410C),
        ),
      'ended' => (
          const Color(0xFFEF4444).withValues(
            alpha: palette.isDark ? 0.20 : 0.14,
          ),
          palette.isDark ? const Color(0xFFFFB4AB) : const Color(0xFFB42318),
        ),
      'rejected' => (
          const Color(0xFFEF4444).withValues(
            alpha: palette.isDark ? 0.20 : 0.14,
          ),
          palette.isDark ? const Color(0xFFFFB4AB) : const Color(0xFFB42318),
        ),
      'pending' => (
          const Color(0xFFFFC107).withValues(
            alpha: palette.isDark ? 0.20 : 0.18,
          ),
          palette.isDark ? const Color(0xFFFFE082) : const Color(0xFF92400E),
        ),
      _ => (
          const Color(0xFFFFC107).withValues(
            alpha: palette.isDark ? 0.20 : 0.18,
          ),
          palette.isDark ? const Color(0xFFFFE082) : const Color(0xFF92400E),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.manrope(
          color: foreground,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class AdminInfoPill extends StatelessWidget {
  const AdminInfoPill({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = AdminUiPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.tileBackground,
        borderRadius: BorderRadius.circular(16),
        border: palette.isDark
            ? null
            : Border.all(color: palette.panelBorder.withValues(alpha: 0.72)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: palette.isDark
                ? const Color(0xFFFFD54F)
                : const Color(0xFFD97706),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.manrope(
              color: palette.primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final palette = AdminUiPalette.of(context);
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: palette.primaryText),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: palette.secondaryText),
      ),
    );
  }
}

class AdminStateCard extends StatelessWidget {
  const AdminStateCard({
    super.key,
    required this.message,
    required this.icon,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = AdminUiPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AdminGlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: const Color(0xFFFFD54F)),
              const SizedBox(height: 14),
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
      ),
    );
  }
}

class AdminUiPalette {
  AdminUiPalette._(BuildContext context)
      : theme = Theme.of(context),
        colorScheme = Theme.of(context).colorScheme,
        isDark = Theme.of(context).brightness == Brightness.dark;

  factory AdminUiPalette.of(BuildContext context) => AdminUiPalette._(context);

  final ThemeData theme;
  final ColorScheme colorScheme;
  final bool isDark;

  Color get panelBackground => isDark
      ? Colors.white.withValues(alpha: 0.10)
      : Colors.white.withValues(alpha: 0.88);

  Color get panelBorder => isDark
      ? Colors.white.withValues(alpha: 0.14)
      : const Color(0xFFD3E3DF);

  Color get tileBackground => isDark
      ? Colors.white.withValues(alpha: 0.06)
      : const Color(0xFFF2F7FA);

  Color get dialogBackground => isDark ? const Color(0xFF0E213E) : Colors.white;

  Color get sheetBackground => isDark
      ? const Color(0xFF0E213E).withValues(alpha: 0.94)
      : Colors.white.withValues(alpha: 0.97);

  Color get primaryText => isDark ? Colors.white : const Color(0xFF10213A);

  Color get secondaryText => isDark
      ? Colors.white.withValues(alpha: 0.72)
      : const Color(0xFF486072);

  Color get tertiaryText => isDark
      ? Colors.white.withValues(alpha: 0.56)
      : const Color(0xFF6A8091);
}
