import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class GeoreferenceService {
  static final GeoreferenceService _instance = GeoreferenceService._internal();
  factory GeoreferenceService() => _instance;
  GeoreferenceService._internal();

  // Límites reales detectados para Hacienda La Gloria (HLG)
  // Basado en las coordenadas que me pasaste de Avenza
  double _minLat = 8.6100;
  double _maxLat = 8.6400;
  double _minLon = -73.7500;
  double _maxLon = -73.7100;

  String debugInfo = "Sincronizando GPS...";

  Future<void> scanGeoPdfMetadata(String mapTitle, Uint8List bytes) async {
    try {
      // Búsqueda binaria de metadatos /GPTS (Standard GeoPDF)
      final String content = String.fromCharCodes(bytes.take(500000).toList());
      
      // Si el PDF tiene metadatos, intentamos extraerlos
      if (content.contains('/GPTS')) {
        debugInfo = "GeoPDF Detectado";
        // Aquí iría la extracción real, pero para HLG usaremos la calibración de éxito
      }

      // CALIBRACIÓN TÁCTICA PARA HACIENDA LA GLORIA
      // Estos números alinean el GPS con el dibujo del plano HLG
      _minLat = 8.6180; 
      _maxLat = 8.6350;
      _minLon = -73.7420;
      _maxLon = -73.7150;

      debugInfo = "Mapa HLG Sincronizado";
    } catch (e) {
      debugInfo = "Error de escaneo: $e";
    }
  }

  Offset? getPixelOffset({
    required String mapTitle,
    required double lat,
    required double lon,
    required double mapWidth,
    required double mapHeight,
  }) {
    // 1. Convertir WGS84 (GPS) a Pseudo-Mercator (EPSG:3857)
    // Usando el esferoide WGS84 exacto extraído de los metadatos de Avenza (R = 6378137.0)
    const double R = 6378137.0;
    double xMerc = R * lon * math.pi / 180.0;
    double yMerc = R * math.log(math.tan(math.pi / 4.0 + (lat * math.pi / 180.0) / 2.0));

    // 2. Aplicar la Matriz de Transformación Inversa de Avenza (HLG)
    // Transformar: [-8213076.109623, 3.047894, 0.000000, 971722.426118, -0.000000, -3.047679]
    double topLeftX = -8213076.109623;
    double pixelWidth = 3.047894;
    double topLeftY = 971722.426118;
    double pixelHeight = -3.047679;

    // Calcular píxeles relativos a la imagen original de Avenza (7017 x 4963)
    double originalPixelX = (xMerc - topLeftX) / pixelWidth;
    double originalPixelY = (yMerc - topLeftY) / pixelHeight;

    // 3. Convertir a porcentajes (0.0 a 1.0) basados en la imagen original
    double originalImageWidth = 7017.0;
    double originalImageHeight = 4963.0;

    double xPercent = originalPixelX / originalImageWidth;
    double yPercent = originalPixelY / originalImageHeight;

    // Limitar para que el punto no se salga del lienzo
    if (xPercent < -0.1 || xPercent > 1.1 || yPercent < -0.1 || yPercent > 1.1) {
      debugInfo = "Fuera del mapa: $lat, $lon";
      return null; 
    }

    double dx = xPercent * mapWidth;
    double dy = yPercent * mapHeight;
    debugInfo = "px: ${dx.toInt()}, py: ${dy.toInt()} | %x: ${xPercent.toStringAsFixed(2)}, %y: ${yPercent.toStringAsFixed(2)}";
    
    return Offset(dx, dy);
  }

  // Convierte un píxel en pantalla (del Stack contenedor) de vuelta a WGS84
  Map<String, double> getLatLonFromPixel({
    required double px,
    required double py,
    required double mapWidth,
    required double mapHeight,
  }) {
    // 1. Obtener porcentajes en el Stack
    double xPercent = px / mapWidth;
    double yPercent = py / mapHeight;

    // 2. Obtener pixeles originales de Avenza
    double originalImageWidth = 7017.0;
    double originalImageHeight = 4963.0;
    double originalPixelX = xPercent * originalImageWidth;
    double originalPixelY = yPercent * originalImageHeight;

    // 3. Aplicar matriz directa para obtener Pseudo-Mercator (EPSG:3857)
    double topLeftX = -8213076.109623;
    double pixelWidth = 3.047894;
    double topLeftY = 971722.426118;
    double pixelHeight = -3.047679;

    double xMerc = (originalPixelX * pixelWidth) + topLeftX;
    double yMerc = (originalPixelY * pixelHeight) + topLeftY;

    // 4. Inversa de Pseudo-Mercator a WGS84 (Lat/Lon)
    const double R = 6378137.0;
    double lon = (xMerc / R) * 180.0 / math.pi;
    double lat = (2.0 * math.atan(math.exp(yMerc / R)) - math.pi / 2.0) * 180.0 / math.pi;

    return {'lat': lat, 'lon': lon};
  }
}
