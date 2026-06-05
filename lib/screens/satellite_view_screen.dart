import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/user_location_service.dart';
import '../theme/design_system.dart';
import '../widgets/sidebar_menu.dart';
import '../widgets/user_location_marker.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import '../services/layer_store.dart';
import '../services/georeference_service.dart';
import '../widgets/object_list_item.dart'; // Para GeoObjectType
import 'object_attributes_screen.dart'; // Para navegar a los atributos del marcador

class SatelliteViewScreen extends StatefulWidget {
  const SatelliteViewScreen({super.key});

  @override
  State<SatelliteViewScreen> createState() => _SatelliteViewScreenState();
}

class _SatelliteViewScreenState extends State<SatelliteViewScreen> {
  final MapController _mapController = MapController();

  static LatLng? _lastLocation;
  static double _lastZoom = 13.0;
  static double _lastHeading = 0.0;

  late LatLng _currentLocation;
  late double _heading;
  late bool _initialLocationSet;

  StreamSubscription<UserLocationData>? _locationSubscription;
  StreamSubscription<MapEvent>? _mapEventSubscription;

  // --- VARIABLES DE ESTADO PARA HERRAMIENTAS DE MAPA ---
  final String _mapTitle = 'satellite';
  String _coordinateFormat = 'DD';
  bool _isMeasuringMode = false;
  final List<LatLng> _measuringPoints = [];
  LatLng? _selectedLineTapPoint;
  final Set<Map<String, dynamic>> _selectedPins = {};

  LatLng? _currentMapCenter;
  double _currentMapZoom = 13.0;

  // Para notificaciones flotantes superiores (Banner)
  Timer? _bannerTimer;
  String? _bannerMessage;
  Color? _bannerColor;

  double _dragDistance = 0.0;
  bool _isBottomSheetOpen = false;

