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
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import '../services/billing_service.dart';
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

  List<Map<String, dynamic>> get _filteredMaps {
    if (_searchQuery.isEmpty) return _mockMaps;
    return _mockMaps
        .where(
          (map) => map['title'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        )
        .toList();
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
    _locationSubscription = UserLocationService().locationStream.listen((
      location,
    ) {
      if (!mounted) return;
      setState(() {
        _lastLocation = location;
        _recalculateMapStatuses();
      });
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

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  final isProOrHlg = plan == 'pro' || plan.toLowerCase() == 'hlg';
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
                                  .map((name) => MapLoadingItem(title: name))
                                  .toList(),
                            // Lista normal
                            ...currentList.map((item) {
                              final String title = item['title'];
                              if (isMapsTab) {
                                return MapListItem(
                                  title: title,
                                  dateAdded: item['date'],
                                  status: item['status'],
                                  thumbnailBytes: item['thumbnailBytes'],
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
                                          '¿Deseas eliminar el mapa "${title}"? Todos los datos asociados se perderán.',
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
                                              setState(
                                                () => _mockMaps.remove(item),
                                              );
                                              Navigator.pop(context);
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
                                          '¿Deseas eliminar "${title}" del respaldo global? Esta acción no se puede deshacer.',
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
                            }).toList(),
                          ],
                        ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 88,
            right: 16,
            child: GestureDetector(
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onAddPressed(),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _onAddPressed() {
    if (isMapsTab) {
      // Verificar límite de 3 GeoPDFs en plan gratuito
      final isPro = SubscriptionService().isPro;
      if (!isPro && _mockMaps.length >= 3) {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: DesignSystem.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
              side: const BorderSide(color: DesignSystem.outline, width: 0.5),
            ),
            child: Container(
              padding: const EdgeInsets.all(DesignSystem.spacingLg),
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(DesignSystem.spacingMd),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: DesignSystem.spacingLg),
                  Text(
                    'Desbloquea NAVIMAP Pro',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: DesignSystem.spacingSm),
                  const Text(
                    'Has alcanzado el límite de 3 mapas GeoPDF del plan básico. Actualiza a Pro para desbloquear todo el potencial de la aplicación.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: DesignSystem.spacingLg),
                  Container(
                    padding: const EdgeInsets.all(DesignSystem.spacingMd),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
                      border: Border.all(color: DesignSystem.outline, width: 0.5),
                    ),
                    child: Column(
                      children: [
                        _buildBenefitRow(
                          icon: Icons.map_outlined,
                          title: 'Importaciones Ilimitadas',
                          description: 'Agrega y organiza todos los GeoPDFs que requieras.',
                        ),
                        const SizedBox(height: DesignSystem.spacingMd),
                        _buildBenefitRow(
                          icon: Icons.satellite_alt_outlined,
                          title: 'Mapas Satelitales Offline',
                          description: 'Descarga imágenes para navegar sin conexión a internet.',
                        ),
                        const SizedBox(height: DesignSystem.spacingMd),
                        _buildBenefitRow(
                          icon: Icons.flash_on_rounded,
                          title: 'Rendimiento Mejorado',
                          description: 'Carga y renderizado más rápido de capas geográficas.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DesignSystem.spacingLg),
                  // Si es Android y no Web, mostramos el botón de Play Store
                  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/settings');
                        try {
                          await BillingService().buySubscription();
                        } catch (e) {
                          debugPrint('Error en compra desde biblioteca: $e');
                        }
                      },
                      child: const Text(
                        'Suscribirse en Play Store',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: DesignSystem.spacingSm),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: DesignSystem.outline),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          '/settings',
                          arguments: {'autoOpenActivation': true},
                        );
                      },
                      child: const Text(
                        'Tengo un Código de Activación',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ] else ...[
                    // Web o iOS: Solo Código de Activación
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          '/settings',
                          arguments: {'autoOpenActivation': true},
                        );
                      },
                      child: const Text(
                        'Tengo un Código de Activación',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                  const SizedBox(height: DesignSystem.spacingSm),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Mantener Plan Básico',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        return;
      }

      AddMapOverlay.show(
        context,
        onMapProcessingStarted: (name) {
          setState(() {
            _loadingMaps.insert(0, name);
          });
        },
        onMapAdded: (name, thumbnail, fullBytes) async {
          if (fullBytes != null) {
            final bytes = Uint8List.fromList(fullBytes);
            MapStore.bytesCache[name] = bytes;
            await GeoreferenceService().scanGeoPdfMetadata(name, bytes);
          }

          setState(() {
            _loadingMaps.remove(name);

            // Calculate initial status
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
            });
          });
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
                  fillColor: Colors.white.withOpacity(0.05),
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
                  color: Colors.white.withOpacity(0.05),
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

  Widget _buildBenefitRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.amber, size: 20),
        const SizedBox(width: DesignSystem.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
