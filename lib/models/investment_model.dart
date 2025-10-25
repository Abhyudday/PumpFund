import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InvestmentModel extends Equatable {
  final String id;
  final String userId;
  final String fundId;
  final double allocatedAmount;
  final double purchaseSizePercentage; // 1-100%
  final double currentValue;
  final double totalPnl;
  final DateTime investedAt;
  final bool autoApprove;
  final bool isActive;

  const InvestmentModel({
    required this.id,
    required this.userId,
    required this.fundId,
    required this.allocatedAmount,
    required this.purchaseSizePercentage,
    required this.currentValue,
    required this.totalPnl,
    required this.investedAt,
    this.autoApprove = false,
    this.isActive = true,
  });

  factory InvestmentModel.fromJson(Map<String, dynamic> json) {
    return InvestmentModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      fundId: json['fundId'] as String,
      allocatedAmount: (json['allocatedAmount'] as num?)?.toDouble() ?? 0.0,
      purchaseSizePercentage: (json['purchaseSizePercentage'] as num?)?.toDouble() ?? 10.0,
      currentValue: (json['currentValue'] as num?)?.toDouble() ?? 0.0,
      totalPnl: (json['totalPnl'] as num?)?.toDouble() ?? 0.0,
      investedAt: _parseTimestamp(json['investedAt']),
      autoApprove: json['autoApprove'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'fundId': fundId,
      'allocatedAmount': allocatedAmount,
      'purchaseSizePercentage': purchaseSizePercentage,
      'currentValue': currentValue,
      'totalPnl': totalPnl,
      'investedAt': investedAt.toIso8601String(),
      'autoApprove': autoApprove,
      'isActive': isActive,
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
        allocatedAmount,
        purchaseSizePercentage,
        currentValue,
        totalPnl,
        investedAt,
        autoApprove,
        isActive,
      ];
}
