import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'subscription_service.dart';

class BillingService {
  static final BillingService _instance = BillingService._internal();
  factory BillingService() => _instance;
  BillingService._internal();

  // Evaluado de forma perezosa para evitar crashes en plataformas que no lo soportan (como la Web)
  InAppPurchase? get _iap => kIsWeb ? null : InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  // IDs de la suscripción en Google Play Console
  static const String subscriptionMonthlyId = 'navimap_pro_monthly';
  static const String subscriptionYearlyId = 'navimap_pro_yearly';
  static const String subscriptionId = subscriptionMonthlyId; // Por compatibilidad

  final ValueNotifier<bool> isStoreAvailable = ValueNotifier<bool>(false);
  final ValueNotifier<ProductDetails?> proProduct = ValueNotifier<ProductDetails?>(null);
  final ValueNotifier<List<ProductDetails>> productsList = ValueNotifier<List<ProductDetails>>([]);
  final ValueNotifier<bool> isPurchasePending = ValueNotifier<bool>(false);

  void initialize() async {
    if (kIsWeb) {
      isStoreAvailable.value = false;
      return;
    }

    // Escuchar actualizaciones de compra
    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap!.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onError: (error) {
        debugPrint('Error en el stream de compras: $error');
        isPurchasePending.value = false;
      },
    );

    // Verificar disponibilidad de la tienda
    try {
      final bool available = await _iap!.isAvailable();
      isStoreAvailable.value = available;
      if (available) {
        await queryProducts();
      }
    } catch (e) {
      debugPrint('Error inicializando facturación de Google Play: $e');
    }
  }

  void dispose() {
    _subscription?.cancel();
  }

  Future<void> queryProducts() async {
    if (kIsWeb || _iap == null) return;
    try {
      final Set<String> ids = {subscriptionMonthlyId, subscriptionYearlyId};
      final ProductDetailsResponse response = await _iap!.queryProductDetails(ids);
      
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Productos no encontrados en la tienda: ${response.notFoundIDs}');
      }

      if (response.productDetails.isNotEmpty) {
        productsList.value = response.productDetails;
        
        // Rellenar proProduct para compatibilidad con código antiguo (ej: upgrade dialog)
        try {
          proProduct.value = response.productDetails.firstWhere(
            (product) => product.id == subscriptionMonthlyId,
            orElse: () => response.productDetails.first,
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error al consultar productos de Google Play: $e');
    }
  }

  Future<void> buySubscription({String productId = subscriptionMonthlyId}) async {
    if (kIsWeb || _iap == null || !isStoreAvailable.value) {
      throw Exception('La tienda de aplicaciones no está disponible en este dispositivo.');
    }

    ProductDetails? targetProduct;
    try {
      targetProduct = productsList.value.firstWhere(
        (p) => p.id == productId,
        orElse: () => proProduct.value?.id == productId ? proProduct.value! : responseProductPlaceholder(productId),
      );
    } catch (_) {
      // Si no se encuentra en la lista actual
    }

    if (targetProduct == null) {
      isPurchasePending.value = true;
      await queryProducts();
      isPurchasePending.value = false;
      try {
        targetProduct = productsList.value.firstWhere((p) => p.id == productId);
      } catch (_) {
        throw Exception('El producto de suscripción no está cargado. Reintenta en unos momentos.');
      }
    }

    isPurchasePending.value = true;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: targetProduct);
    
    try {
      // Intentar comprar la suscripción
      await _iap!.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      isPurchasePending.value = false;
      debugPrint('Error al iniciar compra: $e');
      rethrow;
    }
  }

  // Método auxiliar para evitar errores de tipo en caso de orElse fallidos antes de reconsultar
  ProductDetails responseProductPlaceholder(String id) {
    throw Exception('Producto no encontrado');
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    if (kIsWeb || _iap == null) return;
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        isPurchasePending.value = true;
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          isPurchasePending.value = false;
          debugPrint('Error en compra: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          
          final bool success = await _verifyAndApplyPurchase(purchaseDetails);
          if (success) {
            // Completar la transacción ante Google Play
            if (purchaseDetails.pendingCompletePurchase) {
              await _iap!.completePurchase(purchaseDetails);
            }
          }
          isPurchasePending.value = false;
        }
        
        if (purchaseDetails.pendingCompletePurchase && purchaseDetails.status == PurchaseStatus.canceled) {
          await _iap!.completePurchase(purchaseDetails);
          isPurchasePending.value = false;
        }
      }
    }
  }

  Future<bool> _verifyAndApplyPurchase(PurchaseDetails purchase) async {
    final user = AuthService().currentUser;
    if (user == null) {
      debugPrint('No hay un usuario autenticado para asociar la compra.');
      return false;
    }

    try {
      // Registrar la suscripción Pro en Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'email': user.email,
          'plan': 'pro',
          'active': true,
          'purchaseToken': purchase.verificationData.serverVerificationData,
          'purchaseSource': 'google_play',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Actualizar la caché local en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('navimap_last_license_check', DateTime.now().toIso8601String());
      await prefs.setBool('navimap_cached_active', true);
      await prefs.setString('navimap_cached_plan', 'pro');

      // Actualizar el estado dinámico en memoria
      SubscriptionService().updateSubscriptionState('pro', true, enableCelebration: true);
      
      return true;
    } catch (e) {
      debugPrint('Error registrando compra en Firestore: $e');
      return false;
    }
  }
}
