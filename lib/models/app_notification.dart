import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.receiverId,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    required this.readStatus,
    this.senderId,
    this.receiverRole,
    this.complaintId,
    this.auctionId,
    this.startsAt,
    this.readAt,
  });

  final String id;
  final String receiverId;
  final String title;
  final String message;
  final String type;
  final DateTime timestamp;
  final bool readStatus;
  final String? senderId;
  final String? receiverRole;
  final String? complaintId;
  final String? auctionId;
  final DateTime? startsAt;
  final DateTime? readAt;

  bool get isAdminInbox => receiverRole == 'admin';

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return AppNotification.fromMap(doc.id, doc.data() ?? <String, dynamic>{});
  }

  factory AppNotification.fromMap(String id, Map<String, dynamic> data) {
    return AppNotification(
      id: id,
      receiverId: data['receiverId'] as String? ?? '',
      title: data['title'] as String? ?? 'Notification',
      message: data['message'] as String? ?? '',
      type: data['type'] as String? ?? 'admin',
      timestamp: _readDate(data['timestamp'] ?? data['createdAt']),
      readStatus:
          data['readStatus'] as bool? ?? data['isRead'] as bool? ?? false,
      senderId: data['senderId'] as String?,
      receiverRole: data['receiverRole'] as String?,
      complaintId: data['complaintId'] as String?,
      auctionId: data['auctionId'] as String?,
      startsAt: _readNullableDate(data['startsAt']),
      readAt: _readNullableDate(data['readAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'receiverId': receiverId,
      'title': title,
      'message': message,
      'type': type,
      'timestamp': Timestamp.fromDate(timestamp),
      'createdAt': Timestamp.fromDate(timestamp),
      'readStatus': readStatus,
      'isRead': readStatus,
      'senderId': senderId,
      'receiverRole': receiverRole,
      'complaintId': complaintId,
      'auctionId': auctionId,
      'startsAt': startsAt == null ? null : Timestamp.fromDate(startsAt!),
      'readAt': readAt == null ? null : Timestamp.fromDate(readAt!),
    };
  }

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

  static DateTime? _readNullableDate(dynamic value) {
    if (value == null) {
      return null;
    }
    return _readDate(value);
  }
}
