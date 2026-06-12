import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final ValueNotifier<String> planNotifier = ValueNotifier<String>('free');
  final ValueNotifier<bool> activeNotifier = ValueNotifier<bool>(false);

  String get currentPlan => planNotifier.value;
  bool get isPro => planNotifier.value.toLowerCase() == 'pro' || planNotifier.value.toLowerCase() == 'hlg';
  bool get isActive => activeNotifier.value;

  Future<void> loadSavedSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    final String savedPlan = prefs.getString('navimap_cached_plan') ?? 'free';
    final bool savedActive = prefs.getBool('navimap_cached_active') ?? false;

    planNotifier.value = savedPlan;
    activeNotifier.value = savedActive;
  }

  bool celebrationPending = false;

  void updateSubscriptionState(String plan, bool active) {
    final String oldPlan = planNotifier.value.toLowerCase();
    final bool oldActive = activeNotifier.value;

    planNotifier.value = plan;
    activeNotifier.value = active;

    // Trigger celebration when transitioning from non-active or a different plan to Pro or HLG
    if (active && (plan.toLowerCase() == 'pro' || plan.toLowerCase() == 'hlg')) {
      if (!oldActive || oldPlan != plan.toLowerCase()) {
        celebrationPending = true;
      }
    }
  }
}
