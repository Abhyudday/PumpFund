import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/fund_model.dart';
import '../models/investment_model.dart';
import '../models/transaction_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Collections
  final String _fundsCollection = 'funds';
  final String _investmentsCollection = 'investments';
  final String _transactionsCollection = 'transactions';
  final String _usersCollection = 'users';

  /// Initialize Firebase Messaging
  Future<void> initializeMessaging() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await _messaging.getToken();
    if (token != null) {
      await saveFcmToken(token);
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(saveFcmToken);
  }

  /// Save FCM token to Firestore
  Future<void> saveFcmToken(String token) async {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      await _firestore.collection(_usersCollection).doc(userId).set({
        'fcmToken': token,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Sign in with email
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  /// Sign up with email
  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  /// Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Fetch all funds (stream - real-time updates)
  Stream<List<FundModel>> getFundsStream() {
    return _firestore
        .collection(_fundsCollection)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FundModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Fetch all funds (one-time)
  Future<List<FundModel>> getFunds() async {
    final snapshot = await _firestore.collection(_fundsCollection).get();
    return snapshot.docs
        .map((doc) => FundModel.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  /// Get fund by ID
  Future<FundModel?> getFundById(String fundId) async {
    final doc = await _firestore.collection(_fundsCollection).doc(fundId).get();
    if (doc.exists) {
      return FundModel.fromJson({...doc.data()!, 'id': doc.id});
    }
    return null;
  }

  /// Create investment
  Future<String> createInvestment(InvestmentModel investment) async {
    final doc = await _firestore.collection(_investmentsCollection).add(investment.toJson());
    return doc.id;
  }

  /// Get user investments
  Stream<List<InvestmentModel>> getUserInvestmentsStream(String userId) {
    return _firestore
        .collection(_investmentsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InvestmentModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Update investment
  Future<void> updateInvestment(String investmentId, Map<String, dynamic> data) async {
    await _firestore.collection(_investmentsCollection).doc(investmentId).update(data);
  }

  /// Add transaction
  Future<String> addTransaction(TransactionModel transaction) async {
    final doc = await _firestore.collection(_transactionsCollection).add(transaction.toJson());
    return doc.id;
  }

  /// Get user transactions
  Stream<List<TransactionModel>> getUserTransactionsStream(String userId) {
    return _firestore
        .collection(_transactionsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Save user wallet address
  Future<void> saveUserWallet(String userId, String walletAddress) async {
    await _firestore.collection(_usersCollection).doc(userId).set({
      'walletAddress': walletAddress,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get user wallet address
  Future<String?> getUserWallet(String userId) async {
    final doc = await _firestore.collection(_usersCollection).doc(userId).get();
    return doc.data()?['walletAddress'] as String?;
  }

  /// Update fund ROI
  Future<void> updateFundRoi(String fundId, double roi) async {
    await _firestore.collection(_fundsCollection).doc(fundId).update({
      'roi7d': roi,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  /// Get investment by fund
  Future<InvestmentModel?> getInvestmentByFund(String userId, String fundId) async {
    final snapshot = await _firestore
        .collection(_investmentsCollection)
        .where('userId', isEqualTo: userId)
        .where('fundId', isEqualTo: fundId)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return InvestmentModel.fromJson({...snapshot.docs.first.data(), 'id': snapshot.docs.first.id});
    }
    return null;
  }

  /// Store encrypted wallet data in Firestore
  Future<void> storeUserWalletData({
    required String userId,
    required String walletAddress,
    required String encryptedPrivateKey,
    required String encryptedMnemonic,
  }) async {
    await _firestore.collection(_usersCollection).doc(userId).set({
      'walletAddress': walletAddress,
      'encryptedPrivateKey': encryptedPrivateKey,
      'encryptedMnemonic': encryptedMnemonic,
      'walletCreatedAt': FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get user's encrypted wallet data
  Future<Map<String, dynamic>?> getUserWalletData(String userId) async {
    final doc = await _firestore.collection(_usersCollection).doc(userId).get();
    if (!doc.exists) return null;
    
    final data = doc.data();
    if (data == null) return null;
    
    return {
      'walletAddress': data['walletAddress'],
      'encryptedPrivateKey': data['encryptedPrivateKey'],
      'encryptedMnemonic': data['encryptedMnemonic'],
    };
  }

  /// Update user data (generic update method)
  Future<void> updateUserData(String userId, Map<String, dynamic> data) async {
    await _firestore.collection(_usersCollection).doc(userId).update(data);
  }

  /// Get user data
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    final doc = await _firestore.collection(_usersCollection).doc(userId).get();
    return doc.data();
  }
}
