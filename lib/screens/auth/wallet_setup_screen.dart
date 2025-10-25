import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../blocs/wallet/wallet_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../utils/theme.dart';
import '../home/main_navigation.dart';

class WalletSetupScreen extends StatefulWidget {
  const WalletSetupScreen({super.key});

  @override
  State<WalletSetupScreen> createState() => _WalletSetupScreenState();
}

class _WalletSetupScreenState extends State<WalletSetupScreen> {
  bool _mnemonicSaved = false;
  String? _generatedAddress;
  String? _generatedMnemonic;
  bool _isGenerating = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Generate wallet on screen load with user ID
    final authState = context.read<AuthBloc>().state;
    String? userId;
    if (authState is AuthAuthenticated) {
      userId = authState.user.uid;
    }
    context.read<WalletBloc>().add(WalletGenerateRequested(userId: userId));
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: AppColors.white,
      ),
    );
  }

  void _confirmAndContinue() {
    if (!_mnemonicSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please confirm you have saved your recovery phrase'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigation()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: const Text('Wallet Setup'),
      ),
      body: BlocListener<WalletBloc, WalletState>(
        listener: (context, state) {
          // Capture wallet data once generated and stop listening to subsequent changes
          if (state is WalletGenerated && _generatedAddress == null) {
            setState(() {
              _generatedAddress = state.address;
              _generatedMnemonic = state.mnemonic;
              _isGenerating = false;
              _errorMessage = null;
            });
          } else if (state is WalletError && _generatedAddress == null) {
            setState(() {
              _errorMessage = state.message;
              _isGenerating = false;
            });
          }
        },
        child: Builder(
          builder: (context) {
            // Show loading state
            if (_isGenerating) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.white),
              );
            }

            // Show error state only if wallet wasn't generated
            if (_errorMessage != null && _generatedAddress == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 60),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isGenerating = true;
                          _errorMessage = null;
                        });
                        final authState = context.read<AuthBloc>().state;
                        String? userId;
                        if (authState is AuthAuthenticated) {
                          userId = authState.user.uid;
                        }
                        context.read<WalletBloc>().add(WalletGenerateRequested(userId: userId));
                      },
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              );
            }

            // Show wallet generated UI (using captured data)
            if (_generatedAddress != null && _generatedMnemonic != null) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    const Icon(
                      Icons.account_balance_wallet,
                      size: 60,
                      color: AppColors.white,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your Wallet is Ready!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Save your recovery phrase and address',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.white.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    
                    // QR Code
                    GlowContainer(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.black,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.white),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: QrImageView(
                                data: _generatedAddress!,
                                version: QrVersions.auto,
                                size: 200.0,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Wallet Address',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_generatedAddress!.substring(0, 8)}...${_generatedAddress!.substring(_generatedAddress!.length - 8)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, color: AppColors.white, size: 20),
                                  onPressed: () => _copyToClipboard(_generatedAddress!, 'Address'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Recovery Phrase
                    GlowContainer(
                      glowColor: Colors.red,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.black,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning, color: Colors.red, size: 24),
                                const SizedBox(width: 8),
                                const Text(
                                  'Recovery Phrase',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Save this phrase in a secure location. You will need it to recover your wallet.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.white.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.black,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: SelectableText(
                                _generatedMnemonic!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.white,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => _copyToClipboard(_generatedMnemonic!, 'Recovery phrase'),
                              icon: const Icon(Icons.copy),
                              label: const Text('Copy Phrase'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: AppColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Confirmation checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: _mnemonicSaved,
                          onChanged: (value) {
                            setState(() {
                              _mnemonicSaved = value ?? false;
                            });
                          },
                          activeColor: AppColors.white,
                        ),
                        Expanded(
                          child: Text(
                            'I have saved my recovery phrase securely',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.white.withOpacity(0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Continue button
                    GlowContainer(
                      child: ElevatedButton(
                        onPressed: _confirmAndContinue,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Continue to App',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '💡 Next Steps:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '1. Transfer SOL/USDC to this address\n'
                            '2. Browse and invest in curated funds\n'
                            '3. Your wallet will auto-copy fund trades',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.white.withOpacity(0.8),
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

            // Fallback (should not reach here)
            return const Center(
              child: CircularProgressIndicator(color: AppColors.white),
            );
          },
        ),
      ),
    );
  }
}
