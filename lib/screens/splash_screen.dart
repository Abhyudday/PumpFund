import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/wallet/wallet_bloc.dart';
import '../utils/theme.dart';
import 'auth/login_screen.dart';
import 'home/main_navigation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    _animationController.forward();
    
    // Check auth status after animation (short delay)
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      try {
        context.read<AuthBloc>().add(AuthCheckRequested());
      } catch (e) {
        debugPrint('Auth check error: $e');
        _navigateToLogin();
      }
    });
    
    // Fallback: Navigate to login after 3 seconds if no state change
    // Since Firebase is not initialized, this will be the main path
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (!_hasNavigated && mounted) {
        debugPrint('Splash timeout - navigating to login');
        _navigateToLogin();
      }
    });
  }
  
  void _navigateToLogin() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }
  
  void _navigateToHome() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigation()),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          // Restore wallet from Firestore when app starts with authenticated user
          context.read<WalletBloc>().add(WalletRestoreRequested(state.user.uid));
          _navigateToHome();
        } else if (state is AuthUnauthenticated) {
          _navigateToLogin();
        } else if (state is AuthError) {
          debugPrint('Auth error: ${state.message}');
          _navigateToLogin();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with glow effect
                GlowContainer(
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [AppColors.white, AppColors.gray]),
                    ),
                    child: const Icon(
                      Icons.rocket_launch,
                      size: 80,
                      color: AppColors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // App name
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(colors: [AppColors.white, AppColors.gray]).createShader(bounds),
                  child: const Text(
                    'pumpfunds',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Copy the best traders',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.white.withOpacity(0.7),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
