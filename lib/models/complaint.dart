import 'package:cloud_firestore/cloud_firestore.dart';

class Complaint {
  const Complaint({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.message,
    required this.status,
    required this.adminReply,
    required this.timestamp,
    this.resolvedAt,
    this.adminId,
  });

  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String message;
  final String status;
  final String adminReply;
  final DateTime timestamp;
  final DateTime? resolvedAt;
  final String? adminId;

  bool get isResolved => status == 'resolved';

  factory Complaint.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Complaint.fromMap(doc.id, doc.data() ?? <String, dynamic>{});
  }

  factory Complaint.fromMap(String id, Map<String, dynamic> data) {
    return Complaint(
      id: data['complaintId'] as String? ?? id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? 'FairBid user',
      userEmail: data['userEmail'] as String? ?? '',
      message: data['message'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      adminReply: data['adminReply'] as String? ?? '',
      timestamp: _readDate(data['timestamp']),
      resolvedAt: _readNullableDate(data['resolvedAt']),
      adminId: data['adminId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'complaintId': id,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'message': message,
      'status': status,
      'adminReply': adminReply,
      'timestamp': Timestamp.fromDate(timestamp),
      'resolvedAt': resolvedAt == null ? null : Timestamp.fromDate(resolvedAt!),
      'adminId': adminId,
    };
  }

  Complaint copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userEmail,
    String? message,
    String? status,
    String? adminReply,
    DateTime? timestamp,
    DateTime? resolvedAt,
    String? adminId,
  }) {
    return Complaint(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      message: message ?? this.message,
      status: status ?? this.status,
      adminReply: adminReply ?? this.adminReply,
      timestamp: timestamp ?? this.timestamp,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      adminId: adminId ?? this.adminId,
    );
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
