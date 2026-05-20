import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/design_system.dart';
import 'screens/library_screen.dart';
import 'screens/satellite_view_screen.dart';
import 'screens/map_detail_screen.dart';
import 'screens/layer_manager_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/layer_objects_screen.dart';
import 'screens/map_layer_library_screen.dart';

void main() {
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
        '/': (context) => const LibraryScreen(),
        '/satellite': (context) => const SatelliteViewScreen(),
        '/detail': (context) => const MapDetailScreen(),
        '/layers': (context) => const LayerManagerScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
