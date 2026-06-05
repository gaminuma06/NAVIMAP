import 'package:flutter/material.dart';
import '../theme/design_system.dart';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:async';
import 'package:pdfx/pdfx.dart';
import '../services/map_data_service.dart';
import '../services/layer_store.dart';
import '../services/user_location_service.dart';
import '../services/georeference_service.dart';
import '../widgets/user_location_marker.dart';
import '../widgets/object_list_item.dart';
import 'object_attributes_screen.dart';
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

  UserLocationData? _currentUserLocation;
  StreamSubscription<UserLocationData>? _locationSubscription;
  double _pdfPageWidth = 1000;
  double _pdfPageHeight = 1000;
  final GlobalKey _mapAreaKey = GlobalKey();
  double _currentMapRotation = 0.0;
  latlong2.LatLng? _currentMapCenter;
  double _currentMapZoom = 15.0;
  StreamSubscription? _mapEventSubscription;
  String _coordinateFormat = 'DD';
  double _dragDistance = 0.0;
  bool _isBottomSheetOpen = false;
  final List<Map<String, dynamic>> _selectedPins = [];
  String? _bannerMessage;
  Color? _bannerColor;
  Timer? _bannerTimer;

  bool _isMeasuringMode = false;
  final List<latlong2.LatLng> _measuringPoints = [];
  latlong2.LatLng? _selectedLineTapPoint;

  latlong2.LatLng _getSafeCenter() {
    if (_currentMapCenter != null) return _currentMapCenter!;
    try {
      return _mapController.camera.center;
    } catch (_) {
      return const latlong2.LatLng(8.623083, -73.732583);
    }
  }

  double _calculateGeodesicLength(List<latlong2.LatLng> points) {
    double total = 0.0;
    const double r = 6371000; // Earth radius in meters
    for (int i = 0; i < points.length - 1; i++) {
      final lat1 = points[i].latitude * math.pi / 180;
      final lon1 = points[i].longitude * math.pi / 180;
      final lat2 = points[i + 1].latitude * math.pi / 180;
      final lon2 = points[i + 1].longitude * math.pi / 180;

      final dLat = lat2 - lat1;
      final dLon = lon2 - lon1;

      final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
      final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      total += r * c;
    }
    return total;
  }

  String _formatLength(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(2)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
  }

  void _toggleMeasuringMode() {
    setState(() {
      _isMeasuringMode = !_isMeasuringMode;
      _measuringPoints.clear();
      _selectedPins.clear();
      _selectedLineTapPoint = null;
    });
  }

  void _addMeasuringPoint() {
    setState(() {
      _measuringPoints.add(_getSafeCenter());
    });
  }

  void _saveMeasuringLine() {
    if (_measuringPoints.isEmpty) return;

    final List<latlong2.LatLng> finalPoints = List.from(_measuringPoints);
    if (finalPoints.length == 1) {
      finalPoints.add(_getSafeCenter());
    }

    final double totalLength = _calculateGeodesicLength(finalPoints);
    final formattedLength = _formatLength(totalLength);

    String? activeLayer = LayerStore.activeMapLayer[_mapTitle];
    if (activeLayer == null) {
      final existingLayers = LayerStore.getLayers(_mapTitle);
      if (existingLayers.isNotEmpty) {
        activeLayer = existingLayers.first['title'];
        LayerStore.activeMapLayer[_mapTitle] = activeLayer;
      } else {
        int i = 1;
        String candidate = 'Capa $i';
        while (LayerStore.layers.any((l) => l['title'].toString().toLowerCase() == candidate.toLowerCase())) {
          i++;
          candidate = 'Capa $i';
        }
        activeLayer = candidate;
        LayerStore.initializeLayer(activeLayer, mapContext: _mapTitle);
        existingLayers.add({'title': activeLayer, 'objects': 0});
        LayerStore.activeMapLayer[_mapTitle] = activeLayer;
      }
    }

    final objects = LayerStore.getObjects(activeLayer!, mapContext: _mapTitle);
    final linesCount = objects.where((obj) => obj['type'] == GeoObjectType.line).length;
    final defaultLineName = 'Línea ${linesCount + 1}';

    final controller = TextEditingController(text: defaultLineName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DesignSystem.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
        ),
        title: const Row(
          children: [
            Icon(Icons.timeline, color: Colors.orangeAccent),
            SizedBox(width: 12),
            Text(
              'Nueva Línea',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingresa un nombre para la línea creada:',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nombre de la línea',
                labelStyle: const TextStyle(color: DesignSystem.primary),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Longitud total: $formattedLength',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Capa de destino: $activeLayer',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
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
              final lineName = controller.text.trim();
              if (lineName.isEmpty) return;

              setState(() {
                LayerStore.addObject(
                  activeLayer!,
                  {
                    'name': lineName,
                    'type': GeoObjectType.line,
                    'value': formattedLength,
                    'points': finalPoints.map((p) => {
                      'latitude': p.latitude,
                      'longitude': p.longitude,
                    }).toList(),
                    'unit': 'm',
                    'color': 0xFFFFA726,
                  },
                  mapContext: _mapTitle,
                );
                _isMeasuringMode = false;
                _measuringPoints.clear();
              });

              Navigator.pop(context);

              _showTopBanner(
                'Línea "$lineName" guardada en "$activeLayer"',
                const Color(0xFF388E3C),
              );
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

  void _showTopBanner(String message, Color color) {
    _bannerTimer?.cancel();
    setState(() {
      _bannerMessage = message;
      _bannerColor = color;
    });
    _bannerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _bannerMessage = null;
          _bannerColor = null;
        });
      }
    });
  }

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
          _currentMapZoom = event.camera.zoom;
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
      _showTopBanner(
        'Tu ubicación está fuera de los límites de este mapa',
        const Color(0xFFD32F2F),
      );
      return;
    }

    // In FlutterMap, calibration by dragging is different because the base map is fixed.
    // For now, we will simply center the camera on the user's location.
    _mapController.move(
      latlong2.LatLng(_currentUserLocation!.latitude, _currentUserLocation!.longitude),
      _mapController.camera.zoom,
    );

    _showTopBanner(
      'Cámara centrada en tu posición GPS',
      const Color(0xFF388E3C),
    );
  }

  void _updateMarkerPosition() {
    // With FlutterMap, MarkerLayer automatically handles GPS to Pixel transformation!
    // No need to manually calculate offsets.
    if (_currentUserLocation != null) {
      // Trigger a rebuild to update the MarkerLayer
    }
  }

  double _calculateMarkerSize(double zoom) {
    double size = 36.0 + (zoom - 15.0) * 3.0;
    return size.clamp(16.0, 64.0);
  }

  void _openPinAttributes(Map<String, dynamic> pinObj) {
    final activeLayer = LayerStore.activeMapLayer[_mapTitle];
    if (activeLayer == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ObjectAttributesScreen(
          layerName: activeLayer,
          object: pinObj,
          mapContext: _mapTitle,
        ),
      ),
    ).then((value) {
      setState(() {
        _selectedPins.clear();
      });
    });
  }

  void _handlePinTap(Map<String, dynamic> clickedObj) {
    final activeLayer = LayerStore.activeMapLayer[_mapTitle];
    if (activeLayer == null) return;
    final objects = LayerStore.getObjects(activeLayer, mapContext: _mapTitle);

    final List<Map<String, dynamic>> closePins = [];
    
    try {
      final clickedLat = clickedObj['latitude'] as double;
      final clickedLon = clickedObj['longitude'] as double;
      final clickedPos = _mapController.camera.project(latlong2.LatLng(clickedLat, clickedLon));

      for (var obj in objects) {
        if (obj['type'] == GeoObjectType.point &&
            obj['latitude'] != null &&
            obj['longitude'] != null) {
          final lat = obj['latitude'] as double;
          final lon = obj['longitude'] as double;
          final pos = _mapController.camera.project(latlong2.LatLng(lat, lon));
          
          final dx = clickedPos.x - pos.x;
          final dy = clickedPos.y - pos.y;
          final dist = math.sqrt(dx * dx + dy * dy);
          
          if (dist < 40.0) {
            closePins.add(obj);
          }
        }
      }
    } catch (e) {
      closePins.add(clickedObj);
    }
    
    setState(() {
      _selectedPins.clear();
      _selectedPins.addAll(closePins);
    });
  }

  void _handleMapTap(latlong2.LatLng point) {
    if (_isMeasuringMode) return;

    final activeLayer = LayerStore.activeMapLayer[_mapTitle];
    if (activeLayer == null) {
      setState(() {
        _selectedPins.clear();
        _selectedLineTapPoint = null;
      });
      return;
    }

    final objects = LayerStore.getObjects(activeLayer, mapContext: _mapTitle);
    final List<Map<String, dynamic>> closeObjects = [];
    latlong2.LatLng? lineTapPoint;

    try {
      final tapPos = _mapController.camera.project(point);

      for (var obj in objects) {
        if (obj['type'] == GeoObjectType.point &&
            obj['latitude'] != null &&
            obj['longitude'] != null) {
          final lat = obj['latitude'] as double;
          final lon = obj['longitude'] as double;
          final pos = _mapController.camera.project(latlong2.LatLng(lat, lon));
          
          final dx = tapPos.x - pos.x;
          final dy = tapPos.y - pos.y;
          final dist = math.sqrt(dx * dx + dy * dy);
          
          if (dist < 40.0) {
            closeObjects.add(obj);
          }
        } else if (obj['type'] == GeoObjectType.line && obj['points'] != null) {
          final pts = obj['points'] as List;
          for (int i = 0; i < pts.length - 1; i++) {
            final pt1 = pts[i];
            final pt2 = pts[i + 1];
            if (pt1['latitude'] == null || pt1['longitude'] == null ||
                pt2['latitude'] == null || pt2['longitude'] == null) continue;
            
            final p1 = _mapController.camera.project(latlong2.LatLng(
              pt1['latitude'] as double,
              pt1['longitude'] as double,
            ));
            final p2 = _mapController.camera.project(latlong2.LatLng(
              pt2['latitude'] as double,
              pt2['longitude'] as double,
            ));

            final double dx = p2.x - p1.x;
            final double dy = p2.y - p1.y;
            final double lenSq = dx * dx + dy * dy;
            
            double dist;
            if (lenSq == 0) {
              final double sx = tapPos.x - p1.x;
              final double sy = tapPos.y - p1.y;
              dist = math.sqrt(sx * sx + sy * sy);
            } else {
              final double t = ((tapPos.x - p1.x) * dx + (tapPos.y - p1.y) * dy) / lenSq;
              final double tClamped = t.clamp(0.0, 1.0);
              final double cx = p1.x + tClamped * dx;
              final double cy = p1.y + tClamped * dy;
              final double sx = tapPos.x - cx;
              final double sy = tapPos.y - cy;
              dist = math.sqrt(sx * sx + sy * sy);
            }

            if (dist < 25.0) {
              if (!closeObjects.contains(obj)) {
                closeObjects.add(obj);
                lineTapPoint = point;
              }
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error in _handleMapTap: $e');
    }

    setState(() {
      _selectedPins.clear();
      _selectedPins.addAll(closeObjects);
      _selectedLineTapPoint = (closeObjects.isNotEmpty && closeObjects.first['type'] == GeoObjectType.line)
          ? lineTapPoint
          : null;
    });
  }

  List<Marker> _getPinMarkers() {
    final List<Marker> markers = [];
    final activeLayer = LayerStore.activeMapLayer[_mapTitle];
    if (activeLayer == null) return markers;

    final objects = LayerStore.getObjects(activeLayer, mapContext: _mapTitle);
    final markerSize = _calculateMarkerSize(_currentMapZoom);

    for (var obj in objects) {
      if (obj['type'] == GeoObjectType.point &&
          obj['latitude'] != null &&
          obj['longitude'] != null) {
        final lat = obj['latitude'] as double;
        final lon = obj['longitude'] as double;
        final colorValue = obj['color'] as int? ?? 0xFFFF1744;
        
        final isSelected = _selectedPins.contains(obj);
        final currentSize = isSelected ? markerSize * 1.35 : markerSize;

        markers.add(
          Marker(
            point: latlong2.LatLng(lat, lon),
            width: currentSize,
            height: currentSize,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () => _handlePinTap(obj),
              child: Icon(
                Icons.location_on,
                color: Color(colorValue),
                size: currentSize,
                shadows: const [
                  Shadow(
                    color: Colors.black45,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    if (_selectedPins.isNotEmpty) {
      final firstSelected = _selectedPins.first;
      final lat = firstSelected['latitude'] as double?;
      final lon = firstSelected['longitude'] as double?;
      final anchorPoint = (lat != null && lon != null)
          ? latlong2.LatLng(lat, lon)
          : _selectedLineTapPoint;

      if (anchorPoint != null) {
        markers.add(
          Marker(
            point: anchorPoint,
            width: 220,
            height: (42.0 * _selectedPins.length) + 12.0,
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
                border: Border.all(color: DesignSystem.primary, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DesignSystem.radiusSm - 1.5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _selectedPins.map((pin) {
                    final isLast = pin == _selectedPins.last;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _openPinAttributes(pin),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.edit, color: DesignSystem.primary, size: 14),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      pin['name'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (!isLast)
                          const Divider(
                            color: Colors.white10,
                            height: 1,
                            thickness: 1,
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      }
    }

    // Si estamos en modo de medición, agregar marcadores para los vértices creados
    if (_isMeasuringMode) {
      for (int i = 0; i < _measuringPoints.length; i++) {
        markers.add(
          Marker(
            point: _measuringPoints[i],
            width: 12,
            height: 12,
            alignment: Alignment.center,
            child: Container(
              decoration: BoxDecoration(
                color: DesignSystem.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  List<Polyline> _getPolylines() {
    final List<Polyline> polylines = [];
    final activeLayer = LayerStore.activeMapLayer[_mapTitle];
    if (activeLayer == null && !_isMeasuringMode) return polylines;

    if (activeLayer != null) {
      final objects = LayerStore.getObjects(activeLayer, mapContext: _mapTitle);
      for (var obj in objects) {
        if (obj['type'] == GeoObjectType.line && obj['points'] != null) {
          final pts = obj['points'] as List;
          final List<latlong2.LatLng> latLngList = [];
          for (var pt in pts) {
            final lat = pt['latitude'] as double?;
            final lon = pt['longitude'] as double?;
            if (lat != null && lon != null) {
              latLngList.add(latlong2.LatLng(lat, lon));
            }
          }
          if (latLngList.isNotEmpty) {
            final colorValue = obj['color'] as int? ?? 0xFFFFA726;
            polylines.add(
              Polyline(
                points: latLngList,
                color: Color(colorValue),
                strokeWidth: 4.0,
              ),
            );
          }
        }
      }
    }

    if (_isMeasuringMode && _measuringPoints.isNotEmpty) {
      final currentCenter = _getSafeCenter();
      polylines.add(
        Polyline(
          points: [..._measuringPoints, currentCenter],
          color: DesignSystem.primary.withOpacity(0.8),
          strokeWidth: 3.5,
        ),
      );
    }

    return polylines;
  }

  void _handlePlacePin() {
    final center = _currentMapCenter ?? (() {
      try {
        return _mapController.camera.center;
      } catch (_) {
        return const latlong2.LatLng(8.623083, -73.732583);
      }
    })();
    final double lat = center.latitude;
    final double lon = center.longitude;

    String? activeLayer = LayerStore.activeMapLayer[_mapTitle];
    if (activeLayer == null) {
      // Buscar si ya tiene capas vinculadas
      final existingLayers = LayerStore.getLayers(_mapTitle);
      if (existingLayers.isNotEmpty) {
        activeLayer = existingLayers.first['title'];
        LayerStore.activeMapLayer[_mapTitle] = activeLayer;
      } else {
        // Buscar un nombre único como "Capa 1", "Capa 2", etc. a nivel global
        int i = 1;
        String candidate = 'Capa $i';
        while (LayerStore.layers.any((l) => l['title'].toString().toLowerCase() == candidate.toLowerCase())) {
          i++;
          candidate = 'Capa $i';
        }
        activeLayer = candidate;
        LayerStore.initializeLayer(activeLayer, mapContext: _mapTitle);
        existingLayers.add({'title': activeLayer, 'objects': 0});
        LayerStore.activeMapLayer[_mapTitle] = activeLayer;
      }
    }

    final objects = LayerStore.getObjects(activeLayer!, mapContext: _mapTitle);
    final pointsCount = objects.where((obj) => obj['type'] == GeoObjectType.point).length;
    final defaultPointName = 'Punto ${pointsCount + 1}';

    final controller = TextEditingController(text: defaultPointName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DesignSystem.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
        ),
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Colors.redAccent),
            SizedBox(width: 12),
            Text(
              'Nuevo Marcador',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingresa un nombre para el punto en la mira verde:',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nombre del punto',
                labelStyle: const TextStyle(color: DesignSystem.primary),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Coordenadas: ${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}',
              style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 4),
            Text(
              'Capa de destino: $activeLayer',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
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
              final pointName = controller.text.trim();
              if (pointName.isEmpty) return;

              setState(() {
                LayerStore.addObject(
                  activeLayer!,
                  {
                    'name': pointName,
                    'type': GeoObjectType.point,
                    'value': 'Lat: ${lat.toStringAsFixed(6)}, Lon: ${lon.toStringAsFixed(6)}',
                    'latitude': lat,
                    'longitude': lon,
                  },
                  mapContext: _mapTitle,
                );
              });

              Navigator.pop(context);

              _showTopBanner(
                'Marcador "$pointName" guardado en "$activeLayer"',
                const Color(0xFF388E3C),
              );
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

  Uint8List? _mapImageBytes;

  Future<void> _loadMap() async {
    final service = MapDataService();
    _mapTitle = service.currentMapTitle ?? 'Mapa';
    _coordinateFormat = GeoreferenceService().getCoordinateFormat(_mapTitle);
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
            _coordinateFormat = GeoreferenceService().getCoordinateFormat(_mapTitle);
          });
          return;
        }

        final document = await PdfDocument.openData(bytes);
        final page = await document.getPage(1);

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
          _coordinateFormat = GeoreferenceService().getCoordinateFormat(_mapTitle);
        });
      } catch (e) {
        debugPrint('Error al abrir el PDF: $e');
      }
    } else {
      debugPrint('El archivo no contiene datos válidos.');
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
    _bannerTimer?.cancel();
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
                        onTap: (tapPosition, point) {
                          _handleMapTap(point);
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
                        PolylineLayer(
                          polylines: _getPolylines(),
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
                                    child: IgnorePointer(
                                      child: UserLocationMarker(heading: _currentUserLocation?.heading ?? 0),
                                    ),
                                  ),
                                ]
                              : [],
                        ),
                        MarkerLayer(
                          markers: _getPinMarkers(),
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
              onTap: _handlePlacePin,
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
                    GestureDetector(
                      onTap: _toggleMeasuringMode,
                      child: Icon(
                        Icons.straighten,
                        color: _isMeasuringMode ? Colors.redAccent : DesignSystem.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (_isMeasuringMode) ...[
                      Expanded(
                        child: Center(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: DesignSystem.primary,
                              side: const BorderSide(color: DesignSystem.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            onPressed: _addMeasuringPoint,
                            icon: const Icon(Icons.add, size: 16),
                            label: Text(
                              _measuringPoints.isEmpty
                                  ? 'Añadir inicio'
                                  : 'Añadir intersección (${_formatLength(_calculateGeodesicLength([..._measuringPoints, _getSafeCenter()]))})',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_measuringPoints.isNotEmpty)
                        GestureDetector(
                          onTap: _saveMeasuringLine,
                          child: const Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: _openMapLayers,
                          child: const Icon(
                            Icons.layers_outlined,
                            color: Colors.white24,
                          ),
                        ),
                    ] else ...[
                      Expanded(
                        child: GestureDetector(
                          onVerticalDragStart: (_) {
                            _dragDistance = 0.0;
                          },
                          onVerticalDragUpdate: (details) {
                            _dragDistance += details.primaryDelta ?? 0.0;
                            if (_dragDistance < -20) {
                              _dragDistance = 0.0;
                              _showCoordinateFormatSelector(context);
                            }
                          },
                          onVerticalDragEnd: (details) {
                            if (details.primaryVelocity != null && details.primaryVelocity! < -100) {
                              _showCoordinateFormatSelector(context);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F1F1F),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  centerLatLon != null
                                      ? GeoreferenceService().formatCoordinates(
                                          centerLatLon['lat']!,
                                          centerLatLon['lon']!,
                                          _coordinateFormat,
                                        )
                                      : (GeoreferenceService().hasCalibrationFor(
                                               _mapTitle,
                                             )
                                             ? 'Calculando...'
                                             : 'NO REFERENCIADO'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
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
                  ],
                ),
              ),
            ),
          ),
          if (_bannerMessage != null)
            Positioned(
              top: 16,
              left: 32,
              right: 32,
              child: SafeArea(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _bannerColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      _bannerMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }


  void _showCoordinateFormatSelector(BuildContext context) {
    if (_isBottomSheetOpen) return;
    _isBottomSheetOpen = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(color: Colors.white10, width: 1),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle de arrastre
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Sistema de Coordenadas',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(color: Colors.white10),
                    _buildBottomSheetItem(context, 'DD', 'Grados Decimales (DD)', setModalState),
                    _buildBottomSheetItem(context, 'DM', 'Grados y Minutos (DM)', setModalState),
                    _buildBottomSheetItem(context, 'DMS', 'Grados, Minutos y Segundos (DMS)', setModalState),
                    _buildBottomSheetItem(context, 'UTM', 'UTM (WGS84)', setModalState),
                    _buildBottomSheetItem(context, 'ON', 'Origen Nacional (EPSG:9377)', setModalState),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      _isBottomSheetOpen = false;
    });
  }

  Widget _buildBottomSheetItem(BuildContext context, String value, String label, StateSetter setModalState) {
    final bool isSelected = _coordinateFormat == value;
    return InkWell(
      onTap: () {
        setState(() {
          _coordinateFormat = value;
          GeoreferenceService().setCoordinateFormat(_mapTitle, value);
        });
        setModalState(() {});
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? DesignSystem.primary : Colors.white70,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: DesignSystem.primary,
                size: 20,
              )
            else
              const Icon(
                Icons.circle_outlined,
                color: Colors.white24,
                size: 20,
              ),
          ],
        ),
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
