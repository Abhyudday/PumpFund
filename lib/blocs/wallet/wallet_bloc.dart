import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/wallet_model.dart';
import '../../services/wallet_service.dart';

// Events
abstract class WalletEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class WalletGenerateRequested extends WalletEvent {
  final String? userId;

  WalletGenerateRequested({this.userId});

  @override
  List<Object?> get props => [userId];
}

class WalletLoadRequested extends WalletEvent {}

class WalletRefreshRequested extends WalletEvent {}

class WalletImportRequested extends WalletEvent {
  final String mnemonic;

  WalletImportRequested(this.mnemonic);

  @override
  List<Object?> get props => [mnemonic];
}

class WalletClearRequested extends WalletEvent {}

class WalletPrivateKeyLoaded extends WalletEvent {
  final WalletModel wallet;

  WalletPrivateKeyLoaded(this.wallet);

  @override
  List<Object?> get props => [wallet];
}

class WalletRestoreRequested extends WalletEvent {
  final String userId;

  WalletRestoreRequested(this.userId);

  @override
  List<Object?> get props => [userId];
}

// States
abstract class WalletState extends Equatable {
  @override
  List<Object?> get props => [];
}

class WalletInitial extends WalletState {}

class WalletLoading extends WalletState {}

class WalletGenerated extends WalletState {
  final String address;
  final String mnemonic;

  WalletGenerated(this.address, this.mnemonic);

  @override
  List<Object?> get props => [address, mnemonic];
}

class WalletLoaded extends WalletState {
  final WalletModel wallet;

  WalletLoaded(this.wallet);

  @override
  List<Object?> get props => [wallet];
}

class WalletEmpty extends WalletState {}

class WalletError extends WalletState {
  final String message;

  WalletError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class WalletBloc extends Bloc<WalletEvent, WalletState> {
  final WalletService walletService;

  WalletBloc({required this.walletService}) : super(WalletInitial()) {
    on<WalletGenerateRequested>(_onWalletGenerateRequested);
    on<WalletLoadRequested>(_onWalletLoadRequested);
    on<WalletRefreshRequested>(_onWalletRefreshRequested);
    on<WalletImportRequested>(_onWalletImportRequested);
    on<WalletClearRequested>(_onWalletClearRequested);
    on<WalletPrivateKeyLoaded>(_onWalletPrivateKeyLoaded);
    on<WalletRestoreRequested>(_onWalletRestoreRequested);
  }

  Future<void> _onWalletGenerateRequested(WalletGenerateRequested event, Emitter<WalletState> emit) async {
    emit(WalletLoading());
    try {
      final result = await walletService.generateWallet(userId: event.userId);
      emit(WalletGenerated(result['address']!, result['mnemonic']!));
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  Future<void> _onWalletLoadRequested(WalletLoadRequested event, Emitter<WalletState> emit) async {
    emit(WalletLoading());
    try {
      final hasWallet = await walletService.hasWallet();
      if (!hasWallet) {
        emit(WalletEmpty());
        return;
      }

      final wallet = await walletService.getWalletInfo();
      if (wallet != null) {
        emit(WalletLoaded(wallet));
      } else {
        emit(WalletEmpty());
      }
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  Future<void> _onWalletRefreshRequested(WalletRefreshRequested event, Emitter<WalletState> emit) async {
    try {
      // Load wallet with private key if current state has it
      bool includePrivateKey = false;
      if (state is WalletLoaded) {
        includePrivateKey = (state as WalletLoaded).wallet.privateKey != null;
      }
      
      final wallet = await walletService.getWalletInfo(includePrivateKey: includePrivateKey);
      if (wallet != null) {
        emit(WalletLoaded(wallet));
      }
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  Future<void> _onWalletImportRequested(WalletImportRequested event, Emitter<WalletState> emit) async {
    emit(WalletLoading());
    try {
      final address = await walletService.importWallet(event.mnemonic);
      final wallet = await walletService.getWalletInfo();
      if (wallet != null) {
        emit(WalletLoaded(wallet));
      }
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  Future<void> _onWalletClearRequested(WalletClearRequested event, Emitter<WalletState> emit) async {
    await walletService.clearWallet();
    emit(WalletEmpty());
  }

  Future<void> _onWalletPrivateKeyLoaded(WalletPrivateKeyLoaded event, Emitter<WalletState> emit) async {
    emit(WalletLoaded(event.wallet));
  }

  Future<void> _onWalletRestoreRequested(WalletRestoreRequested event, Emitter<WalletState> emit) async {
    print('🔄 WalletBloc: Wallet restore requested for user: ${event.userId}');
    emit(WalletLoading());
    try {
      // Try to restore wallet from Firestore
      print('📡 WalletBloc: Calling restoreWalletFromFirestore...');
      final restored = await walletService.restoreWalletFromFirestore(event.userId);
      print('📊 WalletBloc: Restore result: $restored');
      
      if (restored) {
        // Load the restored wallet immediately (without waiting for balance)
        print('📥 WalletBloc: Loading wallet info...');
        final wallet = await walletService.getWalletInfo();
        if (wallet != null) {
          print('✅ WalletBloc: Wallet loaded successfully - Address: ${wallet.address}');
          emit(WalletLoaded(wallet));
          
          // Re-encrypt in background (non-blocking)
          walletService.reEncryptWalletForBackend(event.userId).catchError((e) {
            print('⚠️  WalletBloc: Re-encryption warning: $e');
          });
        } else {
          print('❌ WalletBloc: getWalletInfo returned null');
          emit(WalletEmpty());
        }
      } else {
        // No wallet found in Firestore
        print('❌ WalletBloc: No wallet found in Firestore');
        emit(WalletEmpty());
      }
    } catch (e) {
      print('❌ WalletBloc: Error during wallet restore: $e');
      emit(WalletError(e.toString()));
    }
  }
}
