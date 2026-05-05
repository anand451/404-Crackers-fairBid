import 'package:cloud_firestore/cloud_firestore.dart';

class AuctionComment {
  const AuctionComment({
    required this.userName,
    required this.message,
    required this.createdAt,
  });

  final String userName;
  final String message;
  final DateTime createdAt;

  factory AuctionComment.fromMap(Map<String, dynamic> map) {
    return AuctionComment(
      userName: map['userName'] as String? ?? 'Unknown user',
      message: map['message'] as String? ?? '',
      createdAt: _readDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userName': userName,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
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

class Auction {
  Auction({
    required this.id,
    required this.title,
    required this.currentPrice,
    required this.reservePrice,
    required this.endTime,
    required this.state,
    this.description = '',
    this.status = 'approved',
    this.sellerId = '',
    this.sellerName = '',
    this.sellerEmail = '',
    DateTime? createdAt,
    this.comments = const [],
    this.requestId,
    this.rejectionReason,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;
  final double currentPrice;
  final double reservePrice;
  final DateTime endTime;
  final String state;
  final String description;
  final String status;
  final String sellerId;
  final String sellerName;
  final String sellerEmail;
  final DateTime createdAt;
  final List<AuctionComment> comments;
  final String? requestId;
  final String? rejectionReason;

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get isLive => state == 'LIVE' && endTime.isAfter(DateTime.now());

  factory Auction.fromJson(Map<String, dynamic> json) {
    return Auction.fromMap(
      (json['auctionId'] ?? json['id'] ?? '') as String,
      json,
    );
  }

  factory Auction.fromMap(String id, Map<String, dynamic> data) {
    return Auction(
      id: id,
      title: data['title'] as String? ?? 'Untitled auction',
      description: data['description'] as String? ?? '',
      currentPrice: (data['currentPrice'] as num?)?.toDouble() ??
          (data['reservePrice'] as num?)?.toDouble() ??
          0,
      reservePrice: (data['reservePrice'] as num?)?.toDouble() ?? 0,
      endTime: _readDate(data['endTime']),
      state: data['state'] as String? ??
          ((data['status'] as String? ?? 'pending') == 'approved'
              ? 'LIVE'
              : 'PENDING'),
      status: data['status'] as String? ?? 'pending',
      sellerId: data['sellerId'] as String? ?? '',
      sellerName: data['sellerName'] as String? ?? '',
      sellerEmail: data['sellerEmail'] as String? ?? '',
      createdAt: _readDate(data['createdAt']),
      comments: (data['comments'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map(
            (comment) => AuctionComment.fromMap(
              Map<String, dynamic>.from(comment),
            ),
          )
          .toList(),
      requestId: data['requestId'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return toMap();
  }

  Map<String, dynamic> toMap() {
    return {
      'auctionId': id,
      'id': id,
      'title': title,
      'description': description,
      'currentPrice': currentPrice,
      'reservePrice': reservePrice,
      'endTime': Timestamp.fromDate(endTime),
      'state': state,
      'status': status,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerEmail': sellerEmail,
      'createdAt': Timestamp.fromDate(createdAt),
      'comments': comments.map((comment) => comment.toMap()).toList(),
      'requestId': requestId,
      'rejectionReason': rejectionReason,
    };
  }

  Auction copyWith({
    String? id,
    String? title,
    String? description,
    double? currentPrice,
    double? reservePrice,
    DateTime? endTime,
    String? state,
    String? status,
    String? sellerId,
    String? sellerName,
    String? sellerEmail,
    DateTime? createdAt,
    List<AuctionComment>? comments,
    String? requestId,
    String? rejectionReason,
  }) {
    return Auction(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      currentPrice: currentPrice ?? this.currentPrice,
      reservePrice: reservePrice ?? this.reservePrice,
      endTime: endTime ?? this.endTime,
      state: state ?? this.state,
      status: status ?? this.status,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      sellerEmail: sellerEmail ?? this.sellerEmail,
      createdAt: createdAt ?? this.createdAt,
      comments: comments ?? this.comments,
      requestId: requestId ?? this.requestId,
      rejectionReason: rejectionReason ?? this.rejectionReason,
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
}
