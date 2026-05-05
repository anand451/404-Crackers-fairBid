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
    required this.state,
    DateTime? startTime,
    DateTime? endTime,
    this.description = '',
    this.category = 'General',
    this.durationHours = 1,
    this.latitude,
    this.longitude,
    this.status = 'approved',
    this.sellerId = '',
    this.sellerName = '',
    this.sellerEmail = '',
    DateTime? createdAt,
    this.comments = const [],
    this.requestId,
    this.rejectionReason,
  })  : startTime = startTime ?? endTime ?? DateTime.now(),
        endTime = endTime ??
            (startTime ?? DateTime.now()).add(Duration(hours: durationHours)),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;
  final double currentPrice;
  final double reservePrice;
  final DateTime startTime;
  final DateTime endTime;
  final String state;
  final String description;
  final String category;
  final int durationHours;
  final double? latitude;
  final double? longitude;
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
  bool get hasLocation => latitude != null && longitude != null;
  bool get isLive {
    final now = DateTime.now();
    return state == 'LIVE' &&
        !startTime.isAfter(now) &&
        endTime.isAfter(now);
  }

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
      category: data['category'] as String? ?? 'General',
      currentPrice: (data['currentPrice'] as num?)?.toDouble() ??
          (data['price'] as num?)?.toDouble() ??
          (data['reservePrice'] as num?)?.toDouble() ??
          0,
      reservePrice: (data['reservePrice'] as num?)?.toDouble() ??
          (data['price'] as num?)?.toDouble() ??
          0,
      startTime: _readDate(data['startTime'] ?? data['endTime']),
      endTime: _readEndTime(data),
      state: data['state'] as String? ??
          ((data['status'] as String? ?? 'pending') == 'approved'
              ? 'LIVE'
              : 'PENDING'),
      durationHours: (data['durationHours'] as num?)?.toInt() ??
          (data['duration'] as num?)?.toInt() ??
          1,
      latitude: _readLocationValue(data, 'latitude'),
      longitude: _readLocationValue(data, 'longitude'),
      status: data['status'] as String? ?? 'pending',
      sellerId:
          data['sellerId'] as String? ?? data['createdBy'] as String? ?? '',
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
      'category': category,
      'startTime': Timestamp.fromDate(startTime),
      'currentPrice': currentPrice,
      'reservePrice': reservePrice,
      'price': reservePrice,
      'duration': durationHours,
      'durationHours': durationHours,
      'endTime': Timestamp.fromDate(endTime),
      if (hasLocation)
        'location': {
          'lat': latitude,
          'long': longitude,
        },
      'state': state,
      'status': status,
      'sellerId': sellerId,
      'createdBy': sellerId,
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
    String? category,
    double? currentPrice,
    double? reservePrice,
    DateTime? startTime,
    DateTime? endTime,
    int? durationHours,
    double? latitude,
    double? longitude,
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
      category: category ?? this.category,
      currentPrice: currentPrice ?? this.currentPrice,
      reservePrice: reservePrice ?? this.reservePrice,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationHours: durationHours ?? this.durationHours,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
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

  static DateTime _readEndTime(Map<String, dynamic> data) {
    final explicitEndTime = data['endTime'];
    if (explicitEndTime != null) {
      return _readDate(explicitEndTime);
    }

    final startTime = _readDate(data['startTime']);
    final durationHours = (data['durationHours'] as num?)?.toInt() ??
        (data['duration'] as num?)?.toInt() ??
        1;
    return startTime.add(Duration(hours: durationHours));
  }

  static double? _readLocationValue(Map<String, dynamic> data, String key) {
    final directValue = data[key];
    if (directValue is num) {
      return directValue.toDouble();
    }

    final location = data['location'];
    if (location is Map) {
      final value = location[key] ?? location[key == 'latitude' ? 'lat' : 'long'];
      if (value is num) {
        return value.toDouble();
      }
    }

    return null;
  }
}
