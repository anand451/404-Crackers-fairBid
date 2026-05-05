import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/auction.dart';
import '../models/auction_watcher.dart';
import '../models/bid.dart';
import '../models/payment_record.dart';
import '../models/user_model.dart';
import 'notification_service.dart';

class AuctionService {
  AuctionService({
    FirebaseFirestore? firestore,
    NotificationService? notificationService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _notificationService = notificationService ?? NotificationService();

  final FirebaseFirestore _firestore;
  final NotificationService _notificationService;

  CollectionReference<Map<String, dynamic>> get _auctions =>
      _firestore.collection('auctions');
  CollectionReference<Map<String, dynamic>> get _auctionRequests =>
      _firestore.collection('auction_requests');
  CollectionReference<Map<String, dynamic>> get _payments =>
      _firestore.collection('payments');

  Stream<List<Auction>> streamApprovedAuctions() {
    return _auctions
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) {
      final auctions = snapshot.docs
          .map((doc) => Auction.fromMap(doc.id, doc.data()))
          .where((auction) => auction.isVisibleInMarketplace)
          .toList()
        ..sort(_marketplaceSort);
      return auctions;
    });
  }

  Future<Auction?> getAuctionById(String auctionId) async {
    _log('Reading auction $auctionId');
    final doc = await _auctions.doc(auctionId).get();
    final data = doc.data();
    if (!doc.exists || data == null) {
      return null;
    }
    return Auction.fromMap(doc.id, data);
  }

