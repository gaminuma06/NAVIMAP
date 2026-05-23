import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/design_system.dart';
import '../widgets/sidebar_menu.dart';
import '../widgets/user_location_marker.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

class SatelliteViewScreen extends StatefulWidget {
  const SatelliteViewScreen({super.key});

  @override
  State<SatelliteViewScreen> createState() => _SatelliteViewScreenState();
}

class _SatelliteViewScreenState extends State<SatelliteViewScreen> {
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(0, 0);
  double _heading = 0.0;
  bool _isDrawing = false;
  bool _initialLocationSet = false;
  List<LatLng> _drawPoints = [];

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Geolocator.getPositionStream().listen((Position position) {
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _heading = position.heading;

        // Auto centrar como Google Maps la primera vez que se tiene señal GPS
        if (!_initialLocationSet) {
          _initialLocationSet = true;
          _mapController.move(_currentLocation, 17.0);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const SidebarMenu(),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(0, 0),
              initialZoom: 13.0,
              onTap: (tapPosition, point) {
                if (_isDrawing) {
                  setState(() => _drawPoints.add(point));
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.navimap.app',
                tileProvider: CancellableNetworkTileProvider(silenceExceptions: true),
              ),
              if (_currentLocation.latitude != 0)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation,
                      width: 60,
                      height: 60,
                      child: UserLocationMarker(heading: _heading),
                    ),
                  ],
                ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _drawPoints,
                    color: DesignSystem.primary,
                    strokeWidth: 3,
                  ),
                ],
              ),
            ],
          ),
          // HUD
          Positioned(top: 50, left: 20, child: _buildTelemetryPanel()),
          // Top Buttons
          Positioned(
            top: 50,
            right: 20,
            child: Row(
              children: [
                _buildToolButton(Icons.menu, () {
                  Scaffold.of(context).openDrawer();
                }),
                const SizedBox(width: 12),
                _buildToolButton(Icons.arrow_back, () {
                  Navigator.pushReplacementNamed(context, '/');
                }),
              ],
            ),
          ),
          // Tool Sidebar
          Positioned(
            right: 15,
            top: 120,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: DesignSystem.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(DesignSystem.radiusDefault),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  _buildMapAction(Icons.layers_outlined, 'LAYERS', () {
                    Navigator.pushNamed(context, '/layers');
                  }),
                  const SizedBox(height: 20),
                  _buildMapAction(Icons.polyline_outlined, 'DRAW', () {
                    setState(() => _isDrawing = !_isDrawing);
                  }, active: _isDrawing),
                  const SizedBox(height: 20),
                  _buildMapAction(Icons.my_location, 'RECENTER', () {
                    _mapController.move(_currentLocation, 15);
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        backgroundColor: DesignSystem.surface,
        selectedItemColor: DesignSystem.primary,
        unselectedItemColor: Colors.white24,
        onTap: (index) {
          if (index == 0) Navigator.pushReplacementNamed(context, '/');
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: 'Biblioteca',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.satellite_alt),
            label: 'Satélite',
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: DesignSystem.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
        border: Border.all(color: DesignSystem.primary, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: DesignSystem.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text('TELEMETRY ACTIVE', style: DesignSystem.labelCaps),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'LAT: ${_currentLocation.latitude.toStringAsFixed(6)}',
            style: DesignSystem.monoData,
          ),
          Text(
            'LON: ${_currentLocation.longitude.toStringAsFixed(6)}',
            style: DesignSystem.monoData,
          ),
        ],
      ),
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

  Widget _buildMapAction(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: active ? DesignSystem.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
              border: Border.all(
                color: active ? DesignSystem.primary : Colors.white24,
              ),
            ),
            child: Icon(
              icon,
              color: active ? Colors.black : Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: DesignSystem.labelCaps.copyWith(
              fontSize: 8,
              color: active ? DesignSystem.primary : Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}
