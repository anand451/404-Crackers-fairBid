import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.auctionId,
    required this.auctionTitle,
    required this.buyerId,
    required this.buyerName,
    required this.sellerId,
    required this.sellerName,
    required this.amount,
    required this.status,
    required this.timestamp,
    required this.receiptNumber,
    required this.upiId,
  });

  final String id;
  final String auctionId;
  final String auctionTitle;
  final String buyerId;
  final String buyerName;
  final String sellerId;
  final String sellerName;
  final double amount;
  final String status;
  final DateTime timestamp;
  final String receiptNumber;
  final String upiId;

  bool get isCompleted => status == 'completed';

  factory PaymentRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return PaymentRecord.fromMap(doc.id, doc.data() ?? <String, dynamic>{});
  }

  factory PaymentRecord.fromMap(String id, Map<String, dynamic> data) {
    return PaymentRecord(
      id: id,
      auctionId: data['auctionId'] as String? ?? '',
      auctionTitle: data['auctionTitle'] as String? ?? 'Auction',
      buyerId: data['buyerId'] as String? ?? '',
      buyerName: data['buyerName'] as String? ?? 'Buyer',
      sellerId: data['sellerId'] as String? ?? '',
      sellerName: data['sellerName'] as String? ?? 'Seller',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      status: data['status'] as String? ?? 'pending',
      timestamp: _readDate(data['timestamp']),
      receiptNumber: data['receiptNumber'] as String? ?? id,
      upiId: data['upiId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'auctionId': auctionId,
      'auctionTitle': auctionTitle,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'amount': amount,
      'status': status,
      'timestamp': Timestamp.fromDate(timestamp),
      'receiptNumber': receiptNumber,
      'upiId': upiId,
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
