class Bid {
  final String userId;
  final double amount;
  final DateTime normalizedTs;

  Bid({required this.userId, required this.amount, required this.normalizedTs});

  factory Bid.fromJson(Map<String, dynamic> json) {
    return Bid(
      userId: json['userId'],
      amount: json['amount'].toDouble(),
      normalizedTs: DateTime.parse(json['normalizedTs']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'amount': amount,
      'normalizedTs': normalizedTs.toIso8601String(),
    };
  }
}
