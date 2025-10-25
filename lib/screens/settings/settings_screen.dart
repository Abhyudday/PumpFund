import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/wallet/wallet_bloc.dart';
import '../../utils/theme.dart';
import '../auth/login_screen.dart';
import '../wallet/wallet_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _autoApproveByDefault = false;
  double _defaultPurchaseSize = 10.0;

  void _showMnemonic() {
    showDialog(
      context: context,
      builder: (context) => BlocBuilder<WalletBloc, WalletState>(
        builder: (context, state) {
          return AlertDialog(
            backgroundColor: AppColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
              side: const BorderSide(color: AppColors.border, width: 0.5),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 12),
                Text(
                  'Recovery Phrase',
                  style: TextStyle(color: AppColors.white),
                ),
              ],
            ),
            content: FutureBuilder<String?>(
              future: context.read<WalletBloc>().walletService.getMnemonic(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Keep this phrase safe and private. Anyone with this phrase can access your wallet.',
                        style: const TextStyle(
                          color: AppColors.gray,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.black,
                          border: Border.all(color: AppColors.border, width: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: SelectableText(
                          snapshot.data!,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: snapshot.data!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Recovery phrase copied'),
                              backgroundColor: AppColors.white,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy Phrase'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gray,
                          foregroundColor: AppColors.white,
                        ),
                      ),
                    ],
                  );
                }
                return const CircularProgressIndicator(
                  color: AppColors.white,
                  strokeWidth: 1.5,
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: AppColors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        title: const Text(
          'Logout',
          style: TextStyle(color: AppColors.white),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: AppColors.gray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.white)),
          ),
          TextButton(
            onPressed: () {
              context.read<AuthBloc>().add(AuthSignOutRequested());
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Logout', style: TextStyle(color: AppColors.gray)),
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
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wallet Section
            const Text(
              'Wallet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            
            BlocBuilder<WalletBloc, WalletState>(
              builder: (context, state) {
                if (state is WalletLoaded) {
                  return _buildWalletCard(state.wallet.address);
                }
                return const SizedBox.shrink();
              },
            ),
            
            const SizedBox(height: 12),
            
            _buildSettingsTile(
              'Manage Wallet',
              'Top up, withdraw, and view private key',
              Icons.account_balance_wallet,
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
            ),
            
            const SizedBox(height: 12),
            
            _buildSettingsTile(
              'Recovery Phrase',
              'View your wallet recovery phrase',
              Icons.vpn_key,
              onTap: _showMnemonic,
            ),
            
            const SizedBox(height: 32),
            
            // Trading Preferences
            const Text(
              'Trading Preferences',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
                letterSpacing: -0.5,
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
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Auto-Approve Trades',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Enable by default for new investments',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.gray,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _autoApproveByDefault,
                        onChanged: (value) {
                          setState(() {
                            _autoApproveByDefault = value;
                          });
                        },
                        activeColor: AppColors.white,
                        inactiveThumbColor: AppColors.gray,
                        inactiveTrackColor: AppColors.border,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: AppColors.divider, height: 1),
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Default Purchase Size',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Default percentage per trade: ${_defaultPurchaseSize.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.gray,
                        ),
                      ),
                      Slider(
                        value: _defaultPurchaseSize,
                        min: 1,
                        max: 100,
                        divisions: 99,
                        activeColor: AppColors.white,
                        inactiveColor: AppColors.border,
                        onChanged: (value) {
                          setState(() {
                            _defaultPurchaseSize = value;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Notifications
            const Text(
              'Notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
                letterSpacing: -0.5,
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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Push Notifications',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Get notified about new trades',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.gray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                    },
                    activeColor: AppColors.white,
                    inactiveThumbColor: AppColors.gray,
                    inactiveTrackColor: AppColors.border,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // About
            const Text(
              'About',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildSettingsTile(
              'Terms of Service',
              'Read our terms and conditions',
              Icons.description,
              onTap: () {},
            ),
            const SizedBox(height: 12),
            _buildSettingsTile(
              'Privacy Policy',
              'How we handle your data',
              Icons.privacy_tip,
              onTap: () {},
            ),
            const SizedBox(height: 12),
            _buildSettingsTile(
              'Version',
              'v1.0.0',
              Icons.info,
            ),
            
            const SizedBox(height: 32),
            
            // Logout button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gray,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard(String address) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.black,
        border: Border.all(color: AppColors.border, width: 0.5),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined, color: AppColors.white, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wallet Address',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.gray,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${address.substring(0, 8)}...${address.substring(address.length - 8)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: AppColors.white, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: address));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Address copied'),
                  backgroundColor: AppColors.white,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(String title, String subtitle, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border, width: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Icon(icon, color: AppColors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.gray,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.arrow_forward_ios, color: AppColors.gray, size: 14),
          ],
        ),
      ),
    );
  }
}
