import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class MapPersistenceService {
  static final MapPersistenceService _instance = MapPersistenceService._internal();
  factory MapPersistenceService() => _instance;
  MapPersistenceService._internal();

  Future<Directory> get _mapsDir async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docDir.path}/imported_maps');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> get _thumbnailsDir async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docDir.path}/map_thumbnails');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> get _metadataFile async {
    final docDir = await getApplicationDocumentsDirectory();
    return File('${docDir.path}/maps_metadata.json');
  }

  // Guardar mapa en almacenamiento local
  Future<void> saveMap(String name, Uint8List pdfBytes, Uint8List? thumbnailBytes, String date) async {
    try {
      // 1. Guardar PDF bytes
      final mapsDir = await _mapsDir;
      final pdfFile = File('${mapsDir.path}/$name');
      await pdfFile.writeAsBytes(pdfBytes);
      
      // 2. Guardar Thumbnail bytes si existe
      if (thumbnailBytes != null) {
        final thumbnailsDir = await _thumbnailsDir;
        final thumbFile = File('${thumbnailsDir.path}/$name.png');
        await thumbFile.writeAsBytes(thumbnailBytes);
      }
      
      // 3. Guardar en Metadatos
      await _addMetadata(name, date, thumbnailBytes != null);
      debugPrint('Mapa "$name" guardado persistentemente en disco.');
    } catch (e) {
      debugPrint('Error al guardar mapa persistentemente: $e');
    }
  }

  // Agregar mapa al JSON de metadatos
  Future<void> _addMetadata(String name, String date, bool hasThumbnail) async {
    try {
      final file = await _metadataFile;
      List<dynamic> list = [];
      if (await file.exists()) {
        final content = await file.readAsString();
        list = jsonDecode(content) as List<dynamic>;
      }
      
      // Evitar duplicados
      list.removeWhere((item) => item['title'] == name);
      
      list.insert(0, {
        'title': name,
        'date': date,
        'hasThumbnail': hasThumbnail,
      });
      
      await file.writeAsString(jsonEncode(list));
    } catch (e) {
      debugPrint('Error al actualizar metadatos: $e');
    }
  }

  // Cargar mapas guardados en disco
  Future<List<Map<String, dynamic>>> loadSavedMaps(Map<String, Uint8List> bytesCache) async {
    final List<Map<String, dynamic>> maps = [];
    try {
      final file = await _metadataFile;
      if (!await file.exists()) return maps;
      
      final content = await file.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      
      final mapsDir = await _mapsDir;
      final thumbnailsDir = await _thumbnailsDir;
      
      for (var item in list) {
        final name = item['title'] as String;
        final date = item['date'] as String;
        final hasThumbnail = item['hasThumbnail'] as bool? ?? false;
        
        // Leer bytes del PDF
        final pdfFile = File('${mapsDir.path}/$name');
        if (await pdfFile.exists()) {
          final bytes = await pdfFile.readAsBytes();
          bytesCache[name] = bytes;
          
          // Leer thumbnail bytes
          Uint8List? thumbnail;
          if (hasThumbnail) {
            final thumbFile = File('${thumbnailsDir.path}/$name.png');
            if (await thumbFile.exists()) {
              thumbnail = await thumbFile.readAsBytes();
            }
          }
          
          maps.add({
            'title': name,
            'date': date,
            'thumbnail': thumbnail,
          });
        }
      }
      debugPrint('${maps.length} mapas cargados persistentemente desde disco.');
    } catch (e) {
      debugPrint('Error al cargar mapas guardados: $e');
    }
    return maps;
  }

  // Eliminar mapa persistentemente del disco
  Future<void> deleteMap(String name) async {
    try {
      // 1. Eliminar PDF
      final mapsDir = await _mapsDir;
      final pdfFile = File('${mapsDir.path}/$name');
      if (await pdfFile.exists()) {
        await pdfFile.delete();
      }
      
      // 2. Eliminar Thumbnail
      final thumbnailsDir = await _thumbnailsDir;
      final thumbFile = File('${thumbnailsDir.path}/$name.png');
      if (await thumbFile.exists()) {
        await thumbFile.delete();
      }
      
      // 3. Quitar de Metadatos
      final file = await _metadataFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        final list = jsonDecode(content) as List<dynamic>;
        list.removeWhere((item) => item['title'] == name);
        await file.writeAsString(jsonEncode(list));
      }
      debugPrint('Mapa "$name" eliminado persistentemente del disco.');
    } catch (e) {
      debugPrint('Error al eliminar mapa persistentemente: $e');
    }
  }
}
