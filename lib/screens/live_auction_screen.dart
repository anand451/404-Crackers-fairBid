import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../providers/auction_provider.dart';

class LiveAuctionScreen extends StatefulWidget {
  final String auctionId;
  const LiveAuctionScreen({super.key, required this.auctionId});

  @override
  State<LiveAuctionScreen> createState() => _LiveAuctionScreenState();
}

class _LiveAuctionScreenState extends State<LiveAuctionScreen> {
  final _bidController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<AuctionProvider>().joinLiveAuction(widget.auctionId);
    });
  }

  Future<void> _placeBid() async {
    final amount = double.tryParse(_bidController.text);
    if (amount == null) {
      return;
    }

    final success = await Provider.of<AuctionProvider>(
      context,
      listen: false,
    ).placeBid(amount);
    if (!mounted) {
      return;
    }

    if (success) {
      _bidController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bid placed successfully! 🎉')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bid failed - check fairness rules')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Auction')),
      body: Consumer<AuctionProvider>(
        builder: (context, provider, child) {
          if (provider.currentAuction == null) {
            return const Center(child: SpinKitDoubleBounce(color: Colors.blue));
          }

          final auction = provider.currentAuction!;
          final timeLeft = auction.endTime.difference(DateTime.now());

          return Column(
            children: [
              // Auction Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      auction.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${provider.currentPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(offset: Offset(2, 2), blurRadius: 4)],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.isConnected ? '🟢 LIVE' : '🔴 DISCONNECTED',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Time Remaining & Fairness Badge
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        const Text('Time Left', style: TextStyle(fontSize: 12)),
                        Text(
                          timeLeft.isNegative
                              ? 'ENDED'
                              : '${timeLeft.inMinutes}m ${timeLeft.inSeconds % 60}s',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: timeLeft.inMinutes < 1
                                ? Colors.red
                                : Colors.green,
                          ),
                        ),
                      ],
                    ),
                    if (provider.isConnected)
                      const Column(
                        children: [
                          Text('Fairness', style: TextStyle(fontSize: 12)),
                          Icon(Icons.verified, color: Colors.green, size: 24),
                        ],
                      ),
                  ],
                ),
              ),

              // Leaderboard
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Leaderboard',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: provider.leaderboard.length,
                  itemBuilder: (context, index) {
                    final bid = provider.leaderboard[index];
                    return Container(
                      width: 100,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('#${index + 1}'),
                          Text('\$${bid.amount.toStringAsFixed(0)}'),
                          Text(
                            bid.userId.substring(0, 4),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const Spacer(),

              // Bid Input
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    TextField(
                      controller: _bidController,
                      decoration: InputDecoration(
                        labelText: 'Your Bid',
                        prefixText: '\$ ',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _placeBid,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _placeBid,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Place Bid',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    Provider.of<AuctionProvider>(context, listen: false).leaveAuction();
    _bidController.dispose();
    super.dispose();
  }
}
