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

    // Check if we should celebrate this plan (if it's pro/hlg and has never been celebrated on this device)
    if (savedActive && (savedPlan.toLowerCase() == 'pro' || savedPlan.toLowerCase() == 'hlg')) {
      final key = 'navimap_celebrated_${savedPlan.toLowerCase()}';
      final celebrated = prefs.getBool(key) ?? false;
      if (!celebrated) {
        celebrationPending = true;
      }
    }
  }

  bool celebrationPending = false;

  void updateSubscriptionState(String plan, bool active) async {
    final String oldPlan = planNotifier.value;
    final bool oldActive = activeNotifier.value;

    planNotifier.value = plan;
    activeNotifier.value = active;

    if (active && (plan.toLowerCase() == 'pro' || plan.toLowerCase() == 'hlg')) {
      final prefs = await SharedPreferences.getInstance();
      final key = 'navimap_celebrated_${plan.toLowerCase()}';
      final celebrated = prefs.getBool(key) ?? false;

      if (!celebrated || !oldActive || oldPlan == 'free') {
        celebrationPending = true;
        await prefs.setBool(key, true);

        // Reset the other plan's celebrated flag so if they switch plans they see the new celebration
        if (plan.toLowerCase() == 'pro') {
          await prefs.remove('navimap_celebrated_hlg');
        } else if (plan.toLowerCase() == 'hlg') {
          await prefs.remove('navimap_celebrated_pro');
        }
      }
    } else if (plan == 'free' || !active) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('navimap_celebrated_pro');
      await prefs.remove('navimap_celebrated_hlg');
    }
  }
}
