import 'package:equatable/equatable.dart';

class WalletModel extends Equatable {
  final String address;
  final double balance; // SOL balance
  final double usdcBalance;
  final DateTime createdAt;
  final String? privateKey; // Optional - only loaded when explicitly requested

  const WalletModel({
    required this.address,
    required this.balance,
    required this.usdcBalance,
    required this.createdAt,
    this.privateKey,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      address: json['address'] as String,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      usdcBalance: (json['usdcBalance'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'balance': balance,
      'usdcBalance': usdcBalance,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  WalletModel copyWith({
    String? address,
    double? balance,
    double? usdcBalance,
    DateTime? createdAt,
    String? privateKey,
  }) {
    return WalletModel(
      address: address ?? this.address,
      balance: balance ?? this.balance,
      usdcBalance: usdcBalance ?? this.usdcBalance,
      createdAt: createdAt ?? this.createdAt,
      privateKey: privateKey ?? this.privateKey,
    );
  }

  @override
  List<Object?> get props => [address, balance, usdcBalance, createdAt, privateKey];
}
