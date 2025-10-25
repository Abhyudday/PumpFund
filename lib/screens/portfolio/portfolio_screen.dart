import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/portfolio/portfolio_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../utils/theme.dart';
import '../../models/investment_model.dart';
import '../../models/transaction_model.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<PortfolioBloc>().add(PortfolioLoadRequested(authState.user.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: const Text('Portfolio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<PortfolioBloc>().add(PortfolioRefreshRequested());
            },
          ),
        ],
      ),
      body: BlocBuilder<PortfolioBloc, PortfolioState>(
        builder: (context, state) {
          if (state is PortfolioLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.white,
                strokeWidth: 1.5,
              ),
            );
          }

          if (state is PortfolioLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<PortfolioBloc>().add(PortfolioRefreshRequested());
              },
              color: AppColors.white,
              backgroundColor: AppColors.black,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total value card
                    _buildTotalValueCard(state.totalValue, state.totalPnl),
                    
                    const SizedBox(height: 24),
                    
                    // Investments section
                    const Text(
                      'Active Investments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    if (state.investments.isEmpty)
                      _buildEmptyInvestments()
                    else
                      ...state.investments.map((investment) => _buildInvestmentCard(investment)),
                    
                    const SizedBox(height: 24),
                    
                    // Recent transactions
                    const Text(
                      'Recent Transactions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    if (state.transactions.isEmpty)
                      _buildEmptyTransactions()
                    else
                      ...state.transactions.take(10).map((tx) => _buildTransactionItem(tx)),
                  ],
                ),
              ),
            );
          }

          if (state is PortfolioError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${state.message}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildTotalValueCard(double totalValue, double totalPnl) {
    final pnlColor = totalPnl >= 0 ? AppColors.white : AppColors.gray;
    final pnlPrefix = totalPnl >= 0 ? '+' : '';
    final pnlPercentage = totalValue > 0 ? (totalPnl / totalValue) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.black,
        border: Border.all(color: AppColors.border, width: 0.5),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Portfolio Value',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.gray,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${totalValue.toStringAsFixed(4)} SOL',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '$pnlPrefix${totalPnl.toStringAsFixed(4)} SOL',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: pnlColor,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '$pnlPrefix${pnlPercentage.toStringAsFixed(2)}%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: pnlColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentCard(InvestmentModel investment) {
    final pnlColor = investment.totalPnl >= 0 ? AppColors.white : AppColors.gray;
    final pnlPrefix = investment.totalPnl >= 0 ? '+' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Fund Investment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: investment.isActive ? AppColors.white.withOpacity(0.1) : AppColors.gray.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                        color: investment.isActive ? AppColors.white.withOpacity(0.3) : AppColors.gray.withOpacity(0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      investment.isActive ? 'Active' : 'Disabled',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: investment.isActive ? AppColors.white : AppColors.gray,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '$pnlPrefix${investment.totalPnl.toStringAsFixed(2)} SOL',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: pnlColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _showManageInvestmentDialog(investment),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border, width: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Icon(
                        Icons.settings,
                        size: 16,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInvestmentRow('Allocated', '${investment.allocatedAmount.toStringAsFixed(4)} SOL'),
          const SizedBox(height: 8),
          _buildInvestmentRow('Current Value', '${investment.currentValue.toStringAsFixed(4)} SOL'),
          const SizedBox(height: 8),
          _buildInvestmentRow('Purchase Size', '${investment.purchaseSizePercentage.toStringAsFixed(0)}%'),
          const SizedBox(height: 8),
          _buildInvestmentRow('Auto-Approve', investment.autoApprove ? 'Enabled' : 'Disabled'),
        ],
      ),
    );
  }

  Widget _buildInvestmentRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.gray,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyInvestments() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: const Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 48,
            color: AppColors.gray,
          ),
          SizedBox(height: 16),
          Text(
            'No active investments',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.gray,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Invest in a fund to start copy-trading',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.gray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(TransactionModel transaction) {
    final isBuy = transaction.type == TransactionType.buy;
    final typeColor = isBuy ? AppColors.white : AppColors.gray;
    final typeIcon = isBuy ? Icons.arrow_upward : Icons.arrow_downward;
    final dateFormat = DateFormat('MMM dd, HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border, width: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Icon(typeIcon, color: typeColor, size: 16),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBuy ? 'Bought' : 'Sold',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  transaction.tokenSymbol,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.gray,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateFormat.format(transaction.timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.gray,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${transaction.amount.toStringAsFixed(2)} ${transaction.tokenSymbol}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${transaction.totalValue.toStringAsFixed(4)} SOL',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.gray,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTransactions() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: const Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: AppColors.gray,
          ),
          SizedBox(height: 16),
          Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.gray,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showManageInvestmentDialog(InvestmentModel investment) {
    final allocatedController = TextEditingController(
      text: investment.allocatedAmount.toStringAsFixed(4),
    );
    final purchaseSizeController = TextEditingController(
      text: investment.purchaseSizePercentage.toStringAsFixed(0),
    );
    bool autoApprove = investment.autoApprove;
    bool isActive = investment.isActive;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
            side: const BorderSide(color: AppColors.border, width: 0.5),
          ),
          title: const Text(
            'Manage Investment',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Allocated Amount (SOL)',
                  style: TextStyle(
                    color: AppColors.gray,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: allocatedController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppColors.white),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                      borderSide: const BorderSide(color: AppColors.border, width: 0.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                      borderSide: const BorderSide(color: AppColors.border, width: 0.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                      borderSide: const BorderSide(color: AppColors.white, width: 1),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Purchase Size (%)',
                  style: TextStyle(
                    color: AppColors.gray,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: purchaseSizeController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.white),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                      borderSide: const BorderSide(color: AppColors.border, width: 0.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                      borderSide: const BorderSide(color: AppColors.border, width: 0.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                      borderSide: const BorderSide(color: AppColors.white, width: 1),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Investment Active',
                      style: TextStyle(
                        color: AppColors.gray,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Switch(
                      value: isActive,
                      onChanged: (value) {
                        setState(() {
                          isActive = value;
                        });
                      },
                      activeColor: AppColors.white,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Auto-Approve Trades',
                      style: TextStyle(
                        color: AppColors.gray,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Switch(
                      value: autoApprove,
                      onChanged: (value) {
                        setState(() {
                          autoApprove = value;
                        });
                      },
                      activeColor: AppColors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.gray),
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final authState = context.read<AuthBloc>().state;
                  if (authState is! AuthAuthenticated) return;

                  final allocatedAmount = double.tryParse(allocatedController.text);
                  final purchaseSizePercentage = double.tryParse(purchaseSizeController.text);

                  if (allocatedAmount == null || purchaseSizePercentage == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid input')),
                    );
                    return;
                  }

                  if (purchaseSizePercentage < 1 || purchaseSizePercentage > 100) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Purchase size must be between 1-100%')),
                    );
                    return;
                  }

                  final apiService = ApiService();
                  await apiService.updateInvestment(
                    userId: authState.user.uid,
                    fundId: investment.fundId,
                    allocatedAmount: allocatedAmount,
                    purchaseSizePercentage: purchaseSizePercentage,
                    autoApprove: autoApprove,
                    isActive: isActive,
                  );

                  if (context.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Investment settings updated')),
                    );
                    context.read<PortfolioBloc>().add(PortfolioRefreshRequested());
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text(
                'Save',
                style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
