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
    this.upiId = '',
    this.highestBidId,
    this.highestBidderId,
    this.highestBidderName,
    this.winnerId,
    this.winnerName,
    this.finalPrice,
    this.paymentStatus = 'unpaid',
    this.paymentId,
    DateTime? createdAt,
    this.startedAt,
    this.pausedAt,
    this.soldAt,
    this.endedAt,
    this.updatedAt,
    int? remainingSeconds,
    this.bidCount = 0,
    this.comments = const [],
    this.requestId,
    this.rejectionReason,
  })  : startTime = startTime ?? endTime ?? DateTime.now(),
        endTime = endTime ??
            (startTime ?? DateTime.now()).add(Duration(hours: durationHours)),
        createdAt = createdAt ?? DateTime.now(),
        remainingSeconds = remainingSeconds ?? durationHours * 3600;

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
  final String upiId;
  final String? highestBidId;
  final String? highestBidderId;
  final String? highestBidderName;
  final String? winnerId;
  final String? winnerName;
  final double? finalPrice;
  final String paymentStatus;
  final String? paymentId;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? pausedAt;
  final DateTime? soldAt;
  final DateTime? endedAt;
  final DateTime? updatedAt;
  final int remainingSeconds;
  final int bidCount;
  final List<AuctionComment> comments;
  final String? requestId;
  final String? rejectionReason;

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get hasLocation => latitude != null && longitude != null;
  bool get isPaused => state == 'PAUSED';
  bool get isSold => state == 'SOLD';
  bool get isEnded => state == 'ENDED';
  bool get canAcceptBids =>
      status == 'approved' &&
      state == 'LIVE' &&
      endTime.isAfter(DateTime.now());
  bool get isPaymentCompleted => paymentStatus == 'completed';
  bool get isVisibleInMarketplace =>
      status == 'approved' && !isSold && !isEnded && !isRejected;
  bool get isLive {
    final now = DateTime.now();
    return state == 'LIVE' && !startTime.isAfter(now) && endTime.isAfter(now);
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
      upiId: data['upiId'] as String? ?? '',
      highestBidId: data['highestBidId'] as String?,
      highestBidderId: data['highestBidderId'] as String?,
      highestBidderName: data['highestBidderName'] as String?,
      winnerId: data['winnerId'] as String?,
      winnerName: data['winnerName'] as String?,
      finalPrice: (data['finalPrice'] as num?)?.toDouble(),
      paymentStatus: data['paymentStatus'] as String? ?? 'unpaid',
      paymentId: data['paymentId'] as String?,
      createdAt: _readDate(data['createdAt']),
      startedAt: _readNullableDate(data['startedAt']),
      pausedAt: _readNullableDate(data['pausedAt']),
      soldAt: _readNullableDate(data['soldAt']),
      endedAt: _readNullableDate(data['endedAt']),
      updatedAt: _readNullableDate(data['updatedAt']),
      remainingSeconds: (data['remainingSeconds'] as num?)?.toInt() ??
          ((data['durationHours'] as num?)?.toInt() ??
                  (data['duration'] as num?)?.toInt() ??
                  1) *
              3600,
      bidCount: (data['bidCount'] as num?)?.toInt() ?? 0,
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
      'upiId': upiId,
      'highestBidId': highestBidId,
      'highestBidderId': highestBidderId,
      'highestBidderName': highestBidderName,
      'winnerId': winnerId,
      'winnerName': winnerName,
      'finalPrice': finalPrice,
      'paymentStatus': paymentStatus,
      'paymentId': paymentId,
      'createdAt': Timestamp.fromDate(createdAt),
      'startedAt': _writeNullableDate(startedAt),
      'pausedAt': _writeNullableDate(pausedAt),
      'soldAt': _writeNullableDate(soldAt),
      'endedAt': _writeNullableDate(endedAt),
      'updatedAt': _writeNullableDate(updatedAt),
      'remainingSeconds': remainingSeconds,
      'bidCount': bidCount,
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
    String? upiId,
    String? highestBidId,
    String? highestBidderId,
    String? highestBidderName,
    String? winnerId,
    String? winnerName,
    double? finalPrice,
    String? paymentStatus,
    String? paymentId,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? pausedAt,
    DateTime? soldAt,
    DateTime? endedAt,
    DateTime? updatedAt,
    int? remainingSeconds,
    int? bidCount,
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
      upiId: upiId ?? this.upiId,
      highestBidId: highestBidId ?? this.highestBidId,
      highestBidderId: highestBidderId ?? this.highestBidderId,
      highestBidderName: highestBidderName ?? this.highestBidderName,
      winnerId: winnerId ?? this.winnerId,
      winnerName: winnerName ?? this.winnerName,
      finalPrice: finalPrice ?? this.finalPrice,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentId: paymentId ?? this.paymentId,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      pausedAt: pausedAt ?? this.pausedAt,
      soldAt: soldAt ?? this.soldAt,
      endedAt: endedAt ?? this.endedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      bidCount: bidCount ?? this.bidCount,
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

  static DateTime? _readNullableDate(dynamic value) {
    if (value == null) {
      return null;
    }
    return _readDate(value);
  }

  static Timestamp? _writeNullableDate(DateTime? value) {
    if (value == null) {
      return null;
    }
    return Timestamp.fromDate(value);
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
      final value =
          location[key] ?? location[key == 'latitude' ? 'lat' : 'long'];
      if (value is num) {
        return value.toDouble();
      }
    }

    return null;
  }
}
