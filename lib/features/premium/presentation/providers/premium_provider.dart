import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/app_clock.dart';
import '../../../../core/database/database.dart';

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
  final DatabaseService _database;

  PremiumController(this._database) : super(const PremiumState()) {
    _loadPremiumStatus();
  }

  static const _premiumKey = 'premium_status';

  Future<void> _loadPremiumStatus() async {
    final isPremium = _database.getBool(_premiumKey) ?? false;
    final planType = _database.getString('premium_plan') ?? 'free';
    final premiumSinceStr = _database.getString('premium_since');
    final billingCycle = _database.getString('premium_cycle') ?? 'monthly';
    DateTime? premiumSince;
    if (premiumSinceStr != null) {
      premiumSince = DateTime.tryParse(premiumSinceStr);
    }
    state = state.copyWith(
      isPremium: isPremium,
      planType: planType,
      premiumSince: premiumSince,
      billingCycle: billingCycle,
    );
  }

  Future<void> _savePremiumStatus() async {
    await _database.setBool(_premiumKey, state.isPremium);
    await _database.setString('premium_plan', state.planType);
    if (state.premiumSince != null) {
      await _database.setString('premium_since', state.premiumSince!.toIso8601String());
    } else {
      await _database.remove('premium_since');
    }
    await _database.setString('premium_cycle', state.billingCycle);
  }

  Future<void> upgradeToPremium({String billingCycle = 'monthly'}) async {
    state = state.copyWith(
      isPremium: true,
      planType: 'premium',
      premiumSince: AppClock.now(),
      billingCycle: billingCycle,
    );
    await _savePremiumStatus();
  }

  Future<void> downgradeToFree() async {
    state = state.copyWith(
      isPremium: false,
      planType: 'free',
      premiumSince: null,
    );
    await _savePremiumStatus();
  }

  void restorePurchases() {
    state = state.copyWith(
      isPremium: true,
      planType: 'premium',
      premiumSince: AppClock.now().subtract(const Duration(days: 30)),
    );
    _savePremiumStatus();
  }
}

final premiumProvider =
    StateNotifierProvider<PremiumController, PremiumState>((ref) {
  return PremiumController(ref.watch(databaseServiceProvider));
});

final isPremiumProvider = Provider<bool>((ref) {
  return ref.watch(premiumProvider).isPremium;
});

final premiumPlanProvider = Provider<String>((ref) {
  return ref.watch(premiumProvider).planType;
});
