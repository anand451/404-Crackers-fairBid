class Auction {
  String id;
  String title;
  double currentPrice;
  double reservePrice;
  DateTime endTime;
  String state;

  Auction({
    required this.id,
    required this.title,
    required this.currentPrice,
    required this.reservePrice,
    required this.endTime,
    required this.state,
  });

  factory Auction.fromJson(Map<String, dynamic> json) {
    return Auction(
      id: json['auctionId'],
      title: json['title'],
      currentPrice: json['currentPrice'].toDouble(),
      reservePrice: json['reservePrice'].toDouble(),
      endTime: DateTime.parse(json['endTime']),
      state: json['state'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'auctionId': id,
      'title': title,
      'currentPrice': currentPrice,
      'reservePrice': reservePrice,
      'endTime': endTime.toIso8601String(),
      'state': state,
    };
  }
}
