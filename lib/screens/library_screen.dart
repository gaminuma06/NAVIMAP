import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:typed_data';
import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/design_system.dart';
import '../widgets/sidebar_menu.dart';
import '../widgets/map_list_item.dart';
import '../widgets/layer_list_item.dart';
import '../widgets/export_layer_dialog.dart';
import '../widgets/map_loading_item.dart';
import 'add_map_overlay.dart';
import '../services/map_data_service.dart';
import '../services/layer_store.dart';
import '../services/user_location_service.dart';
import '../services/georeference_service.dart';
import '../services/subscription_service.dart';
import '../services/map_persistence_service.dart';
import 'dart:async';

class MapStore {
  static Map<String, Uint8List> bytesCache = {};
  static final List<Map<String, dynamic>> mockMaps = [];
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _selectedSegment = 0; // 0 for Mapas, 1 for Capas
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> get _mockMaps => MapStore.mockMaps;
  final List<String> _loadingMaps =
      []; // Nombres de los mapas que se están procesando

  StreamSubscription? _locationSubscription;
  UserLocationData? _lastLocation;

  bool get isMapsTab => _selectedSegment == 0;

  bool _isMapEnabled(Map<String, dynamic> map, bool isPro) {
    if (isPro) return true;

    // Sort all current mockMaps by addedAt ascending
    final sorted = List<Map<String, dynamic>>.from(_mockMaps);
    sorted.sort((a, b) {
      final aTime = a['addedAt'] as num? ?? 0;
      final bTime = b['addedAt'] as num? ?? 0;
      return aTime.compareTo(bTime);
    });

    // Find the index of the current map in the sorted list
    final index = sorted.indexOf(map);
    return index >= 0 && index < 3;
  }

  List<Map<String, dynamic>> get _filteredMaps {
    List<Map<String, dynamic>> list = _mockMaps;
    if (_searchQuery.isNotEmpty) {
      list = _mockMaps
          .where(
            (map) => map['title'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ),
          )
          .toList();
    }

    final isPro = SubscriptionService().isPro;
    final sortedList = List<Map<String, dynamic>>.from(list);
    sortedList.sort((a, b) {
      if (!isPro) {
        final aEnabled = _isMapEnabled(a, false);
        final bEnabled = _isMapEnabled(b, false);
        if (aEnabled && !bEnabled) return -1;
        if (!aEnabled && bEnabled) return 1;
      }

      final aTime = a['addedAt'] as num? ?? 0;
      final bTime = b['addedAt'] as num? ?? 0;
      return bTime.compareTo(aTime);
    });
    return sortedList;
  }

