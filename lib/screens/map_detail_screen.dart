import 'package:flutter/material.dart';
import '../theme/design_system.dart';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:async';
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
  StreamSubscription<UserLocationData>? _locationSubscription;
  double _pdfPageWidth = 1000;
  double _pdfPageHeight = 1000;
  final GlobalKey _mapAreaKey = GlobalKey();
  double _currentMapRotation = 0.0;
  latlong2.LatLng? _currentMapCenter;
  StreamSubscription? _mapEventSubscription;

  @override
  void initState() {
    super.initState();
    _loadMap();
    _initLocationTracking();
    _mapEventSubscription = _mapController.mapEventStream.listen((event) {
      if (mounted) {
        setState(() {
          _currentMapRotation = event.camera.rotation;
          _currentMapCenter = event.camera.center;
        });
      }
    });
  }

  void _initLocationTracking() {
    _currentUserLocation = UserLocationService().lastData;
    _updateMarkerPosition();

    UserLocationService().startTracking();
    _locationSubscription = UserLocationService().locationStream.listen((data) {
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
    
    final isInside = GeoreferenceService().isUserInsideMap(
      _mapTitle,
      _currentUserLocation!.latitude,
      _currentUserLocation!.longitude,
    );

    if (!isInside) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu ubicación está fuera de los límites de este mapa'),
          backgroundColor: Colors.redAccent,
        )
      );
      return;
    }

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

        // Intentar obtener del caché en memoria
        final cachedPng = service.getCachedPng(_mapTitle);
        final cachedWidth = service.getCachedWidth(_mapTitle);
        final cachedHeight = service.getCachedHeight(_mapTitle);

        if (cachedPng != null && cachedWidth != null && cachedHeight != null) {
          setState(() {
            _pdfPageWidth = cachedWidth;
            _pdfPageHeight = cachedHeight;
            _mapImageBytes = cachedPng;
            _pdfController = PdfController(document: PdfDocument.openData(bytes));
          });
          return;
        }

        final document = await PdfDocument.openData(bytes);
        final page = await document.getPage(1);

        Rect? cropRect;
        double renderWidth = page.width * 2;
        double renderHeight = page.height * 2;
        
        // Página completa: $renderWidth x $renderHeight

        // Renderizar la página completa
        final image = await page.render(
          width: renderWidth,
          height: renderHeight,
          format: PdfPageImageFormat.png,
        );

        final finalWidth = renderWidth / 2;
        final finalHeight = renderHeight / 2;

        // Guardar en la caché global de memoria
        service.cacheRenderedMap(_mapTitle, image!.bytes, finalWidth, finalHeight);

        setState(() {
          _pdfPageWidth = finalWidth;
          _pdfPageHeight = finalHeight;
          _mapImageBytes = image.bytes;
          _pdfController = PdfController(document: Future.value(document));
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
    _mapEventSubscription?.cancel();
    _locationSubscription?.cancel();
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Map<String, double>? centerLatLon;
    final activeCenter = _currentMapCenter ?? (() {
      try {
        return _mapController.camera.center;
      } catch (_) {
        return null;
      }
    })();
    if (activeCenter != null) {
      centerLatLon = {'lat': activeCenter.latitude, 'lon': activeCenter.longitude};
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
                        onPositionChanged: (camera, hasGesture) {
                          setState(() {
                            _currentMapRotation = camera.rotation;
                            _currentMapCenter = camera.center;
                          });
                        },
                        onMapReady: () {
                          // Forzar un frame de renderizado adicional poco después de que el mapa esté listo.
                          // Esto asegura que el marcador GPS se dibuje en su posición correcta una vez que el
                          // motor de FlutterMap ha completado su primer pase de layout.
                          Future.delayed(const Duration(milliseconds: 150), () {
                            if (mounted) {
                              setState(() {});
                            }
                          });

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
                        MarkerLayer(
                          markers: (_currentUserLocation != null &&
                                  GeoreferenceService().isUserInsideMap(
                                    _mapTitle,
                                    _currentUserLocation!.latitude,
                                    _currentUserLocation!.longitude,
                                  ))
                              ? [
                                  Marker(
                                    point: latlong2.LatLng(_currentUserLocation!.latitude, _currentUserLocation!.longitude),
                                    width: 60,
                                    height: 60,
                                    child: UserLocationMarker(heading: _currentUserLocation?.heading ?? 0),
                                  ),
                                ]
                              : [],
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

          Builder(
            builder: (context) {
              final double mapRotation = _currentMapRotation;
              final bool isRotated = mapRotation.abs() > 0.1;

              if (!isRotated) return const SizedBox.shrink();

              return Positioned(
                top: 20,
                right: 20,
                child: GestureDetector(
                  onTap: () {
                    _mapController.rotate(0.0);
                    setState(() {
                      _currentMapRotation = 0.0;
                    });
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0D0D0D),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      size: const Size(50, 50),
                      painter: CompassPainter(
                        rotation: -mapRotation * math.pi / 180.0,
                      ),
                    ),
                  ),
                ),
              );
            }
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
                          ],
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

class CompassPainter extends CustomPainter {
  final double rotation; // en radianes

  CompassPainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    // Dibujar aguja Norte (Triángulo rojo)
    final northPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    final northPath = Path();
    northPath.moveTo(0, -radius * 0.55); // Punta apuntando al Norte
    northPath.lineTo(-radius * 0.22, 0);  // Esquina izquierda
    northPath.lineTo(radius * 0.22, 0);   // Esquina derecha
    northPath.close();
    canvas.drawPath(northPath, northPaint);

    // Dibujar aguja Sur (Triángulo gris/blanco)
    final southPaint = Paint()
      ..color = Colors.grey[400]!
      ..style = PaintingStyle.fill;
    final southPath = Path();
    southPath.moveTo(0, radius * 0.55);  // Punta apuntando al Sur
    southPath.lineTo(-radius * 0.22, 0);  // Esquina izquierda
    southPath.lineTo(radius * 0.22, 0);   // Esquina derecha
    southPath.close();
    canvas.drawPath(southPath, southPaint);

    // Dibujar pasador central blanco
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, 3.5, centerPaint);

    // Dibujar la letra 'N' arriba del puntero Norte
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -radius * 0.88),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CompassPainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}
