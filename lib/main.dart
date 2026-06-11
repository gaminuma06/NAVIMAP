import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/design_system.dart';
import 'screens/library_screen.dart';
import 'screens/satellite_view_screen.dart';
import 'screens/map_detail_screen.dart';
import 'screens/layer_manager_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/layer_objects_screen.dart';
import 'screens/map_layer_library_screen.dart';
import 'screens/login_screen.dart';
import 'screens/access_code_screen.dart';
import 'screens/access_denied_screen.dart';
import 'services/auth_service.dart';
import 'services/access_service.dart';
import 'services/subscription_service.dart';
import 'services/billing_service.dart';
import 'firebase_options.dart';

import 'dart:ui' show PlatformDispatcher;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Cargar estado de suscripción guardado localmente
  await SubscriptionService().loadSavedSubscription();

  // Inicializar servicio de compras (Google Play Store)
  BillingService().initialize();

  // Interceptar y silenciar errores de aserción del motor web de Flutter (window.dart)
  FlutterError.onError = (FlutterErrorDetails details) {
    final exception = details.exception;
    if (exception is AssertionError && exception.toString().contains('window.dart')) {
      // Ignorar esta aserción específica del motor web
      return;
    }
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (error is AssertionError && error.toString().contains('window.dart')) {
      // Ignorar de manera segura en el despachador de la plataforma
      return true;
    }
    return false;
  };

  runApp(const NaviMapApp());
}

class NaviMapApp extends StatelessWidget {
  const NaviMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NaviMap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: DesignSystem.surface,
        primaryColor: DesignSystem.primary,
        colorScheme: const ColorScheme.dark(
          primary: DesignSystem.primary,
          secondary: DesignSystem.secondary,
          surface: DesignSystem.surfaceContainer,
          error: DesignSystem.error,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
            .copyWith(
              headlineLarge: GoogleFonts.spaceGrotesk(
                textStyle: DesignSystem.headlineLg,
                color: DesignSystem.onSurface,
              ),
              headlineMedium: GoogleFonts.spaceGrotesk(
                textStyle: DesignSystem.headlineMd,
                color: DesignSystem.onSurface,
              ),
            ),
        appBarTheme: const AppBarTheme(
          backgroundColor: DesignSystem.surface,
          elevation: 0,
          centerTitle: true,
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: DesignSystem.surface,
        ),
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/layer-objects') {
          final args = settings.arguments;
          if (args is Map<String, dynamic>) {
            return MaterialPageRoute(
              builder: (context) => LayerObjectsScreen(
                layerName: args['layerName'] as String,
                mapContext: args['mapContext'] as String?,
              ),
            );
          } else {
            return MaterialPageRoute(
              builder: (context) =>
                  LayerObjectsScreen(layerName: args as String),
            );
          }
        }
        if (settings.name == '/map-layers') {
          final args = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => MapLayerLibraryScreen(mapTitle: args),
          );
        }
        return null;
      },
      routes: {
        '/': (context) => const AuthWrapper(),
        '/satellite': (context) => const SatelliteViewScreen(),
        '/detail': (context) => const MapDetailScreen(),
        '/layers': (context) => const LayerManagerScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<NaviMapUser?>(
      stream: AuthService().authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF131313),
            body: Center(
              child: CircularProgressIndicator(color: DesignSystem.primary),
            ),
          );
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        // Validar el acceso del usuario en tiempo real
        return StreamBuilder<AccessStatus>(
          stream: AccessService().watchUserAccess(user.uid),
          builder: (context, accessSnapshot) {
            if (accessSnapshot.connectionState == ConnectionState.waiting && !accessSnapshot.hasData) {
              return const Scaffold(
                backgroundColor: Color(0xFF131313),
                body: Center(
                  child: CircularProgressIndicator(color: DesignSystem.secondary),
                ),
              );
            }

            if (accessSnapshot.hasError) {
              return Scaffold(
                backgroundColor: const Color(0xFF131313),
                body: Center(
                  child: Text(
                    'Error al validar licencia: ${accessSnapshot.error}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              );
            }

            final status = accessSnapshot.data!;

            if (status.requiresOnline) {
              return const AccessDeniedScreen(requiresOnline: true);
            }

            if (!status.active) {
              return const AccessDeniedScreen(requiresOnline: false);
            }

            // Licencia activa -> Actualizar el SubscriptionService reactivo de forma segura después del build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              SubscriptionService().updateSubscriptionState(status.plan, true);
            });
            return const LibraryScreen();
          },
        );
      },
    );
  }
}
