import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';

class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  Stream<List<AppNotification>> streamUserNotifications(
    String receiverId, {
    int limit = 40,
  }) {
    return _notifications
        .where('receiverId', isEqualTo: receiverId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(AppNotification.fromDoc).toList());
  }

  Stream<List<AppNotification>> streamAdminNotifications({int limit = 40}) {
    return _notifications
        .where('receiverRole', isEqualTo: 'admin')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(AppNotification.fromDoc).toList());
  }

  Stream<int> streamUserUnreadCount(String receiverId) {
    return _notifications
        .where('receiverId', isEqualTo: receiverId)
        .where('readStatus', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Stream<int> streamAdminUnreadCount() {
    return _notifications
        .where('receiverRole', isEqualTo: 'admin')
        .where('readStatus', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Future<String> createNotification({
    required String receiverId,
    required String title,
    required String message,
    required String type,
    String? senderId,
    String? receiverRole,
    String? complaintId,
    String? auctionId,
    DateTime? startsAt,
    String? documentId,
  }) async {
    final document = documentId == null
        ? _notifications.doc()
        : _notifications.doc(documentId);
    try {
      await document.set({
        'receiverId': receiverId,
        'title': title,
        'message': message,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
        'readStatus': false,
        if (senderId != null) 'senderId': senderId,
        if (receiverRole != null) 'receiverRole': receiverRole,
        if (complaintId != null) 'complaintId': complaintId,
        if (auctionId != null) 'auctionId': auctionId,
        if (startsAt != null) 'startsAt': Timestamp.fromDate(startsAt),
      }, SetOptions(merge: true));
      _log('Notification ${document.id} saved for receiver "$receiverId"');
      return document.id;
    } on FirebaseException catch (error) {
      _log('Notification write failed [${error.code}] ${error.message}');
      rethrow;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _notifications.doc(notificationId).set({
        'readStatus': true,
        'readAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      _log('Notification read update failed [${error.code}] ${error.message}');
      rethrow;
    }
  }

  Future<void> markAllUserNotificationsAsRead(String receiverId) async {
    final snapshot = await _notifications
        .where('receiverId', isEqualTo: receiverId)
        .where('readStatus', isEqualTo: false)
        .get();
    await _markManyAsRead(snapshot.docs);
  }

  Future<void> markAllAdminNotificationsAsRead() async {
    final snapshot = await _notifications
        .where('receiverRole', isEqualTo: 'admin')
        .where('readStatus', isEqualTo: false)
        .get();
    await _markManyAsRead(snapshot.docs);
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notifications.doc(notificationId).delete();
      _log('Notification $notificationId deleted');
    } on FirebaseException catch (error) {
      _log('Notification delete failed [${error.code}] ${error.message}');
      rethrow;
    }
  }

  Future<void> deleteAllUserNotifications(String receiverId) async {
    final snapshot =
        await _notifications.where('receiverId', isEqualTo: receiverId).get();
    await _deleteMany(snapshot.docs);
  }

  Future<void> deleteAllAdminNotifications() async {
    final snapshot =
        await _notifications.where('receiverRole', isEqualTo: 'admin').get();
    await _deleteMany(snapshot.docs);
  }

  Future<void> _markManyAsRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (docs.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    for (final doc in docs) {
      batch.set(
          doc.reference,
          {
            'readStatus': true,
            'readAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> _deleteMany(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (docs.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    for (final doc in docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  void _log(String message) {
    debugPrint('[NotificationService] $message');
  }
}
