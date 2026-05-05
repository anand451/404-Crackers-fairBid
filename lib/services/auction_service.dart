import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/auction.dart';
import '../models/user_model.dart';

class AuctionService {
  AuctionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<Auction>> streamApprovedAuctions() {
    return _firestore
        .collection('auctions')
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) {
      _log('Received ${snapshot.docs.length} auction docs');
      final auctions = snapshot.docs
          .map((doc) => Auction.fromMap(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return auctions;
    });
  }

  Future<Auction?> getAuctionById(String auctionId) async {
    _log('Reading auction $auctionId');
    final doc = await _firestore.collection('auctions').doc(auctionId).get();
    final data = doc.data();
    if (!doc.exists || data == null) {
      return null;
    }
    return Auction.fromMap(doc.id, data);
  }

  Stream<Auction?> watchAuctionById(String auctionId) {
    return _firestore.collection('auctions').doc(auctionId).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }
      return Auction.fromMap(snapshot.id, data);
    });
  }

  Future<void> submitAuctionRequest({
    required String title,
    required String description,
    required String category,
    required double reservePrice,
    required DateTime startTime,
    required int durationHours,
    double? latitude,
    double? longitude,
    required UserModel seller,
  }) async {
    final now = DateTime.now();
    _log(
      'Submitting auction request: title="${title.trim()}", seller=${seller.uid}, reserve=$reservePrice, durationHours=$durationHours',
    );
    final request = Auction(
      id: '',
      title: title.trim(),
      description: description.trim(),
      category: category.trim().isEmpty ? 'General' : category.trim(),
      startTime: startTime,
      currentPrice: reservePrice,
      reservePrice: reservePrice,
      endTime: startTime.add(Duration(hours: durationHours)),
      durationHours: durationHours,
      latitude: latitude,
      longitude: longitude,
      state: 'PENDING',
      status: 'pending',
      sellerId: seller.uid,
      sellerName: seller.fullName,
      sellerEmail: seller.email,
      createdAt: now,
      comments: const [],
    );

    final document = _firestore.collection('auction_requests').doc();
    try {
      await document.set(
        request.copyWith(id: document.id, requestId: document.id).toMap(),
      );
      _log('Auction request created successfully with id ${document.id}');
    } on FirebaseException catch (error) {
      _log(
        'Auction request write failed [${error.code}] ${error.message} for seller ${seller.uid}',
      );
      rethrow;
    }
  }

  Future<void> syncBidPrice({
    required String auctionId,
    required double amount,
  }) async {
    _log('Syncing bid price $amount for auction $auctionId');
    await _firestore.collection('auctions').doc(auctionId).set({
      'currentPrice': amount,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _log(String message) {
    debugPrint('[AuctionService] $message');
  }
}
