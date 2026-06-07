import 'dart:convert' show jsonEncode, jsonDecode;
import 'dart:io' show Directory, File;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../utils/connectivity_helper.dart';

class OfflineMapService {
  final ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> downloadingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> downloadedNotifier = ValueNotifier<bool>(false);
  final Map<String, Uint8List> _webTileCache = <String, Uint8List>{};

  static final OfflineMapService _instance = OfflineMapService._internal();

  factory OfflineMapService() => _instance;

  OfflineMapService._internal();

  bool get isDownloading => downloadingNotifier.value;
  double get downloadProgress => progressNotifier.value;
  bool get isDownloaded => downloadedNotifier.value;

  double? minLat;
  double? maxLat;
  double? minLon;
  double? maxLon;

  Future<void> loadMetadata() async {
    if (kIsWeb) return;
    try {
      final path = await getOfflineTilesPath();
      final file = File('$path/metadata.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        minLat = data['minLat']?.toDouble();
        maxLat = data['maxLat']?.toDouble();
        minLon = data['minLon']?.toDouble();
        maxLon = data['maxLon']?.toDouble();
      } else {
        minLat = maxLat = minLon = maxLon = null;
      }
    } catch (e) {
      debugPrint('Error loading metadata: $e');
    }
  }

  Future<void> saveMetadata({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
  }) async {
    this.minLat = minLat;
    this.maxLat = maxLat;
    this.minLon = minLon;
    this.maxLon = maxLon;
    if (kIsWeb) return;
    try {
      final path = await getOfflineTilesPath();
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File('$path/metadata.json');
      final data = {
        'minLat': minLat,
        'maxLat': maxLat,
        'minLon': minLon,
        'maxLon': maxLon,
      };
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving metadata: $e');
    }
  }

  bool isWithinDownloadedBounds(double lat, double lon) {
    if (minLat == null || maxLat == null || minLon == null || maxLon == null) {
      return false;
    }
    return lat >= minLat! && lat <= maxLat! && lon >= minLon! && lon <= maxLon!;
  }

