import 'dart:typed_data';

class MapDataService {
  static final MapDataService _instance = MapDataService._internal();
  factory MapDataService() => _instance;
  MapDataService._internal();

  Uint8List? _currentMapBytes;
  String? _currentMapTitle;

  // Caché en memoria para imágenes renderizadas y sus dimensiones
  final Map<String, Uint8List> _renderedPngCache = {};
  final Map<String, double> _renderedWidthCache = {};
  final Map<String, double> _renderedHeightCache = {};

  void setCurrentMap(String title, Uint8List? bytes) {
    _currentMapTitle = title;
    _currentMapBytes = bytes;
  }

  Uint8List? get currentMapBytes => _currentMapBytes;
  String? get currentMapTitle => _currentMapTitle;

  // Métodos de acceso al caché
  Uint8List? getCachedPng(String title) => _renderedPngCache[title];
  double? getCachedWidth(String title) => _renderedWidthCache[title];
  double? getCachedHeight(String title) => _renderedHeightCache[title];

  void cacheRenderedMap(String title, Uint8List pngBytes, double width, double height) {
    _renderedPngCache[title] = pngBytes;
    _renderedWidthCache[title] = width;
    _renderedHeightCache[title] = height;
  }
}
