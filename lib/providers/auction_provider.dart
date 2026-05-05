import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import '../models/auction.dart';
import '../models/bid.dart';
import '../services/api_service.dart';

class AuctionProvider extends ChangeNotifier {
  List<Auction> _auctions = [];
  List<Auction> get auctions => _auctions;

  Auction? _currentAuction;
  Auction? get currentAuction => _currentAuction;

  double _currentPrice = 0.0;
  double get currentPrice => _currentPrice;

  Duration _timeRemaining = Duration.zero;
  Duration get timeRemaining => _timeRemaining;

  List<Bid> _leaderboard = [];
  List<Bid> get leaderboard => _leaderboard;

  WebSocketChannel? _wsChannel;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Future<void> loadAuctions() async {
    // Mock API call matching design
    await Future.delayed(const Duration(milliseconds: 500));
    _auctions = [
      Auction(
        id: 'au_123',
        title: 'iPhone 15 Pro Max',
        currentPrice: 950.50,
        reservePrice: 800.00,
        endTime: DateTime.now().add(const Duration(minutes: 45)),
        state: 'LIVE',
      ),
      Auction(
        id: 'au_124',
        title: 'MacBook Pro M3',
        currentPrice: 2200.00,
        reservePrice: 2000.00,
        endTime: DateTime.now().add(const Duration(hours: 2)),
        state: 'LIVE',
      ),
    ];
    notifyListeners();
  }

  Future<void> joinLiveAuction(String auctionId) async {
    _currentAuction = _auctions.firstWhere((a) => a.id == auctionId);

    // Connect WebSocket (mock real-time from design)
    try {
      _wsChannel = WebSocketChannel.connect(
        Uri.parse('ws://localhost:8080/auction/$auctionId/live'),
      );

      _wsChannel!.stream.listen(
        (message) {
          final data = json.decode(message);
          _handleRealtimeUpdate(data);
        },
        onError: (error) => _isConnected = false,
        onDone: () => _isConnected = false,
      );

      _isConnected = true;
      notifyListeners();

      // Mock initial state
      _currentPrice = _currentAuction!.currentPrice;
      _timeRemaining = _currentAuction!.endTime.difference(DateTime.now());
      _leaderboard = [
        Bid(userId: 'u1', amount: _currentPrice, normalizedTs: DateTime.now()),
      ];
    } catch (e) {
      // Fallback to polling
      _pollAuctionState();
    }
  }

  void _handleRealtimeUpdate(Map<String, dynamic> data) {
    if (data['type'] == 'BID_UPDATE') {
      _currentPrice = data['currentPrice'].toDouble();
      notifyListeners();
    } else if (data['type'] == 'AUCTION_EXTENDED') {
      _currentAuction!.endTime = DateTime.parse(data['newEndTime']);
      notifyListeners();
    }
  }

  Future<bool> placeBid(double amount) async {
    if (_currentAuction == null) return false;

    try {
      // Match Bid Submission System from design
      final response = await ApiService.placeBid(
        _currentAuction!.id,
        amount,
        DateTime.now().toIso8601String(), // clientTimestamp
      );

      if (response['success']) {
        _currentPrice = amount;
        notifyListeners();
        return true;
      }
    } catch (e) {
      // Handle race condition - fairness engine handles on backend
    }
    return false;
  }

  void leaveAuction() {
    _wsChannel?.sink.close();
    _currentAuction = null;
    _isConnected = false;
    notifyListeners();
  }

  void _pollAuctionState() {
    // Fallback polling every 2s
    Future.delayed(const Duration(seconds: 2), () {
      if (_currentAuction != null) {
        // Update time remaining
        _timeRemaining = _currentAuction!.endTime.difference(DateTime.now());
        notifyListeners();
        _pollAuctionState();
      }
    });
  }

  @override
  void dispose() {
    _wsChannel?.sink.close();
    super.dispose();
  }
}
