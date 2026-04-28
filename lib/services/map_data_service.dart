import 'dart:typed_data';

class MapDataService {
  static final MapDataService _instance = MapDataService._internal();
  factory MapDataService() => _instance;
  MapDataService._internal();

  Uint8List? _currentMapBytes;
  String? _currentMapTitle;

  void setCurrentMap(String title, Uint8List? bytes) {
    _currentMapTitle = title;
    _currentMapBytes = bytes;
  }

  Uint8List? get currentMapBytes => _currentMapBytes;
  String? get currentMapTitle => _currentMapTitle;
}
