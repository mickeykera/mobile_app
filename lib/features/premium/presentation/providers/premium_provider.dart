import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'premium_provider.freezed.dart';

@freezed
abstract class PremiumState with _$PremiumState {
  const factory PremiumState({
    @Default(false) bool isPremium,
    @Default('free') String planType,
    DateTime? premiumSince,
    @Default('monthly') String billingCycle,
  }) = _PremiumState;
}

class PremiumController extends StateNotifier<PremiumState> {
  PremiumController() : super(const PremiumState()) {
    _loadPremiumStatus();
  }

  Future<void> _loadPremiumStatus() async {
    // In a real app, this would load from secure storage or backend
    // For now, we'll simulate a free user
    state = state.copyWith(isPremium: false, planType: 'free');
  }

  Future<void> upgradeToPremium({String billingCycle = 'monthly'}) async {
    // In a real app, this would process the purchase through the platform's billing system
    // For demo purposes, we'll simulate a successful upgrade
    state = state.copyWith(
      isPremium: true,
      planType: 'premium',
      premiumSince: DateTime.now(),
      billingCycle: billingCycle,
    );
  }

  Future<void> downgradeToFree() async {
    // In a real app, this would cancel the subscription
    state = state.copyWith(
      isPremium: false,
      planType: 'free',
      premiumSince: null,
    );
  }

  void restorePurchases() {
    // In a real app, this would restore from the platform's billing system
    state = state.copyWith(
      isPremium: true,
      planType: 'premium',
      premiumSince: DateTime.now().subtract(const Duration(days: 30)),
    );
  }
}

final premiumProvider =
    StateNotifierProvider<PremiumController, PremiumState>((ref) {
  return PremiumController();
});

final isPremiumProvider = Provider<bool>((ref) {
  return ref.watch(premiumProvider).isPremium;
});

final premiumPlanProvider = Provider<String>((ref) {
  return ref.watch(premiumProvider).planType;
});
