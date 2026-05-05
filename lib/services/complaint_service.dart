import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/complaint.dart';
import '../models/user_model.dart';
import 'notification_service.dart';

class ComplaintService {
  ComplaintService({
    FirebaseFirestore? firestore,
    NotificationService? notificationService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _notificationService = notificationService ?? NotificationService();

  final FirebaseFirestore _firestore;
  final NotificationService _notificationService;

  Stream<List<Complaint>> streamUserComplaints(String userId) {
    return _firestore
        .collection('complaints')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final complaints = snapshot.docs.map(Complaint.fromDoc).toList();
          complaints.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return complaints;
        });
  }

  Stream<List<Complaint>> streamAllComplaints() {
    return _firestore
        .collection('complaints')
        .snapshots()
        .map((snapshot) {
          final complaints = snapshot.docs.map(Complaint.fromDoc).toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return complaints;
        });
  }

  Future<void> submitComplaint({
    required UserModel user,
    required String message,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw 'Please describe your complaint before submitting.';
    }

    final document = _firestore.collection('complaints').doc();
    final complaint = Complaint(
      id: document.id,
      userId: user.uid,
      userName: user.fullName,
      userEmail: user.email,
      message: trimmed,
      status: 'pending',
      adminReply: '',
      timestamp: DateTime.now(),
    );

    try {
      final batch = _firestore.batch();
      batch.set(document, {
        ...complaint.toMap(),
        'timestamp': FieldValue.serverTimestamp(),
      });
      final notificationDoc = _firestore.collection('notifications').doc();
      batch.set(notificationDoc, {
        'receiverId': '',
        'receiverRole': 'admin',
        'senderId': user.uid,
        'title': 'New complaint received',
        'message': '${user.fullName} submitted a complaint.',
        'type': 'complaint',
        'complaintId': complaint.id,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'readStatus': false,
        'isRead': false,
      });
      await batch.commit();
      _log('Complaint ${complaint.id} saved for ${user.uid}');
    } on FirebaseException catch (error) {
      _log('Complaint submit failed [${error.code}] ${error.message}');
      rethrow;
    }
  }

  Future<void> replyToComplaint({
    required Complaint complaint,
    required String adminId,
    required String reply,
  }) async {
    final trimmed = reply.trim();
    if (trimmed.isEmpty) {
      throw 'Reply cannot be empty.';
    }

    try {
      final batch = _firestore.batch();
      batch.set(
          _firestore.collection('complaints').doc(complaint.id),
          {
            'adminReply': trimmed,
            'status': 'resolved',
            'adminId': adminId,
            'resolvedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
      batch.set(_firestore.collection('notifications').doc(), {
        'receiverId': complaint.userId,
        'senderId': adminId,
        'title': 'Complaint updated',
        'message': trimmed,
        'type': 'complaint',
        'complaintId': complaint.id,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'readStatus': false,
        'isRead': false,
      });
      await batch.commit();
      _log('Complaint ${complaint.id} resolved by $adminId');
    } on FirebaseException catch (error) {
      _log('Complaint reply failed [${error.code}] ${error.message}');
      rethrow;
    }
  }

  Future<void> markComplaintReplyAsRead(String complaintId) async {
    final snapshot = await _firestore
        .collection('notifications')
        .where('complaintId', isEqualTo: complaintId)
        .where('type', isEqualTo: 'complaint')
        .where('readStatus', isEqualTo: false)
        .get();

    for (final notification in snapshot.docs) {
      if ((notification.data()['receiverId'] as String?)?.isNotEmpty == true) {
        await _notificationService.markAsRead(notification.id);
      }
    }
  }

  void _log(String message) {
    debugPrint('[ComplaintService] $message');
  }
}
