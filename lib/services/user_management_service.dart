import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import 'notification_service.dart';

class UserManagementService {
  UserManagementService({
    FirebaseFirestore? firestore,
    NotificationService? notificationService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _notificationService = notificationService ?? NotificationService();

  final FirebaseFirestore _firestore;
  final NotificationService _notificationService;

  Stream<List<UserModel>> streamUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      final users = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.id, doc.data()))
          .toList()
        ..sort((a, b) {
          if (a.isAdmin != b.isAdmin) {
            return a.isAdmin ? -1 : 1;
          }
          return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
        });
      return users;
    });
  }

  Future<void> sendNotificationToUser({
    required String receiverId,
    required String senderId,
    required String title,
    required String message,
    String type = 'admin',
  }) async {
    await _notificationService.createNotification(
      receiverId: receiverId,
      senderId: senderId,
      title: title,
      message: message,
      type: type,
    );
  }

  Future<void> updateUserStatus({
    required UserModel user,
    required bool blocked,
    required String adminId,
  }) async {
    await _firestore.collection('users').doc(user.uid).set({
      'status': blocked ? 'blocked' : 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await sendNotificationToUser(
      receiverId: user.uid,
      senderId: adminId,
      title: blocked ? 'Account restricted' : 'Account restored',
      message: blocked
          ? 'Your FairBid account has been blocked by an administrator.'
          : 'Your FairBid account is active again.',
      type: 'admin',
    );
  }
}
