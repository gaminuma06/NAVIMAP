import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart' as xml;

class GeoDataService {
  Future<File?> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['geojson', 'kml', 'gpkg'],
    );

    if (result != null) {
      return File(result.files.single.path!);
    }
    return null;
  }

  // Cargar GeoJSON
  Future<Map<String, dynamic>> loadGeoJson(File file) async {
    final String content = await file.readAsString();
    return json.decode(content);
  }

  // Cargar KML (Simplificado para extraer puntos)
  Future<List<LatLng>> loadKmlPoints(File file) async {
    final String content = await file.readAsString();
    final document = xml.XmlDocument.parse(content);
    final coordinates = document.findAllElements('coordinates');

    List<LatLng> points = [];
    for (var node in coordinates) {
      final text = node.innerText.trim();
      final parts = text.split(RegExp(r'\s+'));
      for (var part in parts) {
        final coords = part.split(',');
        if (coords.length >= 2) {
          points.add(LatLng(double.parse(coords[1]), double.parse(coords[0])));
        }
      }
    }
    return points;
  }

  // La implementación de GPKG requeriría sqflite para abrir la base de datos
  // y consultar las tablas spatial_ref_sys y las capas vectoriales.
}
