import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart';
import 'blocs/wallet/wallet_bloc.dart';
import 'blocs/funds/funds_bloc.dart';
import 'blocs/portfolio/portfolio_bloc.dart';
import 'blocs/auth/auth_bloc.dart';
import 'services/wallet_service.dart';
import 'services/firebase_service.dart';
import 'services/api_service.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  debugPrint('Firebase initialized successfully');
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  // Lock portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const PumpFundsApp());
}

class PumpFundsApp extends StatelessWidget {
  const PumpFundsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (context) => WalletService()),
        RepositoryProvider(create: (context) => FirebaseService()),
        RepositoryProvider(create: (context) => ApiService()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthBloc(
              firebaseService: context.read<FirebaseService>(),
            ),
          ),
          BlocProvider(
            create: (context) => WalletBloc(
              walletService: context.read<WalletService>(),
            ),
          ),
          BlocProvider(
            create: (context) => FundsBloc(
              apiService: context.read<ApiService>(),
              firebaseService: context.read<FirebaseService>(),
            ),
          ),
          BlocProvider(
            create: (context) => PortfolioBloc(
              apiService: context.read<ApiService>(),
              firebaseService: context.read<FirebaseService>(),
              walletService: context.read<WalletService>(),
            ),
          ),
        ],
        child: MaterialApp(
          title: 'pumpfunds',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