  Future<bool> checkInternet() async {
    if (kIsWeb) {
      return isWebOnline();
    }
    try {
      final response = await http
          .head(Uri.parse('https://mt1.google.com/generate_204'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  int estimateTileCount(LatLngBounds bounds) {
    int count = 341; // Zooms 0 a 4 globales suman 341 teselas
    final double west = bounds.west;
    final double east = bounds.east;
    final double north = bounds.north;
    final double south = bounds.south;

    for (int z = 5; z <= 16; z++) {
      final int minX = math.min(lonToTileX(west, z), lonToTileX(east, z));
      final int maxX = math.max(lonToTileX(west, z), lonToTileX(east, z));
      final int minY = math.min(latToTileY(north, z), latToTileY(south, z));
      final int maxY = math.max(latToTileY(north, z), latToTileY(south, z));
      count += (maxX - minX + 1) * (maxY - minY + 1);
    }
    return count;
  }

  Future<String> getOfflineTilesPath() async {
    if (kIsWeb) return 'web_offline_tiles';
    try {
      final docDir = await getApplicationDocumentsDirectory();
      return '${docDir.path}/offline_tiles';
    } catch (e) {
      debugPrint('Error getting directory: $e');
      return 'offline_tiles';
    }
  }

  int lonToTileX(double lon, int zoom) {
    return ((lon + 180.0) / 360.0 * (1 << zoom)).floor();
  }

  int latToTileY(double lat, int zoom) {
    final latRad = lat * math.pi / 180.0;
    return ((1.0 -
                math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
            2.0 *
            (1 << zoom))
        .floor();
  }

  Future<void> checkDownloadStatus() async {
    await loadMetadata();
    if (kIsWeb) {
      downloadedNotifier.value = _webTileCache.length > 50;
      return;
    }
    try {
      final path = await getOfflineTilesPath();
      final dir = Directory(path);
      if (await dir.exists()) {
        final list = dir.listSync(recursive: true).whereType<File>();
        if (list.length > 50) {
          downloadedNotifier.value = true;
          return;
        }
      }
    } catch (e) {
      debugPrint('Error checking download status: $e');
    }
    downloadedNotifier.value = false;
  }

  Future<void> deleteOfflineTiles() async {
    minLat = maxLat = minLon = maxLon = null;
    if (kIsWeb) {
      _webTileCache.clear();
      downloadedNotifier.value = false;
      progressNotifier.value = 0.0;
      return;
    }
    try {
      final path = await getOfflineTilesPath();
      final dir = Directory(path);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error deleting tiles: $e');
    }
    downloadedNotifier.value = false;
    progressNotifier.value = 0.0;
  }

  Future<void> downloadMap(LatLngBounds bounds) async {
    if (downloadingNotifier.value) return;
    downloadingNotifier.value = true;
    progressNotifier.value = 0.0;

    try {
      final basePath = kIsWeb
          ? 'web_offline_tiles'
          : await getOfflineTilesPath();

      final List<Map<String, dynamic>> downloadList = [];

      // 1. Planeta Completo (Zoom 0 al 4) - Descarga global
      for (int z = 0; z <= 4; z++) {
        final int maxXY = 1 << z;
        for (int x = 0; x < maxXY; x++) {
          for (int y = 0; y < maxXY; y++) {
            downloadList.add({'x': x, 'y': y, 'z': z});
          }
        }
      }

      // 2. Transición y Alta Resolución (Zoom 5 al 16) - Dentro de los límites
      final double west = bounds.west;
      final double east = bounds.east;
      final double north = bounds.north;
      final double south = bounds.south;

      for (int z = 5; z <= 16; z++) {
        final int minX = math.min(lonToTileX(west, z), lonToTileX(east, z));
        final int maxX = math.max(lonToTileX(west, z), lonToTileX(east, z));
        final int minY = math.min(latToTileY(north, z), latToTileY(south, z));
        final int maxY = math.max(latToTileY(north, z), latToTileY(south, z));

        for (int x = minX; x <= maxX; x++) {
          for (int y = minY; y <= maxY; y++) {
            final int maxXY = 1 << z;
            if (x >= 0 && x < maxXY && y >= 0 && y < maxXY) {
              downloadList.add({'x': x, 'y': y, 'z': z});
            }
          }
        }
      }

      // Guardar límites en metadatos ANTES de la descarga
      final double minLatCalculated = math.min(bounds.south, bounds.north);
      final double maxLatCalculated = math.max(bounds.south, bounds.north);
      final double minLonCalculated = math.min(bounds.west, bounds.east);
      final double maxLonCalculated = math.max(bounds.west, bounds.east);
      await saveMetadata(
        minLat: minLatCalculated,
        maxLat: maxLatCalculated,
        minLon: minLonCalculated,
        maxLon: maxLonCalculated,
      );

      int downloadedCount = 0;
      final int totalTiles = downloadList.length;

      // Descarga por lotes concurrentes de 25 peticiones simultáneas
      const int batchSize = 25;
      for (int i = 0; i < totalTiles; i += batchSize) {
        if (!downloadingNotifier.value) break;

        final batch = downloadList.sublist(
          i,
          math.min(i + batchSize, totalTiles),
        );

        await Future.wait(
          batch.map((tile) async {
            final int x = tile['x'];
            final int y = tile['y'];
            final int z = tile['z'];
            final String tileKey = '$z/$x/$y';

            if (kIsWeb) {
              if (!_webTileCache.containsKey(tileKey)) {
                final url = 'https://mt1.google.com/vt/lyrs=y&x=$x&y=$y&z=$z';
                try {
                  final response = await http
                      .get(Uri.parse(url))
                      .timeout(const Duration(seconds: 10));
                  if (response.statusCode == 200) {
                    _webTileCache[tileKey] = response.bodyBytes;
                  }
                } catch (e) {
                  // Ignorar errores individuales
                }
              }
            } else {
              final fileDir = Directory('$basePath/$z/$x');
              if (!await fileDir.exists()) {
                await fileDir.create(recursive: true);
              }

              final filePath = '${fileDir.path}/$y.png';
              final file = File(filePath);

              if (!await file.exists()) {
                final url = 'https://mt1.google.com/vt/lyrs=y&x=$x&y=$y&z=$z';
                try {
                  final response = await http
                      .get(Uri.parse(url))
                      .timeout(const Duration(seconds: 10));
                  if (response.statusCode == 200) {
                    await file.writeAsBytes(response.bodyBytes);
                  }
                } catch (e) {
                  // Ignorar errores individuales
                }
              }
            }
          }),
        );

        downloadedCount += batch.length;
        progressNotifier.value = downloadedCount / totalTiles;
      }

      downloadingNotifier.value = false;
      downloadedNotifier.value = true;
    } catch (e) {
      downloadingNotifier.value = false;
      debugPrint('Download map error: $e');
    }
  }

  Uint8List? getWebTile(int x, int y, int z) {
    return _webTileCache['$z/$x/$y'];
  }
}

class OfflineTileProvider extends TileProvider {
  final String baseOfflinePath;
  final CancellableNetworkTileProvider _cancellableNetworkProvider =
      CancellableNetworkTileProvider(silenceExceptions: true);

  OfflineTileProvider({required this.baseOfflinePath});

  @override
  bool get supportsCancelLoading => true;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    if (kIsWeb) {
      final bytes = OfflineMapService().getWebTile(
        coordinates.x,
        coordinates.y,
        coordinates.z,
      );
      if (bytes != null) {
        return MemoryImage(bytes);
      }
      if (!isWebOnline()) {
        return MemoryImage(TileProvider.transparentImage);
      }
      return NetworkImage(getTileUrl(coordinates, options), headers: headers);
    }
    return getImageWithCancelLoadingSupport(
      coordinates,
      options,
      Future.value(),
    );
  }

  @override
  ImageProvider getImageWithCancelLoadingSupport(
    TileCoordinates coordinates,
    TileLayer options,
    Future<void> cancelLoading,
  ) {
    if (kIsWeb) {
      final bytes = OfflineMapService().getWebTile(
        coordinates.x,
        coordinates.y,
        coordinates.z,
      );
      if (bytes != null) {
        return MemoryImage(bytes);
      }
      if (!isWebOnline()) {
        return MemoryImage(TileProvider.transparentImage);
      }
      return NetworkImage(getTileUrl(coordinates, options), headers: headers);
    } else {
      final file = File(
        '$baseOfflinePath/${coordinates.z}/${coordinates.x}/${coordinates.y}.png',
      );
      if (file.existsSync()) {
        return FileImage(file);
      }
    }
    return _cancellableNetworkProvider.getImageWithCancelLoadingSupport(
      coordinates,
      options,
      cancelLoading,
    );
  }

  @override
  void dispose() {
    _cancellableNetworkProvider.dispose();
    super.dispose();
  }
}

class WebNetworkTileProvider extends TileProvider {
  WebNetworkTileProvider({super.headers});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    if (!isWebOnline()) {
      return MemoryImage(TileProvider.transparentImage);
    }
    return NetworkImage(getTileUrl(coordinates, options), headers: headers);
  }

  @override
  ImageProvider getImageWithCancelLoadingSupport(
    TileCoordinates coordinates,
    TileLayer options,
    Future<void> cancelLoading,
  ) {
    if (!isWebOnline()) {
      return MemoryImage(TileProvider.transparentImage);
    }
    return NetworkImage(getTileUrl(coordinates, options), headers: headers);
  }
}
