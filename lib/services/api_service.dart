import '../models/auction.dart';

class ApiService {
  static const String baseUrl =
      'http://localhost:3000/api'; // Mock backend from design

  static Future<Map<String, dynamic>> placeBid(
    String auctionId,
    double amount,
    String clientTimestamp,
  ) async {
    // Mock Bid Submission System with latency normalization simulation
    await Future.delayed(
      Duration(milliseconds: (100 + (amount % 300).toInt())),
    ); // Simulate network latency

    // Simulate fairness engine rejection (5% chance for demo)
    if ((amount % 19).toInt() % 20 == 0) {
      return {
        'success': false,
        'reason': 'Bid rejected - latency too high (Fairness Engine)',
      };
    }

    return {
      'success': true,
      'bidId': 'bid_${DateTime.now().millisecondsSinceEpoch}',
      'position': '1st',
      'currentPrice': amount,
    };
  }

  static Future<List<Auction>> getLiveAuctions() async {
    // Mock matching PostgreSQL query
    await Future.delayed(const Duration(milliseconds: 200));
    return [
      Auction(
        id: 'au_123',
        title: 'iPhone 15 Pro Max',
        currentPrice: 955.50,
        reservePrice: 800.00,
        endTime: DateTime.now().add(const Duration(minutes: 42)),
        state: 'LIVE',
      ),
    ];
  }

  static Future<Map<String, dynamic>> createAuction(Auction auction) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return {'success': true, 'auctionId': auction.id};
  }
}
