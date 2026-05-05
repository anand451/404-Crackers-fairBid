import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/admin_service.dart';
import 'manage_auctions_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final adminService = AdminService();

    return StreamBuilder<AdminDashboardStats>(
      stream: adminService.watchDashboardStats(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const AdminStateCard(
            message: 'Unable to load dashboard analytics.',
            icon: Icons.analytics_outlined,
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data!;
        final metricCards = [
          _MetricSpec(
            label: 'Total Users',
            value: stats.totalUsers.toDouble(),
            icon: Icons.groups_rounded,
            accent: const Color(0xFF67E8F9),
          ),
          _MetricSpec(
            label: 'Total Auctions',
            value: stats.totalAuctions.toDouble(),
            icon: Icons.gavel_rounded,
            accent: const Color(0xFFFFD54F),
          ),
          _MetricSpec(
            label: 'Active Auctions',
            value: stats.activeAuctions.toDouble(),
            icon: Icons.bolt_rounded,
            accent: const Color(0xFF34D399),
          ),
          _MetricSpec(
            label: 'Revenue',
            value: stats.totalRevenue,
            icon: Icons.payments_rounded,
            accent: const Color(0xFFA78BFA),
            prefix: 'Rs ',
          ),
          _MetricSpec(
            label: 'Complaints',
            value: stats.complaintsCount.toDouble(),
            icon: Icons.report_problem_outlined,
            accent: const Color(0xFFFB7185),
          ),
        ];

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: metricCards
                    .map(
                      (metric) => SizedBox(
                        width: math.max(
                          (MediaQuery.of(context).size.width - 54) / 2,
                          160,
                        ),
                        child: _MetricCard(metric: metric),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              AdminGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Marketplace Pulse',
                      style: GoogleFonts.sora(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _PulseBars(stats: stats),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              AdminGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Complaints',
                      style: GoogleFonts.sora(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (stats.complaints.isEmpty)
                      const _SectionEmptyState(
                        label: 'No complaints have been submitted.',
                      )
                    else
                      Column(
                        children: stats.complaints.take(5).map((complaint) {
                          final title = complaint.data['title'] as String? ??
                              complaint.data['subject'] as String? ??
                              'Complaint';
                          final message =
                              complaint.data['message'] as String? ?? '';
                          final userName =
                              complaint.data['userName'] as String? ??
                                  complaint.data['userEmail'] as String? ??
                                  'Anonymous';
                          return _TimelineTile(
                            icon: Icons.report_problem_outlined,
                            title: title,
                            subtitle: '$userName - $message',
                            trailing: DateFormat('dd MMM')
                                .format(complaint.createdAt),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              AdminGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment History',
                      style: GoogleFonts.sora(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (stats.payments.isEmpty)
                      const _SectionEmptyState(
                        label: 'No payments have been recorded yet.',
                      )
                    else
                      Column(
                        children: stats.payments.take(5).map((payment) {
                          final payer = payment.data['userName'] as String? ??
                              payment.data['userEmail'] as String? ??
                              'Unknown payer';
                          final status =
                              payment.data['status'] as String? ?? 'processed';
                          return _TimelineTile(
                            icon: Icons.payments_rounded,
                            title:
                                'Rs ${payment.amount.toStringAsFixed(0)} - ${status.toUpperCase()}',
                            subtitle: payer,
                            trailing:
                                DateFormat('dd MMM').format(payment.createdAt),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _MetricSpec {
  const _MetricSpec({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.prefix = '',
  });

  final String label;
  final double value;
  final IconData icon;
  final Color accent;
  final String prefix;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _MetricSpec metric;

  @override
  Widget build(BuildContext context) {
    return AdminGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(metric.icon, color: metric.accent, size: 26),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: metric.value),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              final displayValue = metric.prefix.isNotEmpty
                  ? '${metric.prefix}${value.toStringAsFixed(0)}'
                  : value.toStringAsFixed(0);
              return Text(
                displayValue,
                style: GoogleFonts.sora(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            metric.label,
            style: GoogleFonts.manrope(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseBars extends StatelessWidget {
  const _PulseBars({required this.stats});

  final AdminDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('Users', stats.totalUsers.toDouble(), const Color(0xFF67E8F9)),
      ('Auctions', stats.totalAuctions.toDouble(), const Color(0xFFFFD54F)),
      ('Active', stats.activeAuctions.toDouble(), const Color(0xFF34D399)),
      ('Complaints', stats.complaintsCount.toDouble(), const Color(0xFFFB7185)),
    ];
    final maxValue = values.fold<double>(
      1,
      (current, item) => math.max(current, item.$2),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: values.map((item) {
        final heightFactor = (item.$2 / maxValue).clamp(0.12, 1.0);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  height: 36 + (110 * heightFactor),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        item.$3.withValues(alpha: 0.28),
                        item.$3,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: item.$3.withValues(alpha: 0.22),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item.$1,
                  style: GoogleFonts.manrope(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFFFD54F)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            trailing,
            style: GoogleFonts.manrope(
              color: Colors.white.withValues(alpha: 0.56),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionEmptyState extends StatelessWidget {
  const _SectionEmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: Colors.white.withValues(alpha: 0.72),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
