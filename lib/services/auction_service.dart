import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/auction.dart';
import '../models/user_model.dart';

class AuctionService {
  AuctionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<Auction>> streamApprovedAuctions() {
    return _firestore.collection('auctions').snapshots().map((snapshot) {
      final auctions = snapshot.docs
          .map((doc) => Auction.fromMap(doc.id, doc.data()))
          .where((auction) => auction.status == 'approved')
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return auctions;
    });
  }

  Future<Auction?> getAuctionById(String auctionId) async {
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
    required double reservePrice,
    required int durationHours,
    required UserModel seller,
  }) async {
    final now = DateTime.now();
    final request = Auction(
      id: '',
      title: title.trim(),
      description: description.trim(),
      currentPrice: reservePrice,
      reservePrice: reservePrice,
      endTime: now.add(Duration(hours: durationHours)),
      state: 'PENDING',
      status: 'pending',
      sellerId: seller.uid,
      sellerName: seller.fullName,
      sellerEmail: seller.email,
      createdAt: now,
      comments: const [],
    );

    final document = _firestore.collection('auction_requests').doc();
    await document.set(
      request.copyWith(id: document.id, requestId: document.id).toMap(),
    );
  }

  Future<void> syncBidPrice({
    required String auctionId,
    required double amount,
  }) async {
    await _firestore.collection('auctions').doc(auctionId).set({
      'currentPrice': amount,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
