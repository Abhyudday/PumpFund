import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/funds/funds_bloc.dart';
import '../../blocs/wallet/wallet_bloc.dart';
import '../../models/fund_model.dart';
import '../../utils/theme.dart';
import 'fund_details_screen.dart';
import '../wallet/wallet_management_screen.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    context.read<FundsBloc>().add(FundsLoadRequested());
    context.read<WalletBloc>().add(WalletLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: const Text(
          'pumpfunds',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined, size: 20),
            onPressed: () {
              context.read<FundsBloc>().add(FundsRefreshRequested());
              context.read<WalletBloc>().add(WalletRefreshRequested());
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<FundsBloc>().add(FundsRefreshRequested());
          context.read<WalletBloc>().add(WalletRefreshRequested());
        },
        color: AppColors.white,
        backgroundColor: AppColors.black,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Wallet balance card
              BlocBuilder<WalletBloc, WalletState>(
                builder: (context, state) {
                  if (state is WalletLoaded) {
                    return _buildWalletCard(state.wallet.balance, state.wallet.address);
                  }
                  return _buildWalletCardLoading();
                },
              ),
              
              const SizedBox(height: 24),
              
              // Section header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Available Funds',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.gray, width: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.gray,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Funds list
              BlocBuilder<FundsBloc, FundsState>(
                builder: (context, state) {
                  if (state is FundsLoading) {
                    return _buildFundsLoading();
                  }
                  
                  if (state is FundsLoaded) {
                    if (state.funds.isEmpty) {
                      return _buildEmptyState();
                    }
                    return Column(
                      children: state.funds
                          .map((fund) => _buildFundCard(fund))
                          .toList(),
                    );
                  }
                  
                  if (state is FundsError) {
                    return _buildErrorState(state.message);
                  }
                  
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletCard(double balance, String address) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<WalletBloc>(),
              child: const WalletManagementScreen(),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.black,
          border: Border.all(color: AppColors.border, width: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Wallet Balance',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.gray,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.gray, width: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Text(
                        'SOL',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.gray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.gray,
                      size: 12,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${balance.toStringAsFixed(4)} SOL',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${address.substring(0, 8)}...${address.substring(address.length - 8)}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.gray,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCardLoading() {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.black,
        border: Border.all(color: AppColors.border, width: 0.5),
        borderRadius: BorderRadius.circular(2),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppColors.white,
          strokeWidth: 1.5,
        ),
      ),
    );
  }

  Widget _buildFundCard(FundModel fund) {
    final roiColor = fund.roi7d >= 0 ? AppColors.white : AppColors.gray;
    final roiPrefix = fund.roi7d >= 0 ? '+' : '';
    
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FundDetailsScreen(fund: fund),
          ),
        );
      },
      child: Container(
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
            // Fund Image
            if (fund.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border, width: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Image.network(
                    fund.imageUrl,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 140,
                      color: AppColors.black,
                      child: const Center(
                        child: Icon(Icons.image_not_supported, color: AppColors.gray, size: 32),
                      ),
                    ),
                  ),
                ),
              ),
            if (fund.imageUrl.isNotEmpty) const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    fund.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                Text(
                  '$roiPrefix${fund.roi7d.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: roiColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              fund.description,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.gray,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoChip(
                  Icons.account_balance_wallet_outlined,
                  '${fund.walletAddresses.length} Wallets',
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  Icons.show_chart,
                  '7D ROI',
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FundDetailsScreen(fund: fund),
                    ),
                  );
                },
                child: const Text('Invest Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.gray, width: 0.5),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.gray),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.gray,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFundsLoading() {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          height: 180,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.black,
            border: Border.all(color: AppColors.border, width: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              color: AppColors.white,
              strokeWidth: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: const Column(
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 48,
            color: AppColors.gray,
          ),
          SizedBox(height: 16),
          Text(
            'No funds available yet',
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

  Widget _buildErrorState(String message) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.gray,
          ),
          const SizedBox(height: 16),
          Text(
            'Error: $message',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.gray,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
