import 'package:flutter/material.dart';
import '../theme/design_system.dart';
import 'dart:typed_data';
import 'package:pdfx/pdfx.dart';
import '../services/map_data_service.dart';
import '../services/user_location_service.dart';
import '../services/georeference_service.dart';
import '../widgets/user_location_marker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

class MapDetailScreen extends StatefulWidget {
  const MapDetailScreen({super.key});

  @override
  State<MapDetailScreen> createState() => _MapDetailScreenState();
}

class _MapDetailScreenState extends State<MapDetailScreen> {
  PdfController? _pdfController;
  final MapController _mapController = MapController();
  
  static final Map<String, double> _dynamicMinZooms = {};
  
  String _mapTitle = '';
  String? _errorMessage;

  UserLocationData? _currentUserLocation;
  double _pdfPageWidth = 1000;
  double _pdfPageHeight = 1000;
  final GlobalKey _mapAreaKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadMap();
    _initLocationTracking();
  }

  void _initLocationTracking() {
    UserLocationService().startTracking();
    UserLocationService().locationStream.listen((data) {
      if (mounted) {
        setState(() {
          _currentUserLocation = data;
          _updateMarkerPosition();
        });
      }
    });
  }

  void _calibratePosition() {
    if (_currentUserLocation == null || _mapImageBytes == null) return;
    
    // In FlutterMap, calibration by dragging is different because the base map is fixed.
    // For now, we will simply center the camera on the user's location.
    _mapController.move(
      latlong2.LatLng(_currentUserLocation!.latitude, _currentUserLocation!.longitude),
      _mapController.camera.zoom,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cámara centrada en tu posición GPS'),
        backgroundColor: Colors.green,
      )
    );
  }

  void _updateMarkerPosition() {
    // With FlutterMap, MarkerLayer automatically handles GPS to Pixel transformation!
    // No need to manually calculate offsets.
    if (_currentUserLocation != null) {
      // Trigger a rebuild to update the MarkerLayer
    }
  }

  Uint8List? _mapImageBytes;

  Future<void> _loadMap() async {
    final service = MapDataService();
    _mapTitle = service.currentMapTitle ?? 'Mapa';
    final bytes = service.currentMapBytes;

    if (bytes != null && bytes.isNotEmpty) {
      try {
        await GeoreferenceService().scanGeoPdfMetadata(_mapTitle, bytes);

        final document = await PdfDocument.openData(bytes);
        final page = await document.getPage(1);

        final cal = GeoreferenceService().getCalibration(_mapTitle);
        Rect? cropRect;
        double renderWidth = page.width * 2;
        double renderHeight = page.height * 2;
        
        if (cal != null && cal.minLptsX != null) {
          print("DEBUG: Página completa: $renderWidth x $renderHeight");
        }

        // Renderizar la página completa
        final image = await page.render(
          width: renderWidth,
          height: renderHeight,
          format: PdfPageImageFormat.png,
        );

        setState(() {
          _pdfPageWidth = renderWidth / 2;
          _pdfPageHeight = renderHeight / 2;
          _mapImageBytes = image!.bytes;
          _pdfController = PdfController(document: Future.value(document));
          
          // PRINTS DE DIAGNÓSTICO
          print('========== PDF LOADED: $_mapTitle ==========');
          print('PDF Page dimensions: ${page.width} x ${page.height}');
          print('Render dimensions: $renderWidth x $renderHeight');
          print('Final _pdfPageWidth: $_pdfPageWidth');
          print('Final _pdfPageHeight: $_pdfPageHeight');
          print('PDF Ratio: ${_pdfPageWidth / _pdfPageHeight}');
          
          final cal = GeoreferenceService().getCalibration(_mapTitle);
          if (cal != null) {
            print('Calibration projection: ${cal.projectionIdentifier}');
            print('Bounds: S=${cal.boundsSouth}, N=${cal.boundsNorth}, W=${cal.boundsWest}, E=${cal.boundsEast}');
          }
          print('==========================================');
        });
      } catch (e) {
        setState(() => _errorMessage = 'Error al abrir el PDF: $e');
      }
    } else {
      setState(() => _errorMessage = 'El archivo no contiene datos válidos.');
    }
  }

  void _openMapLayers() {
    Navigator.pushNamed(
      context,
      '/map-layers',
      arguments: _mapTitle,
    ).then((_) => setState(() {}));
  }

  @override
  void dispose() {
    UserLocationService().stopTracking();
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Map<String, double>? centerLatLon;
    try {
      final center = _mapController.camera.center;
      centerLatLon = {'lat': center.latitude, 'lon': center.longitude};
    } catch (_) {
      // MapController not ready yet
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        centerTitle: true,
        title: Text(
          _mapTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: DesignSystem.primary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: DesignSystem.primary),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: DesignSystem.primary),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        key: _mapAreaKey,
        children: [
          Container(color: Colors.grey[600]),
          _pdfController == null
              ? const Center(
                  child: CircularProgressIndicator(color: DesignSystem.primary),
                )
              : Builder(
                  builder: (context) {
                    var bounds = GeoreferenceService().getMapBounds(_mapTitle);
                    if (bounds == null) {
                      return const Center(child: Text("El mapa no tiene georreferencia válida.", style: TextStyle(color: Colors.white)));
                    }
                    
                    // FIX 3: Ajustar bounds para que coincidan con aspect ratio del PDF
                    final pdfRatio = _pdfPageWidth / _pdfPageHeight;
                    final geoWidth = bounds.east - bounds.west;
                    final geoHeight = bounds.north - bounds.south;
                    final geoRatio = geoWidth / geoHeight;
                    
                    if ((pdfRatio - geoRatio).abs() > 0.05) {
                      final centerLat = (bounds.south + bounds.north) / 2;
                      final centerLon = (bounds.west + bounds.east) / 2;
                      
                      if (pdfRatio > geoRatio) {
                        // PDF más ancho, expandir longitud
                        final newWidth = geoHeight * pdfRatio;
                        bounds = LatLngBounds(
                          latlong2.LatLng(bounds.south, centerLon - newWidth / 2),
                          latlong2.LatLng(bounds.north, centerLon + newWidth / 2),
                        );
                      } else {
                        // PDF más alto, expandir latitud
                        final newHeight = geoWidth / pdfRatio;
                        bounds = LatLngBounds(
                          latlong2.LatLng(centerLat - newHeight / 2, bounds.west),
                          latlong2.LatLng(centerLat + newHeight / 2, bounds.east),
                        );
                      }
                    }
                    
                    return FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCameraFit: CameraFit.bounds(
                          bounds: bounds,
                          padding: const EdgeInsets.all(20),
                        ),
                        minZoom: _dynamicMinZooms[_mapTitle] ?? 1.0,
                        maxZoom: 22.0,
                        onMapReady: () {
                          if (!_dynamicMinZooms.containsKey(_mapTitle)) {
                            // Esperar a que CameraFit.bounds se aplique realmente (toma 1 frame)
                            Future.delayed(const Duration(milliseconds: 100), () {
                              if (!mounted) return;
                              
                              final RenderBox? renderBox = _mapAreaKey.currentContext?.findRenderObject() as RenderBox?;
                              if (renderBox == null) {
                                setState(() => _dynamicMinZooms[_mapTitle] = 10.0);
                                return;
                              }
                              
                              // AHORA SÍ el zoom será el correcto (ej: 15.0 para el mapa 2)
                              final currentZoom = _mapController.camera.zoom;
                              
                              final minZoom = currentZoom - 0.7;
                              
                              setState(() {
                                _dynamicMinZooms[_mapTitle] = minZoom;
                                print('✅ GUARDADO: $_mapTitle → minZoom = $minZoom (desde currentZoom = $currentZoom)');
                                print('📊 Map completo: $_dynamicMinZooms');
                              });
                            });
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.navimap',
                          tileProvider: CancellableNetworkTileProvider(silenceExceptions: true),
                        ),
                        OverlayImageLayer(
                          overlayImages: [
                            OverlayImage(
                              bounds: bounds,
                              imageProvider: MemoryImage(_mapImageBytes!),
                              opacity: 1.0,
                            ),
                          ],
                        ),
                        if (_currentUserLocation != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: latlong2.LatLng(_currentUserLocation!.latitude, _currentUserLocation!.longitude),
                                width: 60,
                                height: 60,
                                child: UserLocationMarker(heading: _currentUserLocation?.heading ?? 0),
                              ),
                            ],
                          ),
                      ],
                    );
                  }
                ),

          // Crosshair en el centro de la pantalla (Mira estática combinada)
          Center(
            child: SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.circle_outlined,
                    color: DesignSystem.primary.withValues(alpha: 0.8),
                    size: 28,
                  ),
                  Icon(
                    Icons.add,
                    color: DesignSystem.primary.withValues(alpha: 0.8),
                    size: 38,
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            top: 20,
            right: 20,
            child: _buildCircularButton(Icons.navigation_outlined),
          ),

          Positioned(
            bottom: 160,
            right: 20,
            child: GestureDetector(
              onTap: _calibratePosition,
              child: _buildCircularButton(Icons.gps_fixed, color: Colors.green),
            ),
          ),

          Positioned(
            bottom: 100,
            right: 20,
            child: GestureDetector(
              onTap: () {
                // Usamos el GPS real, ya no sobreescribimos con coordenadas simuladas.
              },
              child: _buildCircularButton(Icons.location_on),
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF0D0D0D),
              child: SafeArea(
                child: Row(
                  children: [
                    const Icon(Icons.straighten, color: DesignSystem.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F1F1F),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              centerLatLon != null
                                  ? '${centerLatLon!['lat']!.toStringAsFixed(6)}, ${centerLatLon!['lon']!.toStringAsFixed(6)}${GeoreferenceService().debugInfo.isNotEmpty ? " | " + GeoreferenceService().debugInfo : ""}'
                                  : (GeoreferenceService().hasCalibrationFor(
                                          _mapTitle,
                                        )
                                        ? 'Calculando... ${GeoreferenceService().debugInfo}'
                                        : 'NO REFERENCIADO'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_currentUserLocation != null)
                              Text(
                                'GPS REAL: ${_currentUserLocation!.latitude.toStringAsFixed(6)}, ${_currentUserLocation!.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  color: DesignSystem.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _calibratePosition,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "CALIBRAR\nAQUÍ",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _openMapLayers,
                      child: const Icon(
                        Icons.layers_outlined,
                        color: DesignSystem.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCircularButton(IconData icon, {Color? color}) {
    return Container(
      width: 50,
      height: 50,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D0D),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(icon, color: color ?? DesignSystem.primary, size: 26),
    );
  }
}
