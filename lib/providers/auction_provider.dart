import 'dart:async';

import 'package:flutter/material.dart';

import '../models/auction.dart';
import '../models/bid.dart';
import '../services/api_service.dart';
import '../services/auction_service.dart';

class AuctionProvider extends ChangeNotifier {
  AuctionProvider({AuctionService? auctionService})
      : _auctionService = auctionService ?? AuctionService();

  final AuctionService _auctionService;
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

  bool _isConnected = false;
  bool get isConnected => _isConnected;
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  StreamSubscription<List<Auction>>? _auctionsSubscription;
  StreamSubscription<Auction?>? _currentAuctionSubscription;
  Timer? _ticker;

  Future<void> loadAuctions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await _auctionsSubscription?.cancel();
    _auctionsSubscription = _auctionService.streamApprovedAuctions().listen(
      (auctions) {
        _auctions = auctions;
        _isLoading = false;
        notifyListeners();
      },
      onError: (Object error) {
        _errorMessage =
            'We could not load live auctions right now. Please try again.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> joinLiveAuction(String auctionId) async {
    _currentAuction = _auctions.cast<Auction?>().firstWhere(
          (auction) => auction?.id == auctionId,
          orElse: () => null,
        );
    _currentPrice = _currentAuction?.currentPrice ?? 0;
    _timeRemaining =
        _currentAuction?.endTime.difference(DateTime.now()) ?? Duration.zero;
    _leaderboard = _currentPrice > 0
        ? [
            Bid(
              userId: _currentAuction?.sellerId.isNotEmpty == true
                  ? _currentAuction!.sellerId
                  : 'lead',
              amount: _currentPrice,
              normalizedTs: DateTime.now(),
            ),
          ]
        : [];
    _isConnected = true;
    _errorMessage = null;
    notifyListeners();

    await _currentAuctionSubscription?.cancel();
    _currentAuctionSubscription =
        _auctionService.watchAuctionById(auctionId).listen(
      (auction) {
        if (auction == null) {
          _isConnected = false;
          _errorMessage = 'This auction is no longer available.';
          notifyListeners();
          return;
        }

        _currentAuction = auction;
        _currentPrice = auction.currentPrice;
        _timeRemaining = auction.endTime.difference(DateTime.now());
        _leaderboard = [
          Bid(
            userId: auction.sellerId.isNotEmpty ? auction.sellerId : 'lead',
            amount: auction.currentPrice,
            normalizedTs: DateTime.now(),
          ),
        ];
        _isConnected = true;
        notifyListeners();
      },
      onError: (Object error) {
        _isConnected = false;
        _errorMessage = 'Live auction updates disconnected.';
        notifyListeners();
      },
    );

    _startTicker();
  }

  Future<bool> placeBid(double amount) async {
    if (_currentAuction == null) return false;

    try {
      final response = await ApiService.placeBid(
        _currentAuction!.id,
        amount,
        DateTime.now().toIso8601String(), // clientTimestamp
      );

      if (response['success']) {
        _currentPrice = amount;
        _leaderboard = [
          Bid(userId: 'you', amount: amount, normalizedTs: DateTime.now()),
          ..._leaderboard.take(4),
        ];
        await _auctionService.syncBidPrice(
          auctionId: _currentAuction!.id,
          amount: amount,
        );
        notifyListeners();
        return true;
      }
    } catch (e) {
      // Handle race condition - fairness engine handles on backend
    }
    return false;
  }

  void leaveAuction() {
    _ticker?.cancel();
    _currentAuctionSubscription?.cancel();
    _currentAuction = null;
    _isConnected = false;
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_currentAuction == null) {
        return;
      }
      _timeRemaining = _currentAuction!.endTime.difference(DateTime.now());
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _auctionsSubscription?.cancel();
    _currentAuctionSubscription?.cancel();
    super.dispose();
  }
}
