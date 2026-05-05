import 'dart:async';

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/auction.dart';
import 'local_notification_service.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime createdAt;

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'FairBid user',
      message: data['message'] as String? ?? '',
      createdAt: _readDate(data['createdAt']),
    );
  }
}

class AuctionReminder {
  const AuctionReminder({
    required this.id,
    required this.auctionId,
    required this.title,
    required this.startsAt,
    required this.read,
  });

  final String id;
  final String auctionId;
  final String title;
  final DateTime startsAt;
  final bool read;

  factory AuctionReminder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AuctionReminder(
      id: doc.id,
      auctionId: data['auctionId'] as String? ?? doc.id,
      title: data['title'] as String? ?? 'Untitled auction',
      startsAt: _readDate(data['startsAt']),
      read: data['readStatus'] as bool? ?? data['read'] as bool? ?? false,
    );
  }
}

class ManagedAuction {
  const ManagedAuction({
    required this.auction,
    required this.collection,
  });

  final Auction auction;
  final String collection;

  bool get canEdit => collection == 'auction_requests' && auction.isPending;
  bool get canDelete => collection == 'auction_requests' && auction.isPending;
  bool get canJoinLive =>
      collection == 'auctions' &&
      auction.status == 'approved' &&
      !auction.isSold &&
      !auction.isEnded;
}

