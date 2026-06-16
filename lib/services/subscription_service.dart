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

  void updateSubscriptionState(String plan, bool active, {bool enableCelebration = false}) {
    final String oldPlan = planNotifier.value.toLowerCase();
    final bool oldActive = activeNotifier.value;

    // Trigger celebration when transitioning from a non-pro plan (like 'free') to Pro or HLG
    // We compute this BEFORE updating the notifiers to avoid race conditions with synchronous listeners
    if (enableCelebration && active && (plan.toLowerCase() == 'pro' || plan.toLowerCase() == 'hlg')) {
      final bool wasPro = oldActive && (oldPlan == 'pro' || oldPlan == 'hlg');
      if (!wasPro) {
        celebrationPending = true;
      }
    }

    planNotifier.value = plan;
    activeNotifier.value = active;

    // Guardar en caché local para mantener la persistencia al día
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('navimap_cached_plan', plan);
      prefs.setBool('navimap_cached_active', active);
    }).catchError((e) {
      debugPrint('Error al actualizar cache de suscripción: $e');
    });
  }
}
