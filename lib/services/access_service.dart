import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'offline_map_service.dart';

class AccessStatus {
  final bool active;
  final String plan; // 'free' | 'pro'
  final bool requiresOnline;
  final int offlineDaysLeft;

  AccessStatus({
    required this.active,
    this.plan = 'free',
    this.requiresOnline = false,
    this.offlineDaysLeft = 7,
  });
}

class AccessService {
  static final AccessService _instance = AccessService._internal();
  factory AccessService() => _instance;
  AccessService._internal();

  // Claves de SharedPreferences
  static const String _keyLastCheck = 'navimap_last_license_check';
  static const String _keyCachedActive = 'navimap_cached_active';
  static const String _keyCachedPlan = 'navimap_cached_plan';
  static const String _keyCachedCode = 'navimap_cached_code';

  Future<AccessStatus> checkUserAccess(String uid) async {
    final prefs = await SharedPreferences.getInstance();

    // Comprobar conexión a Internet
    final bool isOnline = await OfflineMapService().checkInternet();

    if (isOnline) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          final bool active = data['active'] == true;
          final String plan = data['plan'] ?? 'free';
          final String? code = data['accessCode'];

          // Actualizar caché local
          await prefs.setString(_keyLastCheck, DateTime.now().toIso8601String());
          await prefs.setBool(_keyCachedActive, active);
          await prefs.setString(_keyCachedPlan, plan);
          if (code != null) {
            await prefs.setString(_keyCachedCode, code);
          } else {
            await prefs.remove(_keyCachedCode);
          }

          return AccessStatus(active: active, plan: plan);
        } else {
          // Usuario no registrado en la base de datos aún -> Plan gratuito por defecto
          // Lo creamos en Firestore de forma automática
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'email': AuthService().currentUser?.email ?? '',
            'plan': 'free',
            'active': true,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          await prefs.setString(_keyLastCheck, DateTime.now().toIso8601String());
          await prefs.setBool(_keyCachedActive, true);
          await prefs.setString(_keyCachedPlan, 'free');
          await prefs.remove(_keyCachedCode);
          return AccessStatus(active: true, plan: 'free');
        }
      } catch (e) {
        debugPrint('Error consultando Firestore en checkUserAccess: $e');
        // Si hay error en la red/servidor, caemos al flujo offline como contingencia
      }
    }

    // Flujo Offline (Sin internet o error en consulta)
    final String? lastCheckStr = prefs.getString(_keyLastCheck);
    if (lastCheckStr == null) {
      // Nunca ha validado en línea
      return AccessStatus(active: false, requiresOnline: true);
    }

    final DateTime lastCheck = DateTime.parse(lastCheckStr);
    final int differenceInDays = DateTime.now().difference(lastCheck).inDays;

    if (differenceInDays > 7) {
      // Ventana offline expirada (bloqueo preventivo)
      return AccessStatus(active: false, requiresOnline: true);
    }

    final bool cachedActive = prefs.getBool(_keyCachedActive) ?? false;
    final String cachedPlan = prefs.getString(_keyCachedPlan) ?? 'free';
    final int daysLeft = (7 - differenceInDays).clamp(0, 7);

    return AccessStatus(
      active: cachedActive,
      plan: cachedPlan,
      requiresOnline: false,
      offlineDaysLeft: daysLeft,
    );
  }

  Stream<AccessStatus> watchUserAccess(String uid) async* {
    final prefs = await SharedPreferences.getInstance();
    
    // Devolver instantáneamente la caché local para un arranque rápido de la interfaz
    final bool cachedActive = prefs.getBool(_keyCachedActive) ?? true;
    final String cachedPlan = prefs.getString(_keyCachedPlan) ?? 'free';
    yield AccessStatus(active: cachedActive, plan: cachedPlan);

    // Escuchar cambios en Firestore en tiempo real
    yield* FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data()!;
            final bool active = data['active'] == true;
            final String plan = data['plan'] ?? 'free';
            final String? code = data['accessCode'];

            // Actualizar caché de SharedPreferences
            prefs.setString(_keyLastCheck, DateTime.now().toIso8601String());
            prefs.setBool(_keyCachedActive, active);
            prefs.setString(_keyCachedPlan, plan);
            if (code != null) {
              prefs.setString(_keyCachedCode, code);
            } else {
              prefs.remove(_keyCachedCode);
            }

            return AccessStatus(active: active, plan: plan);
          } else {
            // Usuario no creado en BD aún -> plan gratuito por defecto
            // Lo creamos en Firestore de forma automática asíncrona
            FirebaseFirestore.instance.collection('users').doc(uid).set({
              'email': AuthService().currentUser?.email ?? '',
              'plan': 'free',
              'active': true,
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            prefs.setString(_keyLastCheck, DateTime.now().toIso8601String());
            prefs.setBool(_keyCachedActive, true);
            prefs.setString(_keyCachedPlan, 'free');
            prefs.remove(_keyCachedCode);
            return AccessStatus(active: true, plan: 'free');
          }
        }).handleError((error) {
          debugPrint('Error en la escucha en tiempo real de Firestore: $error');
          // En caso de error, mantenemos el estado local en caché
          return AccessStatus(active: cachedActive, plan: cachedPlan);
        });
  }

  Future<String?> registerAccessCode(String uid, String code) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanCode = code.trim().toUpperCase();

    final bool isOnline = await OfflineMapService().checkInternet();
    if (!isOnline) {
      throw Exception('Se requiere conexión a Internet para validar el código de acceso.');
    }

    try {
      // 1. Validar el código de acceso en la colección 'accessCodes'
      final codeSnap = await FirebaseFirestore.instance.collection('accessCodes').doc(cleanCode).get();
      
      if (!codeSnap.exists) {
        return null; // Código no existe
      }

      final codeData = codeSnap.data()!;
      
      // Buscar campos de forma insensible a mayúsculas/minúsculas para dar soporte a ACTIVE, PLAN y USEDBY
      final activeVal = codeData['active'] ?? codeData['ACTIVE'];
      final bool active = activeVal == true || activeVal.toString().toLowerCase() == 'true';
      
      final planVal = codeData['plan'] ?? codeData['PLAN'];
      final String plan = (planVal ?? 'free').toString().toLowerCase();

      final usedByVal = codeData['usedBy'] ?? codeData['usedby'] ?? codeData['USEDBY'];
      final String? usedBy = usedByVal?.toString();

      if (!active) {
        return null; // Código inactivo
      }

      final bool isUsed = usedBy != null && usedBy.isNotEmpty && usedBy != 'null';
      if (isUsed && usedBy != uid) {
        return null; // Código ya utilizado por otro usuario
      }

      // 2. Asociar el código al usuario en Firestore (Transacción o Lote para atomicidad)
      final batch = FirebaseFirestore.instance.batch();
      
      // Registrar uso en el código
      batch.update(
        FirebaseFirestore.instance.collection('accessCodes').doc(cleanCode),
        {'usedBy': uid},
      );

      // Crear o actualizar perfil de usuario
      final user = AuthService().currentUser;
      batch.set(
        FirebaseFirestore.instance.collection('users').doc(uid),
        {
          'email': user?.email ?? '',
          'accessCode': cleanCode,
          'plan': plan,
          'active': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      // 3. Guardar caché local
      await prefs.setString(_keyLastCheck, DateTime.now().toIso8601String());
      await prefs.setBool(_keyCachedActive, true);
      await prefs.setString(_keyCachedPlan, plan);
      await prefs.setString(_keyCachedCode, cleanCode);

      return plan;
    } catch (e) {
      debugPrint('Error registrando código de acceso: $e');
      rethrow;
    }
  }

  Future<void> clearLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastCheck);
    await prefs.remove(_keyCachedActive);
    await prefs.remove(_keyCachedPlan);
    await prefs.remove(_keyCachedCode);
  }
}
