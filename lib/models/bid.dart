import 'package:cloud_firestore/cloud_firestore.dart';

class Bid {
  const Bid({
    required this.id,
    required this.userId,
    required this.userName,
    required this.bidAmount,
    required this.timestamp,
  });

  final String id;
  final String userId;
  final String userName;
  final double bidAmount;
  final DateTime timestamp;

  double get amount => bidAmount;
  DateTime get normalizedTs => timestamp;

  factory Bid.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Bid.fromMap(doc.id, doc.data() ?? <String, dynamic>{});
  }

  factory Bid.fromMap(String id, Map<String, dynamic> data) {
    return Bid(
      id: id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? 'Bidder',
      bidAmount: (data['bidAmount'] as num?)?.toDouble() ??
          (data['amount'] as num?)?.toDouble() ??
          0,
      timestamp: _readDate(data['timestamp'] ?? data['normalizedTs']),
    );
  }

  factory Bid.fromJson(Map<String, dynamic> json) {
    return Bid.fromMap((json['id'] as String?) ?? '', json);
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'bidAmount': bidAmount,
      'amount': bidAmount,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  Map<String, dynamic> toJson() => toMap();

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