  List<Map<String, dynamic>> get _filteredLayers {
    final allLayers = LayerStore.getLayers(null);
    if (_searchQuery.isEmpty) return allLayers;
    return allLayers
        .where(
          (layer) => layer['title'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        )
        .toList();
  }

  bool _fontsLoaded = false;

  @override
  void initState() {
    super.initState();
    _preloadFonts();
    UserLocationService().startTracking();
    _lastLocation = UserLocationService().lastData;
    _recalculateMapStatuses();
    _loadSavedMaps();
    _locationSubscription = UserLocationService().locationStream.listen((
      location,
    ) {
      if (!mounted) return;
      setState(() {
        _lastLocation = location;
        _recalculateMapStatuses();
      });
    });
    SubscriptionService().planNotifier.addListener(_checkPlanCelebration);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPlanCelebration();
    });
  }

  Future<void> _loadSavedMaps() async {
    if (MapStore.mockMaps.isNotEmpty) return;
    await LayerStore.loadLayers();
    final savedMaps = await MapPersistenceService().loadSavedMaps(MapStore.bytesCache);
    if (!mounted) return;
    setState(() {
      for (var map in savedMaps) {
        final title = map['title'] as String;
        MapSpatialStatus initialStatus = MapSpatialStatus.notReferenced;
        if (GeoreferenceService().hasCalibrationFor(title)) {
          if (_lastLocation != null) {
            bool isInside = GeoreferenceService().isUserInsideMap(
              title,
              _lastLocation!.latitude,
              _lastLocation!.longitude,
            );
            initialStatus = isInside
                ? MapSpatialStatus.within
                : MapSpatialStatus.outside;
          } else {
            initialStatus = MapSpatialStatus.outside;
          }
        }
        
        _mockMaps.add({
          'title': title,
          'date': map['date'],
          'status': initialStatus,
          'thumbnailBytes': map['thumbnail'],
        });
      }
    });
  }

  Future<void> _preloadFonts() async {
    try {
      await GoogleFonts.pendingFonts([
        GoogleFonts.inter(fontWeight: FontWeight.w400),
        GoogleFonts.inter(fontWeight: FontWeight.w500),
        GoogleFonts.inter(fontWeight: FontWeight.w600),
        GoogleFonts.inter(fontWeight: FontWeight.w700),
        GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
        GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
      ]);
    } catch (e) {
      debugPrint('Error precalentando fuentes: $e');
    } finally {
      if (mounted) {
        setState(() {
          _fontsLoaded = true;
        });
      }
    }
  }

  void _recalculateMapStatuses() {
    if (_lastLocation == null) return;
    for (var map in _mockMaps) {
      final title = map['title'] as String;
      if (!GeoreferenceService().hasCalibrationFor(title)) {
        map['status'] = MapSpatialStatus.notReferenced;
      } else {
        bool isInside = GeoreferenceService().isUserInsideMap(
          title,
          _lastLocation!.latitude,
          _lastLocation!.longitude,
        );
        map['status'] = isInside
            ? MapSpatialStatus.within
            : MapSpatialStatus.outside;
      }
    }
  }

  Future<void> _downloadMap(String title) async {
    final bytes = MapStore.bytesCache[title];
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron obtener los datos del mapa.'),
          backgroundColor: DesignSystem.error,
        ),
      );
      return;
    }

    final name = title.toLowerCase().endsWith('.pdf') ? title : '$title.pdf';
    try {
      final String? savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar Mapa',
        fileName: name,
        bytes: bytes,
      );

      if (mounted && savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mapa guardado correctamente en: $savedPath'),
            backgroundColor: const Color(0xFF388E3C),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar el mapa: $e'),
            backgroundColor: DesignSystem.error,
          ),
        );
      }
    }
  }

  Future<void> _shareMap(String title) async {
    final bytes = MapStore.bytesCache[title];
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron obtener los datos del mapa.'),
          backgroundColor: DesignSystem.error,
        ),
      );
      return;
    }

    final name = title.toLowerCase().endsWith('.pdf') ? title : '$title.pdf';
    try {
      final XFile xFile = XFile.fromData(
        bytes,
        name: name,
        mimeType: 'application/pdf',
      );

      await Share.shareXFiles(
        [xFile],
        text: 'Copia del mapa "$title" enviada desde NaviMap',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir el mapa: $e'),
            backgroundColor: DesignSystem.error,
          ),
        );
      }
    }
  }

  void _checkPlanCelebration() {
    if (!mounted) return;
    final service = SubscriptionService();
    if (service.celebrationPending) {
      service.celebrationPending = false;
      final plan = service.currentPlan;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          if (Localizations.of<MaterialLocalizations>(context, MaterialLocalizations) == null) {
            service.celebrationPending = true;
            return;
          }
          _showCelebrationDialog(plan);
        } catch (e) {
          debugPrint('Diferiendo el diálogo de bienvenida debido a un estado inestable: $e');
          service.celebrationPending = true;
        }
      });
    }
  }

  void _showCelebrationDialog(String plan) {
    final planLower = plan.toLowerCase();
    if (planLower == 'hlg') {
      _showHlgCelebrationDialog();
    } else if (planLower == 'pro') {
      _showProCelebrationDialog();
    }
  }

  void _showHlgCelebrationDialog() {
    final themeColor = const Color(0xFF00E676); // Verde esmeralda brillante
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF131313),
            borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
            border: Border.all(
              color: themeColor.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: themeColor.withValues(alpha: 0.15),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Premium Enterprise Icon with glow
              Container(
                padding: const EdgeInsets.all(DesignSystem.spacingLg),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: themeColor.withValues(alpha: 0.35),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withValues(alpha: 0.05),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.domain_verification_rounded,
                  color: themeColor,
                  size: 56,
                ),
              ),
              const SizedBox(height: 24),
              // Corporate Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: themeColor.withValues(alpha: 0.25), width: 0.8),
                ),
                child: Text(
                  'ACCESO CORPORATIVO HLG',
                  style: GoogleFonts.spaceGrotesk(
                    color: themeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // Title
              Text(
                '¡Bienvenido a NaviMap!',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 14),
              // Subtitle / Body text
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Gracias al Ingeniero Adan Arias y a la provisión directa de Hacienda La Gloria, tienes acceso ilimitado a todas las herramientas geográficas, capas y mapas georreferenciados de la plataforma.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: EdgeInsets.only(left: 4.0),
                        child: Icon(
                          Icons.water_drop,
                          size: 13,
                          color: Color(0xFF00B0FF),
                        ),
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Premium Business Action Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'COMENZAR',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Colors.black.withValues(alpha: 0.8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProCelebrationDialog() {
    final themeColor = const Color(0xFFFFD700); // Dorado
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF131313),
            borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
            border: Border.all(
              color: themeColor.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: themeColor.withValues(alpha: 0.15),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with glow
              Container(
                padding: const EdgeInsets.all(DesignSystem.spacingLg),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: themeColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withValues(alpha: 0.05),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: themeColor,
                  size: 56,
                ),
              ),
              const SizedBox(height: 24),
              // Plan Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: themeColor.withValues(alpha: 0.3), width: 0.8),
                ),
                child: Text(
                  'NAVIMAP PRO',
                  style: GoogleFonts.spaceGrotesk(
                    color: themeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Card Title
              Text(
                '¡Bienvenido a NAVIMAP Pro!',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              // Card Subtitle
              Text(
                '¡Gracias por suscribirte! Ahora tienes acceso a todas las herramientas avanzadas y mapas ilimitados.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              // Action Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'COMENZAR',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Colors.black.withValues(alpha: 0.8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    SubscriptionService().planNotifier.removeListener(_checkPlanCelebration);
    _locationSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (SubscriptionService().celebrationPending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkPlanCelebration();
      });
    }

    if (!_fontsLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFF131313),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00E676),
          ),
        ),
      );
    }

    final currentList = isMapsTab ? _filteredMaps : _filteredLayers;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: '',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        surfaceTintColor: Colors.transparent,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Buscar...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : ValueListenableBuilder<String>(
                valueListenable: SubscriptionService().planNotifier,
                builder: (context, plan, _) {
                  final isProOrHlg = plan.toLowerCase() == 'pro' || plan.toLowerCase() == 'hlg';
                  return Text(
                    'NAVIMAP',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: isProOrHlg ? const Color(0xFFFFD700) : Colors.white,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      drawer: const SidebarMenu(),
      body: Stack(
        children: [
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(DesignSystem.spacingMd),
                  child: Container(
                    padding: const EdgeInsets.all(DesignSystem.spacingXs),
                    decoration: BoxDecoration(
                      color: DesignSystem.surfaceContainer,
                      borderRadius: BorderRadius.circular(
                        DesignSystem.radiusDefault,
                      ),
                      border: Border.all(color: DesignSystem.outline),
                    ),
                    child: Row(
                      children: [
                        _buildSegment('Mapas', 0),
                        _buildSegment('Capas', 1),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignSystem.spacingMd,
                  ),
                  child: Text(
                    '${isMapsTab ? "MAPAS" : "CAPAS"} DISPONIBLES (${currentList.length + (isMapsTab ? _loadingMaps.length : 0)})',
                    style: DesignSystem.labelCaps.copyWith(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: DesignSystem.spacingMd),
                Expanded(
                  child:
                      (currentList.isEmpty && _loadingMaps.isEmpty && !_isSearching)
                      ? _buildEmptyStatePlaceholder(isMapsTab ? 'mapas' : 'capas')
                      : ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DesignSystem.spacingMd,
                          ),
                          children: [
                            // Tarjetas de carga primero
                            if (isMapsTab)
                              ..._loadingMaps
                                  .map((name) => MapLoadingItem(title: name)),
                            // Lista normal
                            ...currentList.map((item) {
                              final String title = item['title'];
                              if (isMapsTab) {
                                return MapListItem(
                                  title: title,
                                  dateAdded: item['date'],
                                  status: item['status'],
                                  thumbnailBytes: item['thumbnailBytes'],
                                  isEnabled: _isMapEnabled(item, SubscriptionService().isPro),
                                  onTap: () {
                                    final bytes = MapStore.bytesCache[title];
                                    if (bytes != null) {
                                      MapDataService().setCurrentMap(
                                        title,
                                        Uint8List.fromList(bytes),
                                      );
                                    }
                                    Navigator.pushNamed(context, '/detail');
                                  },
                                  onDownload: () => _downloadMap(title),
                                  onShare: () => _shareMap(title),
                                  onDelete: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: DesignSystem.surface,
                                        title: const Text(
                                          '¿Eliminar Mapa?',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        content: Text(
                                          '¿Deseas eliminar el mapa "$title"? Todos los datos asociados se perderán.',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('CANCELAR'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: DesignSystem.error,
                                            ),
                                            onPressed: () async {
                                              final title = item['title'] as String;
                                              final navigator = Navigator.of(context);
                                              GeoreferenceService().clearCache(title);
                                              await MapPersistenceService().deleteMap(title);
                                              MapStore.bytesCache.remove(title);
                                              if (mounted) {
                                                setState(() {
                                                  _mockMaps.remove(item);
                                                });
                                                navigator.pop();
                                              }
                                            },
                                            child: const Text('ELIMINAR'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              } else {
                                return LayerListItem(
                                  title: title,
                                  objectCount: item['objects'] ?? 0,
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/layer-objects',
                                      arguments: {
                                        'layerName': title,
                                        'mapContext': null,
                                      },
                                    ).then((_) => setState(() {}));
                                  },
                                  onDelete: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: DesignSystem.surface,
                                        title: const Text(
                                          '¿Eliminar Capa?',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        content: Text(
                                          '¿Deseas eliminar "$title" del respaldo global? Esta acción no se puede deshacer.',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('CANCELAR'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: DesignSystem.error,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                LayerStore.layers.remove(item);
                                                LayerStore.mapLayerObjects.remove(
                                                  title,
                                                );
                                              });
                                              LayerStore.saveLayers();
                                              Navigator.pop(context);
                                            },
                                            child: const Text('ELIMINAR'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  onExport: () {
                                    final objects = LayerStore.getObjects(title, mapContext: null);
                                    ExportLayerDialog.show(
                                      context,
                                      layerName: title,
                                      objects: objects,
                                    );
                                  },
                                );
                              }
                            }),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pushReplacementNamed(context, '/satellite');
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFE0E0E0), // Gris pálido
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.satellite_alt,
                    color: Color(0xFF1976D2), // Azul pálido / medio
                    size: 20,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Satélite',
                    style: TextStyle(
                      color: Color(0xFF1976D2), // Azul pálido / medio
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () => _onAddPressed(),
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  void _onAddPressed() {
    if (isMapsTab) {
      AddMapOverlay.show(
        context,
        onMapProcessingStarted: (name) {
          setState(() {
            _loadingMaps.insert(0, name);
          });
        },
        onMapAdded: (name, thumbnail, fullBytes) async {
          try {
            if (fullBytes != null) {
              final bytes = Uint8List.fromList(fullBytes);
              MapStore.bytesCache[name] = bytes;
              await GeoreferenceService().scanGeoPdfMetadata(name, bytes);
              final dateStr = '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
              await MapPersistenceService().saveMap(name, bytes, thumbnail, dateStr);
            }
          } catch (e) {
            debugPrint('Error al escanear metadatos del GeoPDF importado: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error al procesar metadatos de "$name": $e'),
                  backgroundColor: DesignSystem.error,
                ),
              );
            }
          } finally {
            setState(() {
              _loadingMaps.remove(name);

              // Calcular estado inicial
              MapSpatialStatus initialStatus = MapSpatialStatus.notReferenced;
              if (GeoreferenceService().hasCalibrationFor(name)) {
                if (_lastLocation != null) {
                  bool isInside = GeoreferenceService().isUserInsideMap(
                    name,
                    _lastLocation!.latitude,
                    _lastLocation!.longitude,
                  );
                  initialStatus = isInside
                      ? MapSpatialStatus.within
                      : MapSpatialStatus.outside;
                } else {
                  initialStatus = MapSpatialStatus.outside;
                }
              }

              _mockMaps.insert(0, {
                'title': name,
                'date':
                    '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                'status': initialStatus,
                'thumbnailBytes': thumbnail,
                'addedAt': DateTime.now().millisecondsSinceEpoch,
              });
            });
          }
        },
      );
    } else {
      _showAddLayerDialog();
    }
  }

  void _showAddLayerDialog() {
    final controller = TextEditingController();
    String? errorText;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: DesignSystem.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
          ),
          title: const Row(
            children: [
              Icon(Icons.layers_outlined, color: DesignSystem.primary),
              SizedBox(width: 12),
              Text('Nueva Capa', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Deseas agregar una nueva capa de información?',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Nombre de la capa',
                  errorText: errorText,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
                  ),
                ),
                onChanged: (value) {
                  if (errorText != null) setDialogState(() => errorText = null);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignSystem.primary,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                final layers = LayerStore.getLayers(null);
                if (layers.any(
                  (l) =>
                      l['title'].toString().toLowerCase() == name.toLowerCase(),
                )) {
                  setDialogState(() => errorText = 'Ya existe esta capa');
                  return;
                }
                setState(() {
                  LayerStore.initializeLayer(name);
                });
                Navigator.pop(context);
              },
              child: const Text('CREAR CAPA'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStatePlaceholder(String type) {
    final bool isMap = type == 'mapas';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DesignSystem.spacingMd),
      child: Column(
        children: [
          Opacity(
            opacity: 0.4,
            child: DottedBorder(
              color: Colors.white24,
              strokeWidth: 2,
              dashPattern: const [8, 4],
              borderType: BorderType.RRect,
              radius: const Radius.circular(DesignSystem.radiusDefault),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(DesignSystem.spacingMd),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(
                    DesignSystem.radiusDefault,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(
                          DesignSystem.radiusSm,
                        ),
                      ),
                      child: Icon(
                        isMap ? Icons.map_outlined : Icons.layers_outlined,
                        color: Colors.white24,
                      ),
                    ),
                    const SizedBox(width: DesignSystem.spacingMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 14,
                            width: 150,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 10,
                            width: 100,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: DesignSystem.spacingLg),
          Text(
            'No hay $type cargadas',
            style: const TextStyle(color: Colors.white38, fontSize: 16),
          ),
          Text(
            'Usa el botón + para añadir tu primera ${isMap ? "mapa" : "capa"}',
            style: const TextStyle(color: Colors.white24, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSegment(String label, int index) {
    bool isSelected = _selectedSegment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSegment = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: DesignSystem.spacingSm),
          decoration: BoxDecoration(
            color: isSelected ? DesignSystem.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: DesignSystem.labelCaps.copyWith(
              color: isSelected ? Colors.black : Colors.white54,
            ),
          ),
        ),
      ),
    );
  }
}
