import 'package:cloud_firestore/cloud_firestore.dart';

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
    return document.id;
  }

  Future<void> markAsRead(String notificationId) async {
    await _notifications.doc(notificationId).set({
      'readStatus': true,
      'readAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
}
