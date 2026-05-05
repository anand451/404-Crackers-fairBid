import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/auction.dart';

class AdminRecordItem {
  const AdminRecordItem({
    required this.id,
    required this.data,
  });

  final String id;
  final Map<String, dynamic> data;

  DateTime get createdAt => _readDate(
        data['createdAt'] ?? data['timestamp'] ?? data['submittedAt'],
      );

  double get amount => (data['amount'] as num?)?.toDouble() ?? 0;

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}

class AdminDashboardStats {
  const AdminDashboardStats({
    required this.totalUsers,
    required this.totalAuctions,
    required this.activeAuctions,
    required this.completedAuctions,
    required this.totalRevenue,
    required this.complaintsCount,
    required this.payments,
    required this.complaints,
  });

  final int totalUsers;
  final int totalAuctions;
  final int activeAuctions;
  final int completedAuctions;
  final double totalRevenue;
  final int complaintsCount;
  final List<AdminRecordItem> payments;
  final List<AdminRecordItem> complaints;
}

class AdminService {
  AdminService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<Auction>> streamAllAuctions() {
    return _firestore.collection('auctions').snapshots().map((snapshot) {
      final deduped = <String, Auction>{};
      for (final doc in snapshot.docs) {
        final auction = Auction.fromMap(doc.id, doc.data());
        deduped[auction.id] = auction;
      }
      final auctions = deduped.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return auctions;
    });
  }

  Stream<List<Auction>> streamPendingAuctionRequests() {
    return _firestore
        .collection('auction_requests')
        .snapshots()
        .map((snapshot) {
      final deduped = <String, Auction>{};
      for (final doc in snapshot.docs) {
        final request = Auction.fromMap(doc.id, doc.data());
        deduped[request.id] = request;
      }
      final requests = deduped.values
          .where((request) => request.status == 'pending')
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    });
  }

  Future<void> approveAuctionRequest({
    required Auction request,
    required String adminId,
  }) async {
    final requestRef =
        _firestore.collection('auction_requests').doc(request.id);
    final auctionRef = _firestore.collection('auctions').doc(request.id);

    await _firestore.runTransaction((transaction) async {
      final requestSnapshot = await transaction.get(requestRef);
      if (!requestSnapshot.exists) {
        throw Exception('This auction request no longer exists.');
      }

      final approvedAuction = request.copyWith(
        id: request.id,
        requestId: request.id,
        status: 'approved',
        state: 'PENDING',
        rejectionReason: null,
      );

      transaction.set(auctionRef, {
        ...approvedAuction.toMap(),
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': adminId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
          requestRef,
          {
            ...request.toMap(),
            'status': 'approved',
            'state': 'PENDING',
            'approvedAt': FieldValue.serverTimestamp(),
            'approvedBy': adminId,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });
  }

  Future<void> rejectAuctionRequest({
    required Auction request,
    required String adminId,
    String? reason,
  }) async {
    await _firestore.collection('auction_requests').doc(request.id).set({
      'status': 'rejected',
      'state': 'REJECTED',
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectedBy': adminId,
      'rejectionReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateAuction(Auction auction) async {
    await _firestore
        .collection('auctions')
        .doc(auction.id)
        .set(auction.toMap(), SetOptions(merge: true));
  }

  Future<void> updateAuctionStatus({
    required String auctionId,
    required String status,
  }) async {
    final state = switch (status) {
      'approved' => 'LIVE',
      'rejected' => 'REJECTED',
      _ => 'PENDING',
    };

    await _firestore.collection('auctions').doc(auctionId).set({
      'status': status,
      'state': state,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteAuction(String auctionId) async {
    await _firestore.collection('auctions').doc(auctionId).delete();
  }

  Stream<AdminDashboardStats> watchDashboardStats() {
    final controller = StreamController<AdminDashboardStats>.broadcast();

    QuerySnapshot<Map<String, dynamic>>? usersSnapshot;
    QuerySnapshot<Map<String, dynamic>>? auctionsSnapshot;
    QuerySnapshot<Map<String, dynamic>>? complaintsSnapshot;
    QuerySnapshot<Map<String, dynamic>>? paymentsSnapshot;

    void emit() {
      final auctions = auctionsSnapshot?.docs
              .map((doc) => Auction.fromMap(doc.id, doc.data()))
              .toList() ??
          <Auction>[];
      final complaints = complaintsSnapshot?.docs
              .map((doc) => AdminRecordItem(id: doc.id, data: doc.data()))
              .toList() ??
          <AdminRecordItem>[];
      final payments = paymentsSnapshot?.docs
              .map((doc) => AdminRecordItem(id: doc.id, data: doc.data()))
              .toList() ??
          <AdminRecordItem>[];

      controller.add(
        AdminDashboardStats(
          totalUsers: usersSnapshot?.docs.length ?? 0,
          totalAuctions: auctions.length,
          activeAuctions: auctions.where((auction) => auction.isLive).length,
          completedAuctions: auctions
              .where((auction) => auction.isSold || auction.isEnded)
              .length,
          totalRevenue: payments.fold<double>(
            0,
            (total, payment) => total + payment.amount,
          ),
          complaintsCount: complaints.length,
          payments: payments
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
          complaints: complaints
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        ),
      );
    }

    final subscriptions = <StreamSubscription<dynamic>>[
      _firestore.collection('users').snapshots().listen(
        (snapshot) {
          usersSnapshot = snapshot;
          emit();
        },
        onError: controller.addError,
      ),
      _firestore.collection('auctions').snapshots().listen(
        (snapshot) {
          auctionsSnapshot = snapshot;
          emit();
        },
        onError: controller.addError,
      ),
      _firestore.collection('complaints').snapshots().listen(
        (snapshot) {
          complaintsSnapshot = snapshot;
          emit();
        },
        onError: controller.addError,
      ),
      _firestore.collection('payments').snapshots().listen(
        (snapshot) {
          paymentsSnapshot = snapshot;
          emit();
        },
        onError: controller.addError,
      ),
    ];

    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };

    return controller.stream;
  }
}