  @override
  void initState() {
    super.initState();
    final lastLoc = UserLocationService().lastData;
    if (lastLoc != null) {
      _currentLocation = LatLng(lastLoc.latitude, lastLoc.longitude);
      _heading = lastLoc.heading ?? 0.0;
      _lastLocation = _currentLocation;
      _lastHeading = _heading;
    } else {
      _currentLocation = _lastLocation ?? const LatLng(8.623083, -73.732583);
      _heading = _lastHeading;
    }
    _initialLocationSet = _lastLocation != null;
    _currentMapCenter = _lastLocation ?? const LatLng(8.623083, -73.732583);
    _currentMapZoom = _lastZoom;

    _initLocationTracking();
    
    // Cargar formato de coordenadas preferido
    _coordinateFormat = GeoreferenceService().getCoordinateFormat(_mapTitle);

    // Escuchar eventos de la cámara del mapa
    _mapEventSubscription = _mapController.mapEventStream.listen((event) {
      if (mounted) {
        setState(() {
          _currentMapCenter = event.camera.center;
          _currentMapZoom = event.camera.zoom;
          _lastLocation = event.camera.center;
          _lastZoom = event.camera.zoom;
        });
      }
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapEventSubscription?.cancel();
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _safeMove(LatLng center, double zoom) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _mapController.move(center, zoom);
      } catch (_) {}
    });
  }

  void _initLocationTracking() {
    UserLocationService().startTracking();
    _locationSubscription = UserLocationService().locationStream.listen((data) {
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(data.latitude, data.longitude);
        if (data.heading != null) {
          _heading = data.heading!;
          _lastHeading = _heading;
        }

        _lastLocation = _currentLocation;

        // Auto centrar como Google Maps la primera vez que se tiene señal GPS
        if (!_initialLocationSet) {
          _initialLocationSet = true;
          _lastZoom = 17.0;
          _safeMove(_currentLocation, 17.0);
        }
      });
    });
  }

  // --- MÉTODOS AUXILIARES Y GEOMETRÍA ---
  LatLng _getSafeCenter() {
    if (_currentMapCenter != null) return _currentMapCenter!;
    try {
      return _mapController.camera.center;
    } catch (_) {
      return const LatLng(8.623083, -73.732583);
    }
  }

  double _calculateGeodesicLength(List<LatLng> points) {
    double total = 0.0;
    const double r = 6371000; // Radio terrestre en metros
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

  bool get _canClosePolygon {
    if (!_isMeasuringMode || _measuringPoints.length < 3) return false;
    try {
      final firstPoint = _measuringPoints.first;
      final currentCenter = _getSafeCenter();
      
      final p1 = _mapController.camera.project(firstPoint);
      final p2 = _mapController.camera.project(currentCenter);
      
      final dx = p2.x - p1.x;
      final dy = p2.y - p1.y;
      final dist = math.sqrt(dx * dx + dy * dy);
      
      return dist < 35.0;
    } catch (_) {
      return false;
    }
  }

  double _calculatePolygonArea(List<LatLng> points) {
    if (points.length < 3) return 0.0;
    
    double sumLat = 0.0;
    for (var pt in points) {
      sumLat += pt.latitude;
    }
    final double avgLat = (sumLat / points.length) * math.pi / 180.0;
    
    const double r = 6371000.0;
    final List<math.Point<double>> projectedPoints = [];
    
    for (var pt in points) {
      final x = r * (pt.longitude * math.pi / 180.0) * math.cos(avgLat);
      final y = r * (pt.latitude * math.pi / 180.0);
      projectedPoints.add(math.Point(x, y));
    }
    
    double area = 0.0;
    int n = projectedPoints.length;
    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;
      area += projectedPoints[i].x * projectedPoints[j].y;
      area -= projectedPoints[j].x * projectedPoints[i].y;
    }
    return (area.abs() / 2.0);
  }

  String _formatAreaWithUnit(double metersSq, String unit) {
    switch (unit) {
      case 'km²':
        return '${(metersSq / 1000000.0).toStringAsFixed(4)} km²';
      case 'ha':
        return '${(metersSq / 10000.0).toStringAsFixed(3)} ha';
      case 'ac':
        return '${(metersSq / 4046.8564).toStringAsFixed(3)} ac';
      case 'ft²':
        return '${(metersSq * 10.7639).toStringAsFixed(2)} ft²';
      case 'yd²':
        return '${(metersSq * 1.19599).toStringAsFixed(2)} yd²';
      case 'mi²':
        return '${(metersSq / 2589988.11).toStringAsFixed(5)} mi²';
      case 'cm²':
        return '${(metersSq * 10000.0).toStringAsFixed(0)} cm²';
      case 'm²':
      default:
        return '${metersSq.toStringAsFixed(2)} m²';
    }
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

    final List<LatLng> finalPoints = List.from(_measuringPoints);
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

  void _saveMeasuringPolygon() {
    if (_measuringPoints.length < 3) return;

    final List<LatLng> finalPoints = List.from(_measuringPoints);
    final double areaM2 = _calculatePolygonArea(finalPoints);
    final formattedArea = _formatAreaWithUnit(areaM2, 'm²');

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
    final polygonsCount = objects.where((obj) => obj['type'] == GeoObjectType.polygon).length;
    final defaultPolygonName = 'Polígono ${polygonsCount + 1}';

    final controller = TextEditingController(text: defaultPolygonName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DesignSystem.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
        ),
        title: const Row(
          children: [
            Icon(Icons.pentagon_outlined, color: Colors.orangeAccent),
            SizedBox(width: 12),
            Text(
              'Nuevo Polígono',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingresa un nombre para el polígono creado:',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nombre del polígono',
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
              'Área total: $formattedArea',
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
              final polyName = controller.text.trim();
              if (polyName.isEmpty) return;

              setState(() {
                LayerStore.addObject(
                  activeLayer!,
                  {
                    'name': polyName,
                    'type': GeoObjectType.polygon,
                    'value': formattedArea,
                    'points': finalPoints.map((p) => {
                      'latitude': p.latitude,
                      'longitude': p.longitude,
                    }).toList(),
                    'unit': 'm²',
                    'color': 0xFFFFA726,
                  },
                  mapContext: _mapTitle,
                );
                _isMeasuringMode = false;
                _measuringPoints.clear();
              });

              Navigator.pop(context);

              _showTopBanner(
                'Polígono "$polyName" guardado en "$activeLayer"',
                const Color(0xFF388E3C),
              );
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

  void _handlePlacePin() {
    final center = _getSafeCenter();
    final double lat = center.latitude;
    final double lon = center.longitude;

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

  void _handlePinTap(Map<String, dynamic> clickedObj) {
    final activeLayer = LayerStore.activeMapLayer[_mapTitle];
    if (activeLayer == null) return;
    final objects = LayerStore.getObjects(activeLayer, mapContext: _mapTitle);

    final List<Map<String, dynamic>> closePins = [];
    
    try {
      final clickedLat = clickedObj['latitude'] as double;
      final clickedLon = clickedObj['longitude'] as double;
      final clickedPos = _mapController.camera.project(LatLng(clickedLat, clickedLon));

      for (var obj in objects) {
        if (obj['type'] == GeoObjectType.point &&
            obj['latitude'] != null &&
            obj['longitude'] != null) {
          final lat = obj['latitude'] as double;
          final lon = obj['longitude'] as double;
          final pos = _mapController.camera.project(LatLng(lat, lon));
          
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

  void _handleMapTap(LatLng point) {
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
    LatLng? lineTapPoint;

    try {
      final tapPos = _mapController.camera.project(point);

      for (var obj in objects) {
        if (obj['type'] == GeoObjectType.point &&
            obj['latitude'] != null &&
            obj['longitude'] != null) {
          final lat = obj['latitude'] as double;
          final lon = obj['longitude'] as double;
          final pos = _mapController.camera.project(LatLng(lat, lon));
          
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
            
            final p1 = _mapController.camera.project(LatLng(
              pt1['latitude'] as double,
              pt1['longitude'] as double,
            ));
            final p2 = _mapController.camera.project(LatLng(
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
        } else if (obj['type'] == GeoObjectType.polygon && obj['points'] != null) {
          final pts = obj['points'] as List;
          final List<math.Point<double>> projectedVertices = [];
          bool isNearBoundary = false;

          for (int i = 0; i < pts.length; i++) {
            final pt = pts[i];
            if (pt['latitude'] == null || pt['longitude'] == null) continue;
            final pNode = _mapController.camera.project(LatLng(
              pt['latitude'] as double,
              pt['longitude'] as double,
            ));
            projectedVertices.add(math.Point(pNode.x, pNode.y));
          }

          for (int i = 0; i < projectedVertices.length; i++) {
            final p1 = projectedVertices[i];
            final p2 = projectedVertices[(i + 1) % projectedVertices.length];

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
              isNearBoundary = true;
              break;
            }
          }

          final isInside = _isPointInPolygon(math.Point(tapPos.x, tapPos.y), projectedVertices);

          if (isInside || isNearBoundary) {
            if (!closeObjects.contains(obj)) {
              closeObjects.add(obj);
              lineTapPoint = point;
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
      _selectedLineTapPoint = (closeObjects.isNotEmpty &&
              (closeObjects.first['type'] == GeoObjectType.line || closeObjects.first['type'] == GeoObjectType.polygon))
          ? lineTapPoint
          : null;
    });
  }

  bool _isPointInPolygon(math.Point<double> p, List<math.Point<double>> vertices) {
    bool isInside = false;
    int j = vertices.length - 1;
    for (int i = 0; i < vertices.length; i++) {
      if ((vertices[i].y < p.y && vertices[j].y >= p.y || vertices[j].y < p.y && vertices[i].y >= p.y) &&
          (vertices[i].x + (p.y - vertices[i].y) / (vertices[j].y - vertices[i].y) * (vertices[j].x - vertices[i].x) < p.x)) {
        isInside = !isInside;
      }
      j = i;
    }
    return isInside;
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

  void _openMapLayers() {
    Navigator.pushNamed(
      context,
      '/map-layers',
      arguments: _mapTitle,
    ).then((_) => setState(() {}));
  }

  void _recentrateGPS() {
    if (_currentLocation.latitude == 0) return;
    _mapController.move(
      LatLng(_currentLocation.latitude, _currentLocation.longitude),
      _mapController.camera.zoom,
    );
    _showTopBanner(
      'Cámara centrada en tu posición GPS',
      const Color(0xFF388E3C),
    );
  }

  double _calculateMarkerSize(double zoom) {
    double size = 36.0 + (zoom - 15.0) * 3.0;
    return size.clamp(16.0, 64.0);
  }

  String _getObjectSubtitle(Map<String, dynamic> pin) {
    if (pin['type'] == GeoObjectType.point) {
      final lat = pin['latitude'] as double?;
      final lon = pin['longitude'] as double?;
      if (lat != null && lon != null) {
        return GeoreferenceService().formatCoordinates(lat, lon, _coordinateFormat);
      }
    }
    return pin['value'] as String? ?? '';
  }

  List<Polygon> _getPolygons() {
    final List<Polygon> polygons = [];
    final activeLayer = LayerStore.activeMapLayer[_mapTitle];
    if (activeLayer == null && !_isMeasuringMode) return polygons;

    if (activeLayer != null) {
      final objects = LayerStore.getObjects(activeLayer, mapContext: _mapTitle);
      for (var obj in objects) {
        if (obj['type'] == GeoObjectType.polygon && obj['points'] != null) {
          final pts = obj['points'] as List;
          final List<LatLng> latLngList = [];
          for (var pt in pts) {
            final lat = pt['latitude'] as double?;
            final lon = pt['longitude'] as double?;
            if (lat != null && lon != null) {
              latLngList.add(LatLng(lat, lon));
            }
          }
          if (latLngList.isNotEmpty) {
            final colorValue = obj['color'] as int? ?? 0xFFFFA726;
            polygons.add(
              Polygon(
                points: latLngList,
                borderColor: Color(colorValue),
                borderStrokeWidth: 3.0,
                color: Color(colorValue).withValues(alpha: 0.25),
              ),
            );
          }
        }
      }
    }

    if (_isMeasuringMode && _canClosePolygon && _measuringPoints.length >= 3) {
      polygons.add(
        Polygon(
          points: [..._measuringPoints, _getSafeCenter()],
          borderColor: Colors.transparent,
          color: DesignSystem.primary.withValues(alpha: 0.15),
        ),
      );
    }

    return polygons;
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
          final List<LatLng> latLngList = [];
          for (var pt in pts) {
            final lat = pt['latitude'] as double?;
            final lon = pt['longitude'] as double?;
            if (lat != null && lon != null) {
              latLngList.add(LatLng(lat, lon));
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
          color: DesignSystem.primary.withValues(alpha: 0.8),
          strokeWidth: 3.5,
        ),
      );
    }

    return polylines;
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
            point: LatLng(lat, lon),
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
          ? LatLng(lat, lon)
          : _selectedLineTapPoint;

      if (anchorPoint != null) {
        markers.add(
          Marker(
            point: anchorPoint,
            width: 230,
            height: (56.0 * _selectedPins.length) + 8.0,
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(
                  color: DesignSystem.primary.withValues(alpha: 0.85),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _selectedPins.map((pin) {
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
                                  Icon(
                                    pin['type'] == GeoObjectType.point
                                        ? Icons.location_on
                                        : (pin['type'] == GeoObjectType.line ? Icons.timeline : Icons.pentagon_outlined),
                                    color: Color(pin['color'] as int? ?? 0xFFFF1744),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          pin['name'] as String? ?? 'Sin nombre',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _getObjectSubtitle(pin),
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 10,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.edit,
                                    color: DesignSystem.primary,
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (pin != _selectedPins.last)
                          Container(height: 0.5, color: Colors.white10),
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

    return markers;
  }

  // --- COMPONENTES DE UI ---
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

  Widget _buildToolButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: DesignSystem.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
          border: Border.all(color: Colors.white10),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
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
      drawer: const SidebarMenu(),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _lastLocation ?? const LatLng(8.623083, -73.732583),
              initialZoom: _lastZoom,
              onTap: (tapPosition, point) {
                _handleMapTap(point);
              },
              onPositionChanged: (camera, hasGesture) {
                setState(() {
                  _currentMapCenter = camera.center;
                  _currentMapZoom = camera.zoom;
                  _lastLocation = camera.center;
                  _lastZoom = camera.zoom;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.navimap.app',
                tileProvider: CancellableNetworkTileProvider(silenceExceptions: true),
              ),
              PolygonLayer(
                polygons: _getPolygons(),
              ),
              PolylineLayer(
                polylines: _getPolylines(),
              ),
              MarkerLayer(
                markers: _currentLocation.latitude != 0
                    ? [
                        Marker(
                          point: _currentLocation,
                          width: 60,
                          height: 60,
                          child: IgnorePointer(
                            child: UserLocationMarker(heading: _heading),
                          ),
                        ),
                      ]
                    : [],
              ),
              MarkerLayer(
                markers: _getPinMarkers(),
              ),
            ],
          ),
          
          // --- RETÍCULA / MIRILLA CENTRAL ESTÁTICA ---
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

          // --- BOTÓN DE RETROCESO (TOP LEFT) ---
          Positioned(
            top: 50,
            left: 20,
            child: _buildToolButton(Icons.arrow_back, () {
              Navigator.pushReplacementNamed(context, '/');
            }),
          ),

          // --- BOTONES GPS Y PIN (BOTTOM RIGHT) ---
          Positioned(
            bottom: 160,
            right: 20,
            child: GestureDetector(
              onTap: _recentrateGPS,
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

          // --- PANEL DE NOTIFICACIÓN SUPERIOR (BANNER) ---
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

          // --- BARRA INFERIOR DE ACCIONES ---
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
                      if (_canClosePolygon) ...[
                        GestureDetector(
                          onTap: _saveMeasuringPolygon,
                          child: const Icon(
                            Icons.pentagon_outlined,
                            color: DesignSystem.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
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
                          onLongPress: () async {
                            if (centerLatLon != null) {
                              final String coordText = GeoreferenceService().formatCoordinates(
                                centerLatLon['lat']!,
                                centerLatLon['lon']!,
                                _coordinateFormat,
                              );
                              await Clipboard.setData(ClipboardData(text: coordText));
                              _showTopBanner(
                                'Coordenadas copiadas al portapapeles',
                                const Color(0xFF388E3C),
                              );
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
                                      : 'Calculando...',
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
        ],
      ),
    );
  }
}
