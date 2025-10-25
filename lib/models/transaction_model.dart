import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { buy, sell }

class TransactionModel extends Equatable {
  final String id;
  final String userId;
  final String fundId;
  final TransactionType type;
  final String tokenAddress;
  final String tokenSymbol;
  final double amount;
  final double price;
  final double totalValue;
  final String signature;
  final DateTime timestamp;
  final bool isSuccess;
  final String? errorMessage;

  const TransactionModel({
    required this.id,
    required this.userId,
    required this.fundId,
    required this.type,
    required this.tokenAddress,
    required this.tokenSymbol,
    required this.amount,
    required this.price,
    required this.totalValue,
    required this.signature,
    required this.timestamp,
    this.isSuccess = true,
    this.errorMessage,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      fundId: json['fundId'] as String,
      type: json['type'] == 'buy' ? TransactionType.buy : TransactionType.sell,
      tokenAddress: json['tokenAddress'] as String,
      tokenSymbol: json['tokenSymbol'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      totalValue: (json['totalValue'] as num?)?.toDouble() ?? 0.0,
      signature: json['signature'] as String,
      timestamp: _parseTimestamp(json['timestamp']),
      isSuccess: json['isSuccess'] as bool? ?? true,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'fundId': fundId,
      'type': type == TransactionType.buy ? 'buy' : 'sell',
      'tokenAddress': tokenAddress,
      'tokenSymbol': tokenSymbol,
      'amount': amount,
      'price': price,
      'totalValue': totalValue,
      'signature': signature,
      'timestamp': timestamp.toIso8601String(),
      'isSuccess': isSuccess,
      'errorMessage': errorMessage,
    };
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) {
      return DateTime.now();
    }
    
    // Handle Firestore Timestamp objects
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    
    // Handle string timestamps (for backward compatibility)
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        return DateTime.now();
      }
    }
    
    // Handle milliseconds since epoch
    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    
    return DateTime.now();
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        fundId,
        type,
        tokenAddress,
        tokenSymbol,
        amount,
        price,
        totalValue,
        signature,
        timestamp,
        isSuccess,
        errorMessage,
      ];
}
