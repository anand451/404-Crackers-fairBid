import 'dart:async';

import 'package:flutter/material.dart';

import '../models/auction.dart';
import '../services/auction_service.dart';

class AuctionProvider extends ChangeNotifier {
  AuctionProvider({AuctionService? auctionService})
      : _auctionService = auctionService ?? AuctionService();

  final AuctionService _auctionService;

  List<Auction> _auctions = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<Auction>>? _auctionsSubscription;

  List<Auction> get auctions => _auctions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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

  @override
  void dispose() {
    _auctionsSubscription?.cancel();
    super.dispose();
  }
}
