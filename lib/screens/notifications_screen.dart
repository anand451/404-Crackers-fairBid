import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/widgets/app_state_widgets.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';

Future<void> showNotificationCenterSheet({
  required BuildContext context,
  required String title,
  String? receiverId,
  bool adminInbox = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.82,
        child: NotificationCenterSheet(
          title: title,
          receiverId: receiverId,
          adminInbox: adminInbox,
        ),
      );
    },
  );
}

class NotificationCenterSheet extends StatelessWidget {
  NotificationCenterSheet({
    super.key,
    required this.title,
    this.receiverId,
    this.adminInbox = false,
    NotificationService? notificationService,
  }) : _notificationService = notificationService ?? NotificationService();

  final String title;
  final String? receiverId;
  final bool adminInbox;
  final NotificationService _notificationService;

  @override
  Widget build(BuildContext context) {
    final stream = adminInbox
        ? _notificationService.streamAdminNotifications()
        : _notificationService.streamUserNotifications(receiverId ?? '');
    final hasTarget = adminInbox || (receiverId?.isNotEmpty ?? false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.sora(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: hasTarget
                    ? () => adminInbox
                        ? _notificationService.deleteAllAdminNotifications()
                        : _notificationService
                            .deleteAllUserNotifications(receiverId ?? '')
                    : null,
                child: const Text('Clear all'),
              ),
              TextButton(
                onPressed: hasTarget
                    ? () => adminInbox
                        ? _notificationService.markAllAdminNotificationsAsRead()
                        : _notificationService
                            .markAllUserNotificationsAsRead(receiverId ?? '')
                    : null,
                child: const Text('Mark all read'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<AppNotification>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const AppMessageState(
                    icon: Icons.cloud_off_rounded,
                    message: 'Unable to load notifications right now.',
                  );
                }
                if (!snapshot.hasData) {
                  return const AppLoadingIndicator(
                    label: 'Loading notifications...',
                  );
                }

                final notifications = snapshot.data!;
                if (notifications.isEmpty) {
                  return const AppMessageState(
                    icon: Icons.notifications_none_rounded,
                    message: 'You are all caught up.',
                  );
                }

                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = notifications[index];
                    return _NotificationTile(
                      notification: item,
                      onTap: () async {
                        if (!item.readStatus) {
                          await _notificationService.markAsRead(item.id);
                        }
                      },
                      onDelete: () =>
                          _notificationService.deleteNotification(item.id),
                      onMarkRead: item.readStatus
                          ? null
                          : () => _notificationService.markAsRead(item.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDelete,
    this.onMarkRead,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    final accent = switch (notification.type) {
      'complaint' => const Color(0xFFFB7185),
      'auction' => const Color(0xFF14B8A6),
      'payment' => const Color(0xFF6366F1),
      _ => const Color(0xFFFFC107),
    };

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: const Color(0xFFEF4444),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: notification.readStatus
              ? Theme.of(context).colorScheme.surface
              : accent.withValues(alpha: 0.10),
          border: Border.all(
            color: notification.readStatus
                ? Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.4)
                : accent.withValues(alpha: 0.35),
          ),
        ),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.all(18),
          leading: CircleAvatar(
            backgroundColor: accent.withValues(alpha: 0.18),
            child: Icon(_iconFor(notification.type), color: accent),
          ),
          title: Text(
            notification.title,
            style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.message),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _TypePill(type: notification.type, color: accent),
                    Text(
                      DateFormat('dd MMM, hh:mm a')
                          .format(notification.timestamp),
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.56),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'read':
                  onMarkRead?.call();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (context) => [
              if (!notification.readStatus)
                const PopupMenuItem<String>(
                  value: 'read',
                  child: Text('Mark as read'),
                ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
            icon: notification.readStatus
                ? const Icon(Icons.more_horiz_rounded)
                : Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    return switch (type) {
      'complaint' => Icons.support_agent_rounded,
      'auction' => Icons.notifications_active_outlined,
      'payment' => Icons.payments_outlined,
      _ => Icons.campaign_rounded,
    };
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({
    required this.type,
    required this.color,
  });

  final String type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      'complaint' => 'Complaint reply',
      'auction' => 'Auction alert',
      'payment' => 'Payment update',
      _ => 'Admin message',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
