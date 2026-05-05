import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../providers/auth_provider.dart';
import '../providers/auction_provider.dart';
import 'live_auction_screen.dart';
import 'create_auction_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuctionProvider>(context, listen: false).loadAuctions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('FairBid'),
            if (authProvider.userProfile?.fullName.isNotEmpty ?? false)
              Text(
                authProvider.userProfile!.fullName,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                    ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateAuctionScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () =>
                Provider.of<AuthProvider>(context, listen: false).logout(),
          ),
        ],
      ),
      body: Consumer<AuctionProvider>(
        builder: (context, auctionProvider, child) {
          if (auctionProvider.isLoading) {
            return const Center(
              child: SpinKitWave(color: Colors.blue, size: 50.0),
            );
          }

          if (auctionProvider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  auctionProvider.errorMessage!,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return Column(
            children: [
              if (!authProvider.isEmailVerified)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7D6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFE08A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.mark_email_unread_outlined,
                        color: Color(0xFF9A6700),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Verify your email to strengthen account trust and recovery options.',
                        ),
                      ),
                      TextButton(
                        onPressed: authProvider.reloadUser,
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: auctionProvider.auctions.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No approved auctions are live yet. Check back after an admin approves new listings.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: auctionProvider.auctions.length,
                        itemBuilder: (context, index) {
                          final auction = auctionProvider.auctions[index];
                          final timeLeft =
                              auction.endTime.difference(DateTime.now());

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child:
                                    const Icon(Icons.gavel, color: Colors.blue),
                              ),
                              title: Text(auction.title),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (auction.description.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          top: 4, bottom: 6),
                                      child: Text(auction.description),
                                    ),
                                  Text(
                                    '\$${auction.currentPrice.toStringAsFixed(2)}',
                                  ),
                                  Text(
                                    timeLeft.isNegative
                                        ? 'Closed'
                                        : '${timeLeft.inMinutes}m ${timeLeft.inSeconds.remainder(60)}s',
                                    style: TextStyle(
                                      color: timeLeft.inMinutes < 5
                                          ? Colors.red
                                          : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: ElevatedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LiveAuctionScreen(
                                      auctionId: auction.id,
                                    ),
                                  ),
                                ),
                                child: const Text('Join Live'),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
