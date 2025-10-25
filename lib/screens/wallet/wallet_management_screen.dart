import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../blocs/wallet/wallet_bloc.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';

class WalletManagementScreen extends StatefulWidget {
  const WalletManagementScreen({super.key});

  @override
  State<WalletManagementScreen> createState() => _WalletManagementScreenState();
}

class _WalletManagementScreenState extends State<WalletManagementScreen> {
  bool _showPrivateKey = false;
  final _amountController = TextEditingController();
  List<Map<String, dynamic>> _tokenHoldings = [];
  bool _loadingTokens = false;

  @override
  void initState() {
    super.initState();
    _loadTokenHoldings();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadTokenHoldings() async {
    setState(() {
      _loadingTokens = true;
    });

    final walletState = context.read<WalletBloc>().state;
    if (walletState is WalletLoaded) {
      final apiService = ApiService();
      final tokens = await apiService.getTokenAccounts(walletState.wallet.address);
      if (mounted) {
        setState(() {
          _tokenHoldings = tokens;
          _loadingTokens = false;
        });
      }
    } else {
      setState(() {
        _loadingTokens = false;
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: AppColors.white,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showTopUpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.black,
        title: const Text(
          'Top Up Wallet',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Send SOL to your wallet address to top up:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            BlocBuilder<WalletBloc, WalletState>(
              builder: (context, state) {
                if (state is WalletLoaded) {
                  return Column(
                    children: [
                      QrImageView(
                        data: state.wallet.address,
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.black,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          state.wallet.address,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return const CircularProgressIndicator();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppColors.white)),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.black,
        title: const Text(
          'Withdraw SOL',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Amount (SOL)',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Recipient Address',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.white),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement withdrawal logic
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Withdrawal feature coming soon!'),
                  backgroundColor: AppColors.gray,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.white,
            ),
            child: const Text('Withdraw', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showPrivateKeyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.black,
        title: Row(
          children: [
            const Icon(Icons.warning, color: AppColors.gray),
            const SizedBox(width: 8),
            const Text(
              'Private Key',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: BlocBuilder<WalletBloc, WalletState>(
          builder: (context, state) {
            if (state is WalletLoaded) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚠️ Never share your private key with anyone!',
                    style: TextStyle(
                      color: AppColors.gray,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Anyone with your private key can access your funds.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  if (_showPrivateKey) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.black,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.gray),
                      ),
                      child: SelectableText(
                        state.wallet.privateKey ?? 'Not available',
                        style: const TextStyle(
                          color: AppColors.gray,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _copyToClipboard(
                            state.wallet.privateKey ?? '',
                            'Private key',
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy Private Key'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gray,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // Reload wallet with private key
                          final walletService = context.read<WalletBloc>().walletService;
                          final walletWithKey = await walletService.getWalletInfo(includePrivateKey: true);
                          
                          if (walletWithKey != null && mounted) {
                            setState(() {
                              _showPrivateKey = true;
                            });
                            // Update the bloc state with private key included
                            context.read<WalletBloc>().add(WalletPrivateKeyLoaded(walletWithKey));
                          }
                        },
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text('Reveal Private Key'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gray,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            }
            return const CircularProgressIndicator();
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _showPrivateKey = false;
              });
              Navigator.pop(context);
            },
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
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
        backgroundColor: AppColors.black,
        title: const Text('Manage Wallet'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<WalletBloc, WalletState>(
        builder: (context, state) {
          if (state is WalletLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is WalletLoaded) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Wallet Balance Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.white.withOpacity(0.2),
                          AppColors.gray.withOpacity(0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.white.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Total Balance',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${state.wallet.balance.toStringAsFixed(4)} SOL',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${(state.wallet.balance * 150).toStringAsFixed(2)} USD',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Wallet Address
                  const Text(
                    'Wallet Address',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            state.wallet.address,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: AppColors.white),
                          onPressed: () => _copyToClipboard(
                            state.wallet.address,
                            'Address',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.add_circle_outline,
                          label: 'Top Up',
                          color: AppColors.white,
                          onTap: _showTopUpDialog,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.remove_circle_outline,
                          label: 'Withdraw',
                          color: AppColors.gray,
                          onTap: _showWithdrawDialog,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: _ActionButton(
                      icon: Icons.vpn_key,
                      label: 'Reveal Private Key',
                      color: AppColors.gray,
                      onTap: _showPrivateKeyDialog,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Token Holdings Section
                  const Text(
                    'Token Holdings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_loadingTokens)
                    const Center(
                      child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 1.5),
                    )
                  else if (_tokenHoldings.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      child: const Center(
                        child: Text(
                          'No tokens found',
                          style: TextStyle(color: AppColors.gray, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    ..._tokenHoldings.map((token) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border, width: 0.5),
                            ),
                            child: const Icon(Icons.toll, color: AppColors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${token['mint'].toString().substring(0, 8)}...${token['mint'].toString().substring(token['mint'].toString().length - 8)}',
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Token',
                                  style: TextStyle(
                                    color: AppColors.gray.withOpacity(0.7),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                token['amount'].toStringAsFixed(2),
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Balance',
                                style: TextStyle(
                                  color: AppColors.gray.withOpacity(0.7),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )),

                  const SizedBox(height: 32),

                  // Security Notice
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.gray.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.gray.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.security,
                          color: AppColors.gray,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Security Notice',
                                style: TextStyle(
                                  color: AppColors.gray,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your private key is encrypted and stored securely. Never share it with anyone.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.account_balance_wallet,
                  size: 64,
                  color: Colors.white30,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No wallet found',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    context.read<WalletBloc>().add(WalletLoadRequested());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.white,
                  ),
                  child: const Text(
                    'Reload Wallet',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
