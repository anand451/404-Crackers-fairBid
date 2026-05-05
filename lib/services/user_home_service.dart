import 'dart:async';

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/auction.dart';
import 'auction_service.dart';
import 'local_notification_service.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    required this.message,
    required this.createdAt,
    this.deliveredAt,
    this.seenAt,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String senderName;
  final String message;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? seenAt;

  bool get isDelivered => deliveredAt != null;
  bool get isSeen => seenAt != null;

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      receiverId: data['receiverId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'FairBid user',
      message: data['message'] as String? ?? '',
      createdAt: _readDate(data['createdAt']),
      deliveredAt: _readNullableDate(data['deliveredAt']),
      seenAt: _readNullableDate(data['seenAt']),
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

  bool get canEdit => !auction.isLive && !auction.isPaused && !auction.isSold && !auction.isEnded;
  bool get canDelete => !auction.isLive && !auction.isPaused && !auction.isSold && !auction.isEnded;
  bool get canJoinLive =>
      collection == 'auctions' &&
      auction.status == 'approved' &&
      !auction.isSold &&
      !auction.isEnded;
}

class AuctionChatThread {
  const AuctionChatThread({
    required this.id,
    required this.auctionId,
    required this.participants,
    required this.updatedAt,
    required this.lastMessage,
    required this.lastSenderId,
    required this.lastSenderName,
  });

  final String id;
  final String auctionId;
  final List<String> participants;
  final DateTime updatedAt;
  final String lastMessage;
  final String lastSenderId;
  final String lastSenderName;

  String otherParticipant(String currentUserId) {
    return participants.firstWhere(
      (participant) => participant != currentUserId,
      orElse: () => currentUserId,
    );
  }

  factory AuctionChatThread.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AuctionChatThread(
      id: doc.id,
      auctionId: data['auctionId'] as String? ?? '',
      participants: (data['participants'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      updatedAt: _readDate(data['lastMessageAt'] ?? data['updatedAt']),
      lastMessage: data['lastMessage'] as String? ?? '',
      lastSenderId: data['lastSenderId'] as String? ?? '',
      lastSenderName: data['lastSenderName'] as String? ?? 'FairBid user',
    );
  }
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
      final deduped = <String, Auction>{};
      for (final doc in snapshot.docs) {
        final auction = Auction.fromMap(doc.id, doc.data());
        deduped[auction.id] = auction;
      }
      final auctions = deduped.values
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
    final controller = StreamController<List<AuctionReminder>>.broadcast();
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
        userSubscription;
    final auctionSubscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    final auctionsById = <String, Auction>{};
    List<String> reminderIds = <String>[];

    void emit() {
      final reminders = reminderIds
          .map((auctionId) {
            final auction = auctionsById[auctionId];
            if (auction == null) {
              return null;
            }
            if (!auction.startTime.isAfter(DateTime.now()) &&
                !auction.isPaused) {
              return null;
            }
            return AuctionReminder(
              id: 'auction_${userId}_$auctionId',
              auctionId: auction.id,
              title: auction.title,
              startsAt: auction.startTime,
              read: false,
            );
          })
          .whereType<AuctionReminder>()
          .toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      controller.add(reminders);
    }

    Future<void> rebuildAuctionSubscriptions(List<String> ids) async {
      auctionsById.clear();
      for (final subscription in auctionSubscriptions) {
        await subscription.cancel();
      }
      auctionSubscriptions.clear();

      if (ids.isEmpty) {
        emit();
        return;
      }

      final chunks = <List<String>>[];
      for (var index = 0; index < ids.length; index += 10) {
        final end = (index + 10).clamp(0, ids.length);
        chunks.add(ids.sublist(index, end));
      }

      for (final chunk in chunks) {
        final subscription = _firestore
            .collection('auctions')
            .where(FieldPath.documentId, whereIn: chunk)
            .snapshots()
            .listen(
          (snapshot) {
            final chunkIds = chunk.toSet();
            auctionsById.removeWhere((key, value) => chunkIds.contains(key));
            for (final doc in snapshot.docs) {
              auctionsById[doc.id] = Auction.fromMap(doc.id, doc.data());
            }
            emit();
          },
          onError: controller.addError,
        );
        auctionSubscriptions.add(subscription);
      }
    }

    userSubscription =
        _firestore.collection('users').doc(userId).snapshots().listen(
      (snapshot) async {
        final ids =
            (snapshot.data()?['reminderAuctions'] as List<dynamic>? ?? [])
                .whereType<String>()
                .toList();
        reminderIds = ids;
        await rebuildAuctionSubscriptions(ids);
      },
      onError: controller.addError,
    );

    controller.onCancel = () async {
      await userSubscription?.cancel();
      for (final subscription in auctionSubscriptions) {
        await subscription.cancel();
      }
    };

    return controller.stream;
  }