class UserHomeService {
  UserHomeService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<Auction>> streamFutureAuctions() {
    return _firestore
        .collection('auctions')
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final auctions = snapshot.docs
          .map((doc) => Auction.fromMap(doc.id, doc.data()))
          .where(
            (auction) =>
                auction.isVisibleInMarketplace &&
                (auction.startTime.isAfter(now) ||
                    auction.isLive ||
                    auction.isPaused),
          )
          .toList()
        ..sort((a, b) {
          int rank(Auction auction) {
            if (auction.isLive) {
              return 0;
            }
            if (auction.isPaused) {
              return 1;
            }
            return 2;
          }

          final byRank = rank(a).compareTo(rank(b));
          if (byRank != 0) {
            return byRank;
          }
          return a.startTime.compareTo(b.startTime);
        });
      return auctions;
    });
  }

  Stream<List<AuctionReminder>> streamMyReminders(String userId) {
    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: userId)
        .where('type', isEqualTo: 'auction')
        .snapshots()
        .map((snapshot) {
      final reminders = snapshot.docs
          .map(AuctionReminder.fromDoc)
          .where((reminder) => reminder.startsAt.isAfter(DateTime.now()))
          .toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      return reminders;
    });
  }

  Future<void> cancelAuctionReminder({
    required String userId,
    required String auctionId,
  }) async {
    await _firestore.runTransaction((transaction) async {
      transaction.set(
        _firestore.collection('users').doc(userId),
        {
          'reminderAuctions': FieldValue.arrayRemove([auctionId]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      transaction.delete(
        _firestore.collection('notifications').doc(
              _auctionReminderNotificationId(userId, auctionId),
            ),
      );
    });

    await LocalNotificationService.instance.cancel(
      _stableNotificationId('${userId}_$auctionId'),
    );
  }

  Stream<List<Auction>> streamMyUpcomingRequests(String userId) {
    return _firestore
        .collection('auction_requests')
        .where('sellerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final auctions = snapshot.docs
          .map((doc) => Auction.fromMap(doc.id, doc.data()))
          .where((auction) => auction.startTime.isAfter(now))
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      return auctions;
    });
  }

  Stream<List<ManagedAuction>> streamMyManagedAuctions(String userId) {
    final controller = StreamController<List<ManagedAuction>>.broadcast();
    QuerySnapshot<Map<String, dynamic>>? requestSnapshot;
    QuerySnapshot<Map<String, dynamic>>? liveSnapshot;

    void emit() {
      final items = <ManagedAuction>[
        ...?requestSnapshot?.docs.map(
          (doc) => ManagedAuction(
            auction: Auction.fromMap(doc.id, doc.data()),
            collection: 'auction_requests',
          ),
        ),
        ...?liveSnapshot?.docs.map(
          (doc) => ManagedAuction(
            auction: Auction.fromMap(doc.id, doc.data()),
            collection: 'auctions',
          ),
        ),
      ];

      final deduped = <String, ManagedAuction>{};
      for (final item in items) {
        deduped[item.auction.id] = item;
      }

      final merged = deduped.values.toList()
        ..sort((a, b) => b.auction.createdAt.compareTo(a.auction.createdAt));
      controller.add(merged);
    }

    final subscriptions = <StreamSubscription<dynamic>>[
      _firestore
          .collection('auction_requests')
          .where('sellerId', isEqualTo: userId)
          .snapshots()
          .listen(
        (snapshot) {
          requestSnapshot = snapshot;
          emit();
        },
        onError: controller.addError,
      ),
      _firestore
          .collection('auctions')
          .where('sellerId', isEqualTo: userId)
          .snapshots()
          .listen(
        (snapshot) {
          liveSnapshot = snapshot;
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

  Stream<int> streamUnreadNotificationCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: userId)
        .where('readStatus', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Stream<String?> streamReaction({
    required String auctionId,
    required String userId,
  }) {
    return _firestore
        .collection('likes')
        .doc(_reactionId(auctionId, userId))
        .snapshots()
        .map((snapshot) => snapshot.data()?['value'] as String?);
  }

  Stream<Map<String, int>> streamReactionCounts(String auctionId) {
    return _firestore
        .collection('likes')
        .where('auctionId', isEqualTo: auctionId)
        .snapshots()
        .map((snapshot) {
      var likes = 0;
      var dislikes = 0;
      for (final doc in snapshot.docs) {
        switch (doc.data()['value']) {
          case 'like':
            likes++;
          case 'dislike':
            dislikes++;
        }
      }
      return {'like': likes, 'dislike': dislikes};
    });
  }

  Future<void> toggleReaction({
    required String auctionId,
    required String userId,
    required String value,
  }) async {
    final document = _firestore.collection('likes').doc(
          _reactionId(auctionId, userId),
        );
    final snapshot = await document.get();
    if (snapshot.data()?['value'] == value) {
      await document.delete();
      return;
    }

    await document.set({
      'auctionId': auctionId,
      'userId': userId,
      'value': value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveAuctionReminder({
    required String userId,
    required Auction auction,
  }) async {
    final notificationRef = _firestore
        .collection('notifications')
        .doc(_auctionReminderNotificationId(userId, auction.id));

    await _firestore.runTransaction((transaction) async {
      transaction.set(
        _firestore.collection('users').doc(userId),
        {
          'reminderAuctions': FieldValue.arrayUnion([auction.id]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      transaction.set(
          notificationRef,
          {
            'receiverId': userId,
            'auctionId': auction.id,
            'message':
                'Reminder set for ${auction.title} at ${auction.startTime.toLocal()}.',
            'title': auction.title,
            'startsAt': Timestamp.fromDate(auction.startTime),
            'readStatus': false,
            'type': 'auction',
            'timestamp': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });

    await LocalNotificationService.instance.scheduleAuctionStartReminder(
      id: _stableNotificationId('${userId}_${auction.id}'),
      title: auction.title,
      startsAt: auction.startTime,
    );
  }

  Stream<List<ChatMessage>> streamMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ChatMessage.fromDoc).toList());
  }

  Future<void> sendMessage({
    required String chatId,
    required String auctionId,
    required String creatorId,
    required String userId,
    required String userName,
    required String message,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final chatRef = _firestore.collection('chats').doc(chatId);
    await chatRef.set({
      'auctionId': auctionId,
      'creatorId': creatorId,
      'participants': [creatorId, userId],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await chatRef.collection('messages').add({
      'senderId': userId,
      'senderName': userName,
      'message': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMyAuctionRequest(Auction auction) async {
    await _firestore
        .collection('auction_requests')
        .doc(auction.id)
        .set(auction.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteMyAuctionRequest(String auctionId) async {
    await _firestore.collection('auction_requests').doc(auctionId).delete();
  }

  static String chatIdFor({
    required String auctionId,
    required String creatorId,
    required String userId,
  }) {
    final participants = [creatorId, userId]..sort();
    return '${auctionId}_${participants.join('_')}';
  }

  static String _reactionId(String auctionId, String userId) {
    return '${auctionId}_$userId';
  }

  static int _stableNotificationId(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = 0x1fffffff & (hash + codeUnit);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash = hash ^ (hash >> 6);
    }
    return math.max(1, hash.abs());
  }

  static String _auctionReminderNotificationId(
      String userId, String auctionId) {
    return 'auction_${userId}_$auctionId';
  }
}

DateTime _readDate(dynamic value) {
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
