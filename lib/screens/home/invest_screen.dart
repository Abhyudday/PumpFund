import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/fund_model.dart';
import '../../models/investment_model.dart';
import '../../blocs/wallet/wallet_bloc.dart';
import '../../services/firebase_service.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';

class InvestScreen extends StatefulWidget {
  final FundModel fund;

  const InvestScreen({super.key, required this.fund});

  @override
  State<InvestScreen> createState() => _InvestScreenState();
}

class _InvestScreenState extends State<InvestScreen> {
  double _allocationPercentage = 10.0;
  double _purchaseSizePercentage = 10.0;
  bool _isLoading = false;

  void _invest() async {
    final walletState = context.read<WalletBloc>().state;
    if (walletState is! WalletLoaded) {
      _showError('Wallet not loaded');
      return;
    }

    final balance = walletState.wallet.balance;
    if (balance == 0) {
      _showError('Please top up your wallet first');
      return;
    }

    final allocatedAmount = balance * (_allocationPercentage / 100);
    if (allocatedAmount < 0.01) {
      _showError('Minimum investment is 0.01 SOL');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final firebaseService = context.read<FirebaseService>();
      final apiService = context.read<ApiService>();
      final user = firebaseService.getCurrentUser();

      if (user == null) {
        _showError('User not authenticated');
        return;
      }

      // Create investment record
      final investment = InvestmentModel(
        id: '',
        userId: user.uid,
        fundId: widget.fund.id,
        allocatedAmount: allocatedAmount,
        purchaseSizePercentage: _purchaseSizePercentage,
        currentValue: allocatedAmount,
        totalPnl: 0.0,
        investedAt: DateTime.now(),
        autoApprove: true,
      );

      await firebaseService.createInvestment(investment);
      
      // Subscribe to fund via backend (optional - non-blocking)
      // This enables copy-trading notifications when backend is running
      try {
        await apiService.subscribeToFund(user.uid, widget.fund.id, allocatedAmount, autoApprove: true);
      } catch (e) {
        // Backend not available - continue without it
        print('Backend subscription failed (optional): $e');
      }

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        _showSuccess();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.white, size: 20),
            SizedBox(width: 12),
            Text(
              'Success!',
              style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Text(
          'You\'ve successfully invested in ${widget.fund.name}. Your wallet will now copy all trades from this fund.',
          style: TextStyle(color: AppColors.gray),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to home
            },
            child: const Text(
              'Done',
              style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: const Text('Invest in Fund'),
      ),
      body: BlocBuilder<WalletBloc, WalletState>(
        builder: (context, state) {
          if (state is WalletLoaded) {
            final balance = state.wallet.balance;
            final allocatedAmount = balance * (_allocationPercentage / 100);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fund name
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.black,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Investing in',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.gray,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.fund.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppColors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Wallet balance
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.black,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Available Balance',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.white,
                          ),
                        ),
                        Text(
                          '${balance.toStringAsFixed(4)} SOL',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Allocation percentage
                  const Text(
                    'Allocation Amount',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'What percentage of your balance to allocate?',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.white.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.black,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Percentage',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.white,
                              ),
                            ),
                            Text(
                              '${_allocationPercentage.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: AppColors.white,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _allocationPercentage,
                          min: 1,
                          max: 100,
                          divisions: 99,
                          activeColor: AppColors.white,
                          inactiveColor: AppColors.border,
                          onChanged: (value) {
                            setState(() {
                              _allocationPercentage = value;
                            });
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Amount: ${allocatedAmount.toStringAsFixed(4)} SOL',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Purchase size percentage
                  const Text(
                    'Purchase Size Per Trade',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'What % of allocated amount to use per copy-trade?',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.white.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.black,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Per Trade',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.white,
                              ),
                            ),
                            Text(
                              '${_purchaseSizePercentage.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: AppColors.white,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _purchaseSizePercentage,
                          min: 1,
                          max: 100,
                          divisions: 99,
                          activeColor: AppColors.white,
                          inactiveColor: AppColors.border,
                          onChanged: (value) {
                            setState(() {
                              _purchaseSizePercentage = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            );
          }

          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.white,
              strokeWidth: 1.5,
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GlowContainer(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _invest,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.black,
                        ),
                      )
                    : const Text(
                        'Confirm Investment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
