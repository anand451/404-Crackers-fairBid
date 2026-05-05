import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    try {
      await androidPlugin?.requestExactAlarmsPermission();
    } catch (_) {
      // Some Android versions do not expose exact alarm settings. Scheduling
      // still works with the best available mode.
    }

    _isInitialized = true;
  }

  Future<void> scheduleAuctionStartReminder({
    required int id,
    required String title,
    required DateTime startsAt,
  }) async {
    await initialize();

    final now = DateTime.now();
    if (!startsAt.isAfter(now)) {
      await showAuctionStartingNow(id: id, title: title);
      return;
    }

    await _plugin.zonedSchedule(
      id: id,
      title: 'Auction timer finished',
      body: '$title is starting now.',
      scheduledDate: tz.TZDateTime.from(startsAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'fairbid_auction_start',
          'Auction start reminders',
          channelDescription: 'Notifications for auctions users follow.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> showAuctionStartingNow({
    required int id,
    required String title,
  }) async {
    await initialize();
    await _plugin.show(
      id: id,
      title: 'Auction timer finished',
      body: '$title is starting now.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'fairbid_auction_start',
          'Auction start reminders',
          channelDescription: 'Notifications for auctions users follow.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> showInboxNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'fairbid_inbox',
          'FairBid inbox',
          channelDescription: 'Complaint and admin notifications from FairBid.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> cancel(int id) async {
    await initialize();
    await _plugin.cancel(id: id);
  }
}