  Stream<Auction?> watchAuctionById(String auctionId) {
    return _auctions.doc(auctionId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }
      return Auction.fromMap(snapshot.id, data);
    });
  }

  Stream<List<Bid>> streamAuctionBids(String auctionId) {
    return _bidsForAuction(auctionId).snapshots().map((snapshot) {
      final bids = snapshot.docs.map(Bid.fromDoc).toList()
        ..sort((a, b) {
          final byAmount = b.bidAmount.compareTo(a.bidAmount);
          if (byAmount != 0) {
            return byAmount;
          }
          return a.timestamp.compareTo(b.timestamp);
        });
      return bids;
    });
  }

  Stream<List<AuctionWatcher>> streamAuctionWatchers(String auctionId) {
    return _watchersForAuction(auctionId).snapshots().map((snapshot) {
      final watchers = snapshot.docs.map(AuctionWatcher.fromDoc).toList()
        ..sort((a, b) => a.enteredAt.compareTo(b.enteredAt));
      return watchers;
    });
  }

  Stream<List<PaymentRecord>> streamAuctionPayments(String auctionId) {
    return _payments.where('auctionId', isEqualTo: auctionId).snapshots().map(
        (snapshot) => snapshot.docs.map(PaymentRecord.fromDoc).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp)));
  }

  Stream<PaymentRecord?> watchPaymentForAuctionAndBuyer({
    required String auctionId,
    required String buyerId,
  }) {
    return _payments
        .where('auctionId', isEqualTo: auctionId)
        .where('buyerId', isEqualTo: buyerId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return null;
      }
      return PaymentRecord.fromDoc(snapshot.docs.first);
    });
  }

  Future<void> submitAuctionRequest({
    required String title,
    required String description,
    required String category,
    required double reservePrice,
    required DateTime startTime,
    required int durationHours,
    required String upiId,
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
      upiId: upiId.trim(),
      createdAt: now,
      updatedAt: now,
      remainingSeconds: durationHours * 3600,
      comments: const [],
    );

    final document = _auctionRequests.doc();
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

  Future<Bid> placeBid({
    required String auctionId,
    required String bidderId,
    required String bidderName,
    required double amount,
  }) async {
    final bidRef = _bidsForAuction(auctionId).doc();
    late Bid placedBid;

    await _firestore.runTransaction((transaction) async {
      final auctionSnapshot = await transaction.get(_auctions.doc(auctionId));
      if (!auctionSnapshot.exists || auctionSnapshot.data() == null) {
        throw 'This auction is no longer available.';
      }

      final auction =
          Auction.fromMap(auctionSnapshot.id, auctionSnapshot.data()!);
      if (!auction.canAcceptBids) {
        throw auction.isPaused
            ? 'Bidding is paused right now.'
            : auction.isSold
                ? 'This auction has already been sold.'
                : 'This auction is not accepting bids right now.';
      }
      if (auction.sellerId == bidderId) {
        throw 'Sellers cannot bid on their own auctions.';
      }
      if (amount <= auction.currentPrice) {
        throw 'Your bid must be higher than the current highest bid.';
      }

      transaction.set(bidRef, {
        'userId': bidderId,
        'userName': bidderName,
        'bidAmount': amount,
        'amount': amount,
        'timestamp': FieldValue.serverTimestamp(),
      });
      transaction.set(
          _auctions.doc(auctionId),
          {
            'currentPrice': amount,
            'highestBidId': bidRef.id,
            'highestBidderId': bidderId,
            'highestBidderName': bidderName,
            'bidCount': auction.bidCount + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      placedBid = Bid(
        id: bidRef.id,
        userId: bidderId,
        userName: bidderName,
        bidAmount: amount,
        timestamp: DateTime.now(),
      );
    });

    return placedBid;
  }

  Future<void> startAuction({
    required Auction auction,
    required String sellerId,
  }) async {
    if (auction.sellerId != sellerId) {
      throw 'Only the seller can start this auction.';
    }

    final remainingSeconds = auction.remainingSeconds <= 0
        ? auction.durationHours * 3600
        : auction.remainingSeconds;
    final now = DateTime.now();

    await _auctions.doc(auction.id).set({
      'state': 'LIVE',
      'startTime': Timestamp.fromDate(now),
      'startedAt': FieldValue.serverTimestamp(),
      'pausedAt': null,
      'endTime':
          Timestamp.fromDate(now.add(Duration(seconds: remainingSeconds))),
      'remainingSeconds': remainingSeconds,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _notifyInterestedUsersForAuctionStart(auction.copyWith(
      startTime: now,
      endTime: now.add(Duration(seconds: remainingSeconds)),
      state: 'LIVE',
      remainingSeconds: remainingSeconds,
    ));
  }

  Future<void> pauseAuction({
    required Auction auction,
    required String sellerId,
  }) async {
    if (auction.sellerId != sellerId) {
      throw 'Only the seller can pause this auction.';
    }
    if (!auction.isLive) {
      throw 'Only a live auction can be paused.';
    }

    final remainingSeconds = auction.endTime
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, 1 << 31)
        .toInt();
    await _auctions.doc(auction.id).set({
      'state': 'PAUSED',
      'remainingSeconds': remainingSeconds,
      'pausedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> endAuction({
    required Auction auction,
    required String sellerId,
  }) async {
    if (auction.sellerId != sellerId) {
      throw 'Only the seller can end this auction.';
    }

    await _auctions.doc(auction.id).set({
      'state': 'ENDED',
      'remainingSeconds': 0,
      'endedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> sellAuction({
    required Auction auction,
    required Bid bid,
    required String sellerId,
  }) async {
    if (auction.sellerId != sellerId) {
      throw 'Only the seller can finalize this sale.';
    }
    if (bid.userId == auction.sellerId) {
      throw 'A seller bid cannot be selected as the winner.';
    }

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(_auctions.doc(auction.id));
      if (!snapshot.exists || snapshot.data() == null) {
        throw 'This auction is no longer available.';
      }

      final latestAuction = Auction.fromMap(snapshot.id, snapshot.data()!);
      if (latestAuction.isSold) {
        throw 'This auction has already been sold.';
      }

      transaction.set(
          _auctions.doc(auction.id),
          {
            'state': 'SOLD',
            'winnerId': bid.userId,
            'winnerName': bid.userName,
            'highestBidId': bid.id,
            'highestBidderId': bid.userId,
            'highestBidderName': bid.userName,
            'currentPrice': bid.bidAmount,
            'finalPrice': bid.bidAmount,
            'paymentStatus': 'pending',
            'remainingSeconds': 0,
            'soldAt': FieldValue.serverTimestamp(),
            'endedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });

    await _notificationService.createNotification(
      receiverId: bid.userId,
      senderId: sellerId,
      title: 'You won the auction',
      message:
          'Complete payment for ${auction.title} at Rs ${bid.bidAmount.toStringAsFixed(0)}.',
      type: 'auction',
      auctionId: auction.id,
    );
    await _notificationService.createNotification(
      receiverId: sellerId,
      senderId: sellerId,
      title: 'Auction sold',
      message:
          '${auction.title} was sold to ${bid.userName} for Rs ${bid.bidAmount.toStringAsFixed(0)}.',
      type: 'auction',
      auctionId: auction.id,
    );
  }

  Future<PaymentRecord> submitWinnerPayment({
    required Auction auction,
    required String buyerId,
    required String buyerName,
  }) async {
    if (auction.winnerId != buyerId) {
      throw 'Only the winning bidder can submit payment.';
    }
    if (!auction.isSold) {
      throw 'This auction is not ready for payment.';
    }
    if (auction.finalPrice == null) {
      throw 'The final sale amount is missing.';
    }

    final paymentRef = _payments.doc('${auction.id}_$buyerId');
    final receiptNumber =
        'FB-${auction.id.substring(0, auction.id.length.clamp(0, 6)).toUpperCase()}-${DateTime.now().millisecondsSinceEpoch}';
    late PaymentRecord record;

    await _firestore.runTransaction((transaction) async {
      final auctionSnapshot = await transaction.get(_auctions.doc(auction.id));
      if (!auctionSnapshot.exists || auctionSnapshot.data() == null) {
        throw 'This auction is no longer available.';
      }

      final latestAuction = Auction.fromMap(
        auctionSnapshot.id,
        auctionSnapshot.data()!,
      );
      if (latestAuction.winnerId != buyerId) {
        throw 'Only the confirmed winner can pay for this auction.';
      }
      if (!latestAuction.isSold) {
        throw 'The auction must be sold before payment.';
      }

      final paymentSnapshot = await transaction.get(paymentRef);
      if (paymentSnapshot.exists) {
        throw 'Payment has already been recorded for this auction.';
      }

      transaction.set(paymentRef, {
        'auctionId': latestAuction.id,
        'auctionTitle': latestAuction.title,
        'buyerId': buyerId,
        'buyerName': buyerName,
        'sellerId': latestAuction.sellerId,
        'sellerName': latestAuction.sellerName,
        'amount': latestAuction.finalPrice,
        'status': 'completed',
        'timestamp': FieldValue.serverTimestamp(),
        'receiptNumber': receiptNumber,
        'upiId': latestAuction.upiId,
      });
      transaction.set(
          _auctions.doc(auction.id),
          {
            'paymentStatus': 'completed',
            'paymentId': paymentRef.id,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      record = PaymentRecord(
        id: paymentRef.id,
        auctionId: latestAuction.id,
        auctionTitle: latestAuction.title,
        buyerId: buyerId,
        buyerName: buyerName,
        sellerId: latestAuction.sellerId,
        sellerName: latestAuction.sellerName,
        amount: latestAuction.finalPrice ?? 0,
        status: 'completed',
        timestamp: DateTime.now(),
        receiptNumber: receiptNumber,
        upiId: latestAuction.upiId,
      );
    });

    await _notificationService.createNotification(
      receiverId: auction.sellerId,
      senderId: buyerId,
      title: 'Payment submitted',
      message:
          '$buyerName marked payment complete for ${auction.title}. Receipt: $receiptNumber.',
      type: 'payment',
      auctionId: auction.id,
    );
    await _notificationService.createNotification(
      receiverId: buyerId,
      senderId: auction.sellerId,
      title: 'Payment receipt generated',
      message:
          'Your payment for ${auction.title} is recorded. Receipt: $receiptNumber.',
      type: 'payment',
      auctionId: auction.id,
    );

    return record;
  }

  Uri buildUpiPaymentUri({
    required Auction auction,
    required double amount,
  }) {
    return Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': auction.upiId,
        'pn':
            auction.sellerName.isEmpty ? 'FairBid Seller' : auction.sellerName,
        'am': amount.toStringAsFixed(2),
        'cu': 'INR',
        'tn': 'FairBid ${auction.title}',
      },
    );
  }

  Future<void> upsertWatcher({
    required String auctionId,
    required String userId,
    required String userName,
  }) async {
    await _watchersForAuction(auctionId).doc(userId).set({
      'userId': userId,
      'userName': userName,
      'enteredAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeWatcher({
    required String auctionId,
    required String userId,
  }) {
    return _watchersForAuction(auctionId).doc(userId).delete();
  }

  Future<void> updateAuction(Auction auction) async {
    await _auctions.doc(auction.id).set(
          auction.copyWith(updatedAt: DateTime.now()).toMap(),
          SetOptions(merge: true),
        );
  }

  Future<void> syncBidPrice({
    required String auctionId,
    required double amount,
  }) async {
    await _auctions.doc(auctionId).set({
      'currentPrice': amount,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  CollectionReference<Map<String, dynamic>> _bidsForAuction(String auctionId) {
    return _auctions.doc(auctionId).collection('bids');
  }

  CollectionReference<Map<String, dynamic>> _watchersForAuction(
    String auctionId,
  ) {
    return _firestore
        .collection('auction_watchers')
        .doc(auctionId)
        .collection('members');
  }

  Future<void> _notifyInterestedUsersForAuctionStart(Auction auction) async {
    final interestedUsers = await _firestore
        .collection('users')
        .where('reminderAuctions', arrayContains: auction.id)
        .get();

    final futures = <Future<dynamic>>[];
    for (final userDoc in interestedUsers.docs) {
      if (userDoc.id == auction.sellerId) {
        continue;
      }
      futures.add(
        _notificationService.createNotification(
          receiverId: userDoc.id,
          senderId: auction.sellerId,
          title: 'Auction started',
          message: '${auction.title} is live now. Join the bidding.',
          type: 'auction',
          auctionId: auction.id,
        ),
      );
    }
    futures.add(
      _notificationService.createNotification(
        receiverId: auction.sellerId,
        senderId: auction.sellerId,
        title: 'Auction is live',
        message: 'Your auction ${auction.title} has started successfully.',
        type: 'auction',
        auctionId: auction.id,
      ),
    );

    await Future.wait(futures);
  }

  static int _marketplaceSort(Auction a, Auction b) {
    int rank(Auction auction) {
      switch (auction.state) {
        case 'LIVE':
          return 0;
        case 'PAUSED':
          return 1;
        default:
          return 2;
      }
    }

    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) {
      return byRank;
    }
    return a.startTime.compareTo(b.startTime);
  }

  void _log(String message) {
    debugPrint('[AuctionService] $message');
  }
}