  Future<void> cancelAuctionReminder({
    required String userId,
    required String auctionId,
  }) async {
    try {
      final batch = _firestore.batch();
      batch.set(_firestore.collection('users').doc(userId), {
        'reminderAuctions': FieldValue.arrayRemove([auctionId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.delete(_reminderRegistrationRef(userId: userId, auctionId: auctionId));
      await batch.commit();
      _log('Reminder removed for user=$userId auction=$auctionId');
    } on FirebaseException catch (error) {
      _log('Reminder cancel failed [${error.code}] ${error.message}');
      rethrow;
    }

    try {
      await _firestore
          .collection('notifications')
          .doc(_auctionReminderNotificationId(userId, auctionId))
          .delete();
    } on FirebaseException catch (error) {
      _log(
        'Legacy reminder notification cleanup skipped [${error.code}] ${error.message}',
      );
    }

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

  Stream<List<AuctionChatThread>> streamAuctionChatsForParticipant({
    required String auctionId,
    required String participantId,
  }) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: participantId)
        .snapshots()
        .map((snapshot) {
      final threads = snapshot.docs.map(AuctionChatThread.fromDoc).toList()
        ..removeWhere((thread) => thread.auctionId != auctionId)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return threads;
    });
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
    try {
      final batch = _firestore.batch();
      batch.set(_firestore.collection('users').doc(userId), {
        'reminderAuctions': FieldValue.arrayUnion([auction.id]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(
        _reminderRegistrationRef(userId: userId, auctionId: auction.id),
        {
          'userId': userId,
          'auctionId': auction.id,
          'title': auction.title,
          'startsAt': Timestamp.fromDate(auction.startTime),
          'createdAt': FieldValue.serverTimestamp(),
          'triggeredAt': null,
        },
        SetOptions(merge: true),
      );
      await batch.commit();
      _log('Reminder saved for user=$userId auction=${auction.id}');
    } on FirebaseException catch (error) {
      _log('Reminder save failed [${error.code}] ${error.message}');
      rethrow;
    }

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
    required String receiverId,
    required String userName,
    required String message,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final chatRef = _firestore.collection('chats').doc(chatId);
    try {
      await chatRef.set({
        'auctionId': auctionId,
        'creatorId': creatorId,
        'participants': [creatorId, userId],
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': trimmed,
        'lastSenderId': userId,
        'lastSenderName': userName,
        'lastMessageAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await chatRef.collection('messages').add({
        'senderId': userId,
        'receiverId': receiverId,
        'senderName': userName,
        'message': trimmed,
        'createdAt': FieldValue.serverTimestamp(),
        'deliveredAt': FieldValue.serverTimestamp(),
        'seenAt': null,
      });
      if (receiverId != userId) {
        await _firestore.collection('notifications').add({
          'receiverId': receiverId,
          'senderId': userId,
          'auctionId': auctionId,
          'title': 'New auction chat message',
          'message': '$userName: $trimmed',
          'type': 'auction',
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'readStatus': false,
          'isRead': false,
        });
      }
      _log('Chat message sent in $chatId by $userId');
    } on FirebaseException catch (error) {
      _log('Chat send failed [${error.code}] ${error.message}');
      rethrow;
    }
  }

  Stream<List<ChatMessage>> streamMessagesForViewer({
    required String chatId,
    required String viewerId,
  }) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final messages = snapshot.docs.map(ChatMessage.fromDoc).toList();
      unawaited(
        _markMessagesSeen(
          chatId: chatId,
          viewerId: viewerId,
          messages: messages,
        ),
      );
      return messages;
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

  Future<void> resubmitAuctionForApproval({
    required ManagedAuction item,
    required Auction updatedAuction,
  }) async {
    final normalized = updatedAuction.copyWith(
      id: item.auction.id,
      requestId: item.auction.id,
      sellerId: item.auction.sellerId,
      sellerName: item.auction.sellerName,
      sellerEmail: item.auction.sellerEmail,
      status: 'pending',
      state: 'PENDING',
      rejectionReason: null,
      createdAt: item.auction.createdAt,
      updatedAt: DateTime.now(),
      currentPrice: updatedAuction.reservePrice,
      highestBidId: null,
      highestBidderId: null,
      highestBidderName: null,
      winnerId: null,
      winnerName: null,
      finalPrice: null,
      paymentStatus: 'unpaid',
      paymentId: null,
      startedAt: null,
      pausedAt: null,
      soldAt: null,
      endedAt: null,
      remainingSeconds: updatedAuction.durationHours * 3600,
      bidCount: 0,
      comments: const [],
    );

    final batch = _firestore.batch();
    final requestRef = _firestore.collection('auction_requests').doc(item.auction.id);
    batch.set(requestRef, normalized.toMap(), SetOptions(merge: true));

    if (item.collection == 'auctions') {
      final auctionRef = _firestore.collection('auctions').doc(item.auction.id);
      batch.set(auctionRef, normalized.toMap(), SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<void> deleteMyAuction(ManagedAuction item) async {
    await AuctionService(firestore: _firestore).deleteAuctionCascade(
      item.auction.id,
    );
  }

  DocumentReference<Map<String, dynamic>> _reminderRegistrationRef({
    required String userId,
    required String auctionId,
  }) {
    return _firestore
        .collection('user_notifications')
        .doc(userId)
        .collection('auctions')
        .doc(auctionId);
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

  Future<void> _markMessagesSeen({
    required String chatId,
    required String viewerId,
    required List<ChatMessage> messages,
  }) async {
    final pending = messages
        .where((message) => message.senderId != viewerId && !message.isSeen)
        .toList();
    if (pending.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    for (final message in pending) {
      final ref = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(message.id);
      batch.set(
        ref,
        {
          'deliveredAt': FieldValue.serverTimestamp(),
          'seenAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  void _log(String message) {
    debugPrint('[UserHomeService] $message');
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

DateTime? _readNullableDate(dynamic value) {
  if (value == null) {
    return null;
  }
  return _readDate(value);
}
