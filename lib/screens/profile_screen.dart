import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/complaint.dart';
import '../providers/auth_provider.dart';
import '../services/complaint_service.dart';
import '../utils/auth_validators.dart';

class ProfileScreen extends StatelessWidget {
  ProfileScreen({super.key, ComplaintService? complaintService})
      : _complaintService = complaintService ?? ComplaintService();

  final ComplaintService _complaintService;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.userProfile;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          _ProfileHero(userName: user.fullName, email: user.email),
          if (authProvider.isBlocked) ...[
            const SizedBox(height: 14),
            const _StatusBanner(
              icon: Icons.block_rounded,
              color: Color(0xFFDC2626),
              message:
                  'Your account is blocked. Profile edits and complaints are disabled.',
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: authProvider.isBlocked
                      ? null
                      : () => _showEditProfileSheet(context),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Profile'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: authProvider.isBlocked
                      ? null
                      : () => _showComplaintSheet(context),
                  icon: const Icon(Icons.report_problem_outlined),
                  label: const Text('Raise Complaint'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _InfoPanel(
            title: 'Profile Details',
            child: Column(
              children: [
                _ProfileInfoRow(
                  icon: Icons.phone_iphone_rounded,
                  label: 'Phone',
                  value:
                      user.phoneNumber.isEmpty ? 'Not added' : user.phoneNumber,
                ),
                _ProfileInfoRow(
                  icon: Icons.cake_outlined,
                  label: 'Date of birth',
                  value: DateFormat('dd MMM yyyy').format(user.dateOfBirth),
                ),
                _ProfileInfoRow(
                  icon: Icons.verified_user_outlined,
                  label: 'Account status',
                  value: authProvider.accountStatus.toUpperCase(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Complaint History',
            style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Complaint>>(
            stream: _complaintService.streamUserComplaints(user.uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const _StatusBanner(
                  icon: Icons.cloud_off_rounded,
                  color: Color(0xFFB45309),
                  message: 'Unable to load your complaints right now.',
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final complaints = snapshot.data!;
              if (complaints.isEmpty) {
                return const _InfoPanel(
                  title: 'No complaints yet',
                  child: Text(
                    'When you raise a complaint, the admin reply will appear here in real time.',
                  ),
                );
              }

              return Column(
                children: complaints
                    .map((complaint) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ComplaintCard(complaint: complaint),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: authProvider.logout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditProfileSheet(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.userProfile;
    if (user == null) {
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: user.fullName);
    final phoneController = TextEditingController(text: user.phoneNumber);
    final dobController = TextEditingController(
        text: DateFormat('dd MMM yyyy').format(user.dateOfBirth));
    var selectedDate = user.dateOfBirth;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(1940),
                lastDate:
                    DateTime.now().subtract(const Duration(days: 365 * 18)),
              );
              if (picked == null || !context.mounted) {
                return;
              }
              setModalState(() {
                selectedDate = picked;
                dobController.text = DateFormat('dd MMM yyyy').format(picked);
              });
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit profile',
                      style: GoogleFonts.sora(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: nameController,
                      validator: AuthValidators.fullName,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: phoneController,
                      validator: AuthValidators.phone,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        prefixIcon: Icon(Icons.phone_iphone_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: dobController,
                      readOnly: true,
                      onTap: pickDate,
                      validator: (_) =>
                          AuthValidators.dateOfBirth(selectedDate),
                      decoration: const InputDecoration(
                        labelText: 'Date of birth',
                        prefixIcon: Icon(Icons.cake_outlined),
                        suffixIcon: Icon(Icons.calendar_month_rounded),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Consumer<AuthProvider>(
                      builder: (context, provider, child) {
                        return SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: provider.isProfileSaving
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    final success =
                                        await provider.updateProfile(
                                      fullName: nameController.text.trim(),
                                      phoneNumber: phoneController.text.trim(),
                                      dateOfBirth: selectedDate,
                                    );
                                    if (!context.mounted) {
                                      return;
                                    }
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: success
                                            ? const Color(0xFF0F766E)
                                            : const Color(0xFFB3261E),
                                        content: Text(
                                          success
                                              ? 'Profile updated successfully.'
                                              : provider.authError ??
                                                  'Unable to update profile.',
                                        ),
                                      ),
                                    );
                                  },
                            child: Text(
                              provider.isProfileSaving
                                  ? 'Saving...'
                                  : 'Save changes',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    dobController.dispose();
  }

  Future<void> _showComplaintSheet(BuildContext context) async {
    final controller = TextEditingController();
    final user = context.read<AuthProvider>().userProfile;
    if (user == null) {
      return;
    }
    final formKey = GlobalKey<FormState>();

    final complaintMessage = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
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
                  'Raise a complaint',
                  style: GoogleFonts.sora(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Describe the issue clearly so the admin can respond faster.',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  minLines: 5,
                  maxLines: 8,
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Complaint message is required';
                    }
                    if ((value ?? '').trim().length < 10) {
                      return 'Please provide a little more detail';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    hintText: 'Write your complaint here...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.tonal(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) {
                        return;
                      }
                      Navigator.of(
                        sheetContext,
                      ).pop(controller.text.trim());
                    },
                    child: const Text(
                      'Submit complaint',
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

    if (complaintMessage == null || !context.mounted) {
      return;
    }

    try {
      await _complaintService.submitComplaint(
        user: user,
        message: complaintMessage,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Complaint submitted. The admin has been notified.',
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

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.userName,
    required this.email,
  });

  final String userName;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F766E), Color(0xFF1D4ED8)],
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            child: Text(
              userName.isEmpty ? 'F' : userName[0].toUpperCase(),
              style: GoogleFonts.sora(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            userName,
            textAlign: TextAlign.center,
            style: GoogleFonts.sora(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            email,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: Colors.white.withValues(alpha: 0.76),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF14B8A6).withValues(alpha: 0.15),
            child: Icon(icon, size: 18, color: const Color(0xFF0F766E)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.56),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({required this.complaint});

  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
    final color = complaint.isResolved
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  complaint.status.toUpperCase(),
                  style: GoogleFonts.manrope(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('dd MMM, hh:mm a').format(complaint.timestamp),
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            complaint.message,
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
          ),
          if (complaint.adminReply.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xFF0F766E).withValues(alpha: 0.10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin reply',
                    style: GoogleFonts.manrope(
                      color: const Color(0xFF0F766E),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(complaint.adminReply),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
