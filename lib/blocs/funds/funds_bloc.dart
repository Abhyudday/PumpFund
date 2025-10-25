import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/fund_model.dart';
import '../../services/api_service.dart';
import '../../services/firebase_service.dart';

// Events
abstract class FundsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class FundsLoadRequested extends FundsEvent {}

class FundsRefreshRequested extends FundsEvent {}

// States
abstract class FundsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class FundsInitial extends FundsState {}

class FundsLoading extends FundsState {}

class FundsLoaded extends FundsState {
  final List<FundModel> funds;

  FundsLoaded(this.funds);

  @override
  List<Object?> get props => [funds];
}

class FundsError extends FundsState {
  final String message;

  FundsError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class FundsBloc extends Bloc<FundsEvent, FundsState> {
  final ApiService apiService;
  final FirebaseService firebaseService;

  FundsBloc({
    required this.apiService,
    required this.firebaseService,
  }) : super(FundsInitial()) {
    on<FundsLoadRequested>(_onFundsLoadRequested);
    on<FundsRefreshRequested>(_onFundsRefreshRequested);
  }

  Future<void> _onFundsLoadRequested(FundsLoadRequested event, Emitter<FundsState> emit) async {
    emit(FundsLoading());
    try {
      final funds = await firebaseService.getFunds();
      emit(FundsLoaded(funds));
    } catch (e) {
      emit(FundsError(e.toString()));
    }
  }

  Future<void> _onFundsRefreshRequested(FundsRefreshRequested event, Emitter<FundsState> emit) async {
    // Refresh ROI for all funds
    try {
      final currentState = state;
      if (currentState is FundsLoaded) {
        for (final fund in currentState.funds) {
          final roi = await apiService.calculateFundRoi(fund.walletAddresses);
          await firebaseService.updateFundRoi(fund.id, roi);
        }
      }
    } catch (e) {
      // Silently fail refresh
    }
  }
}
