import 'package:cloud_firestore/cloud_firestore.dart';

class AuctionWatcher {
  const AuctionWatcher({
    required this.userId,
    required this.userName,
    required this.enteredAt,
  });

  final String userId;
  final String userName;
  final DateTime enteredAt;

  factory AuctionWatcher.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AuctionWatcher(
      userId: data['userId'] as String? ?? doc.id,
      userName: data['userName'] as String? ?? 'Viewer',
      enteredAt: _readDate(data['enteredAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'enteredAt': Timestamp.fromDate(enteredAt),
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
}
