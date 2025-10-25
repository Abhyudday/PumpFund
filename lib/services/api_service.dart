import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // API endpoints
  // Note: Helius API key stored in backend, not used directly in app
  static const String _solanaTrackerBaseUrl = 'https://data.solanatracker.io';
  static const String _backendBaseUrl = 'https://pump-funds-production.up.railway.app'; // Your Node.js backend on Railway

  /// Get wallet PNL from SolanaTracker
  Future<Map<String, dynamic>> getWalletPnl(String walletAddress, {String period = '7d'}) async {
    try {
      final url = '$_solanaTrackerBaseUrl/pnl/wallet?wallet=$walletAddress&period=$period';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to fetch PNL: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('API error: $e');
    }
  }

  /// Calculate average ROI for multiple wallets
  Future<double> calculateFundRoi(List<String> walletAddresses) async {
    try {
      double totalRoi = 0;
      int successCount = 0;

      for (final address in walletAddresses) {
        try {
          final pnlData = await getWalletPnl(address);
          final roi = (pnlData['roi'] as num?)?.toDouble() ?? 0.0;
          totalRoi += roi;
          successCount++;
        } catch (e) {
          // Skip failed wallet fetches
          continue;
        }
      }

      if (successCount == 0) return 0.0;
      return totalRoi / successCount;
    } catch (e) {
      throw Exception('Failed to calculate ROI: $e');
    }
  }

  /// Get token price from Jupiter
  Future<double> getTokenPrice(String tokenMintAddress) async {
    try {
      final url = 'https://price.jup.ag/v4/price?ids=$tokenMintAddress';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['data'][tokenMintAddress]['price'] as num?)?.toDouble() ?? 0.0;
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// Subscribe to fund (notify backend)
  Future<bool> subscribeToFund(String userId, String fundId, double allocatedAmount, {bool autoApprove = true}) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendBaseUrl/api/subscribe'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'fundId': fundId,
          'allocatedAmount': allocatedAmount,
          'autoApprove': autoApprove,
          'purchaseSizePercentage': 100,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to subscribe: $e');
    }
  }

  /// Unsubscribe from fund
  Future<bool> unsubscribeFromFund(String userId, String fundId) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendBaseUrl/api/unsubscribe'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'fundId': fundId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to unsubscribe: $e');
    }
  }

  /// Update investment settings
  Future<bool> updateInvestment({
    required String userId,
    required String fundId,
    double? allocatedAmount,
    double? purchaseSizePercentage,
    bool? autoApprove,
    bool? isActive,
  }) async {
    try {
      final body = <String, dynamic>{
        'userId': userId,
        'fundId': fundId,
      };
      
      if (allocatedAmount != null) body['allocatedAmount'] = allocatedAmount;
      if (purchaseSizePercentage != null) body['purchaseSizePercentage'] = purchaseSizePercentage;
      if (autoApprove != null) body['autoApprove'] = autoApprove;
      if (isActive != null) body['isActive'] = isActive;

      final response = await http.post(
        Uri.parse('$_backendBaseUrl/api/update-investment'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to update investment: $e');
    }
  }

  /// Get Solana transaction details
  Future<Map<String, dynamic>> getTransactionDetails(String signature) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.mainnet-beta.solana.com'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'getTransaction',
          'params': [signature, {'encoding': 'jsonParsed'}],
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['result'] as Map<String, dynamic>;
      }
      throw Exception('Failed to fetch transaction');
    } catch (e) {
      throw Exception('Transaction fetch error: $e');
    }
  }

  /// Get recent transactions for wallet
  Future<List<Map<String, dynamic>>> getWalletTransactions(String address, {int limit = 10}) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.mainnet-beta.solana.com'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'getSignaturesForAddress',
          'params': [address, {'limit': limit}],
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['result'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get SPL token accounts for wallet
  Future<List<Map<String, dynamic>>> getTokenAccounts(String walletAddress) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.mainnet-beta.solana.com'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'getTokenAccountsByOwner',
          'params': [
            walletAddress,
            {'programId': 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'},
            {'encoding': 'jsonParsed'}
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final accounts = data['result']?['value'] as List? ?? [];
        
        List<Map<String, dynamic>> tokens = [];
        for (var account in accounts) {
          try {
            final tokenAmount = account['account']['data']['parsed']['info']['tokenAmount'];
            final mint = account['account']['data']['parsed']['info']['mint'];
            final uiAmount = tokenAmount['uiAmount'];
            
            if (uiAmount != null && uiAmount > 0) {
              tokens.add({
                'mint': mint,
                'amount': uiAmount,
                'decimals': tokenAmount['decimals'],
              });
            }
          } catch (e) {
            // Skip invalid token accounts
          }
        }
        return tokens;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get all available funds from backend
  Future<List<Map<String, dynamic>>> getAllFunds() async {
    try {
      final response = await http.get(
        Uri.parse('$_backendBaseUrl/api/funds'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['funds'] ?? []);
      }
      throw Exception('Failed to fetch funds: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to fetch funds: $e');
    }
  }

  /// Get specific fund details
  Future<Map<String, dynamic>> getFundDetails(String fundId) async {
    try {
      final response = await http.get(
        Uri.parse('$_backendBaseUrl/api/funds/$fundId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Failed to fetch fund: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to fetch fund: $e');
    }
  }
}
