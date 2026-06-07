import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class UserLocationData {
  final double latitude;
  final double longitude;
  final double? heading;
  final double accuracy;

  UserLocationData({
    required this.latitude,
    required this.longitude,
    this.heading,
    required this.accuracy,
  });
}

class UserLocationService {
  static final UserLocationService _instance = UserLocationService._internal();
  factory UserLocationService() => _instance;
  UserLocationService._internal();

  StreamController<UserLocationData> _locationController =
      StreamController<UserLocationData>.broadcast();
  Stream<UserLocationData> get locationStream => _locationController.stream;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;

  double? _currentHeading;

  Future<bool> checkPermissions() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return false;
      }

      if (permission == LocationPermission.deniedForever) return false;
      return true;
    } catch (e) {
      return false;
    }
  }

  UserLocationData? _lastData;
  UserLocationData? get lastData => _lastData;

  void _emitLocation(UserLocationData data) {
    _lastData = data;
    if (!_locationController.isClosed) {
      _locationController.add(data);
    }
  }

  void startTracking() async {
    // Si ya estamos escuchando, emitir el último dato en la siguiente microtarea para evitar condiciones de carrera
    if (_positionSubscription != null) {
      if (_lastData != null) {
        Future.microtask(() {
          if (!_locationController.isClosed) {
            _locationController.add(_lastData!);
          }
        });
      }
      return;
    }

    final hasPermission = await checkPermissions();

    if (!hasPermission) {
      // Usar exactamente la coordenada que obtuviste en Avenza
      // 8°37'23.1" N, 73°43'57.3" W -> 8.623083, -73.732583
      simulateLocation(8.623083, -73.732583, heading: 0);
      return;
    }

    // Escuchar Brújula
    _compassSubscription = FlutterCompass.events?.listen((event) {
      _currentHeading = event.heading;
    });

    // Obtener última posición conocida para mostrarla instantáneamente
    try {
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        _emitLocation(
          UserLocationData(
            latitude: lastPos.latitude,
            longitude: lastPos.longitude,
            heading: _currentHeading,
            accuracy: lastPos.accuracy,
          ),
        );
      }
    } catch (_) {}

    // Escuchar GPS Real
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 1,
          ),
        ).listen(
          (Position position) {
            _emitLocation(
              UserLocationData(
                latitude: position.latitude,
                longitude: position.longitude,
                heading: _currentHeading,
                accuracy: position.accuracy,
              ),
            );
          },
          onError: (error) {
            debugPrint('Geolocator position stream error: $error');
          },
        );
  }

  void simulateLocation(double lat, double lon, {double? heading}) {
    _emitLocation(
      UserLocationData(
        latitude: lat,
        longitude: lon,
        heading: heading ?? 45.0,
        accuracy: 5.0,
      ),
    );
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _compassSubscription?.cancel();
    _positionSubscription = null;
    _compassSubscription = null;
  }
}
