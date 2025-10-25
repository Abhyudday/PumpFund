import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FundModel extends Equatable {
  final String id;
  final String name;
  final String description;
  final List<String> walletAddresses;
  final double roi7d;
  final List<double> roiHistory; // Daily ROI for last 7 days [day1, day2, ..., day7]
  final DateTime lastUpdated;
  final String imageUrl;

  const FundModel({
    required this.id,
    required this.name,
    required this.description,
    required this.walletAddresses,
    required this.roi7d,
    this.roiHistory = const [],
    required this.lastUpdated,
    this.imageUrl = '',
  });

  factory FundModel.fromJson(Map<String, dynamic> json) {
    return FundModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      walletAddresses: List<String>.from(json['walletAddresses'] ?? []),
      roi7d: (json['roi7d'] as num?)?.toDouble() ?? 0.0,
      roiHistory: (json['roiHistory'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [],
      lastUpdated: _parseTimestamp(json['lastUpdated']),
      imageUrl: json['imageUrl'] as String? ?? '',
    );
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'walletAddresses': walletAddresses,
      'roi7d': roi7d,
      'roiHistory': roiHistory,
      'lastUpdated': lastUpdated.toIso8601String(),
      'imageUrl': imageUrl,
    };
  }

  @override
  List<Object?> get props => [id, name, description, walletAddresses, roi7d, roiHistory, lastUpdated, imageUrl];
}
