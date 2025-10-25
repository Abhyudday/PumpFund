import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/investment_model.dart';
import '../../models/transaction_model.dart';
import '../../services/api_service.dart';
import '../../services/firebase_service.dart';
import '../../services/wallet_service.dart';

// Events
abstract class PortfolioEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class PortfolioLoadRequested extends PortfolioEvent {
  final String userId;

  PortfolioLoadRequested(this.userId);

  @override
  List<Object?> get props => [userId];
}

class PortfolioRefreshRequested extends PortfolioEvent {}

// States
abstract class PortfolioState extends Equatable {
  @override
  List<Object?> get props => [];
}

class PortfolioInitial extends PortfolioState {}

class PortfolioLoading extends PortfolioState {}

class PortfolioLoaded extends PortfolioState {
  final List<InvestmentModel> investments;
  final List<TransactionModel> transactions;
  final double totalValue;
  final double totalPnl;

  PortfolioLoaded({
    required this.investments,
    required this.transactions,
    required this.totalValue,
    required this.totalPnl,
  });

  @override
  List<Object?> get props => [investments, transactions, totalValue, totalPnl];
}

class PortfolioError extends PortfolioState {
  final String message;

  PortfolioError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class PortfolioBloc extends Bloc<PortfolioEvent, PortfolioState> {
  final ApiService apiService;
  final FirebaseService firebaseService;
  final WalletService walletService;

  PortfolioBloc({
    required this.apiService,
    required this.firebaseService,
    required this.walletService,
  }) : super(PortfolioInitial()) {
    on<PortfolioLoadRequested>(_onPortfolioLoadRequested);
    on<PortfolioRefreshRequested>(_onPortfolioRefreshRequested);
  }

  Future<void> _onPortfolioLoadRequested(PortfolioLoadRequested event, Emitter<PortfolioState> emit) async {
    emit(PortfolioLoading());
    try {
      final investmentsStream = firebaseService.getUserInvestmentsStream(event.userId);
      final transactionsStream = firebaseService.getUserTransactionsStream(event.userId);

      List<TransactionModel> cachedTransactions = [];

      // Listen to transactions stream and cache them
      transactionsStream.listen((transactions) {
        cachedTransactions = transactions;
      });

      await emit.forEach(
        investmentsStream,
        onData: (List<InvestmentModel> investments) {
          // Calculate total allocated amount (initial investment)
          double totalAllocated = 0;
          for (final investment in investments) {
            totalAllocated += investment.allocatedAmount;
          }

          // Fetch and emit wallet balance asynchronously
          _updateWalletBalance(emit, investments, cachedTransactions, totalAllocated);

          // Return a temporary state that will be immediately updated
          return PortfolioLoaded(
            investments: investments,
            transactions: cachedTransactions,
            totalValue: 0,
            totalPnl: 0,
          );
        },
        onError: (error, stackTrace) => PortfolioError(error.toString()),
      );
    } catch (e) {
      emit(PortfolioError(e.toString()));
    }
  }

  Future<void> _updateWalletBalance(
    Emitter<PortfolioState> emit,
    List<InvestmentModel> investments,
    List<TransactionModel> transactions,
    double totalAllocated,
  ) async {
    try {
      final walletInfo = await walletService.getWalletInfo();
      final actualWalletBalance = walletInfo?.balance ?? 0;
      final totalPnl = actualWalletBalance - totalAllocated;

      emit(PortfolioLoaded(
        investments: investments,
        transactions: transactions,
        totalValue: actualWalletBalance,
        totalPnl: totalPnl,
      ));
    } catch (e) {
      print('Error fetching wallet balance: $e');
    }
  }

  Future<void> _onPortfolioRefreshRequested(PortfolioRefreshRequested event, Emitter<PortfolioState> emit) async {
    // Refresh portfolio data
    final currentState = state;
    if (currentState is PortfolioLoaded) {
      // Trigger refresh by re-emitting current state
      emit(currentState);
    }
  }
}
