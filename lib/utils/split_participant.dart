class SplitParticipant {
  final String email;
  final String name;
  final double amount;
  final double percentage;
  final bool isCustomAmount;
  final String splitType;
  final bool isPaid;

  SplitParticipant({
    required this.email,
    this.name = '',
    required this.amount,
    this.percentage = 0.0,
    this.isCustomAmount = false,
    this.splitType = 'equal',
    this.isPaid = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
      'share': amount.toString(),
      'percentage': percentage,
      'isCustomAmount': isCustomAmount,
      'splitType': splitType,
    };
  }

  factory SplitParticipant.fromJson(Map<String, dynamic> json) {
    return SplitParticipant(
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      amount: double.tryParse(json['share']?.toString() ?? '0') ?? 0.0,
      percentage: (json['percentage'] ?? 0.0).toDouble(),
      isCustomAmount: json['isCustomAmount'] ?? false,
      splitType: json['splitType'] ?? 'equal',
      isPaid: json['isPaid'] ?? false,
    );
  }

  SplitParticipant copyWith({
    String? email,
    String? name,
    double? amount,
    double? percentage,
    bool? isCustomAmount,
    String? splitType,
    bool? isPaid,
  }) {
    return SplitParticipant(
      email: email ?? this.email,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      percentage: percentage ?? this.percentage,
      isCustomAmount: isCustomAmount ?? this.isCustomAmount,
      splitType: splitType ?? this.splitType,
      isPaid: isPaid ?? this.isPaid,
    );
  }
}