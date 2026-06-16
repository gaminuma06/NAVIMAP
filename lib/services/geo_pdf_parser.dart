import 'package:flutter/foundation.dart';

class GeoPdfParser {
  static Map<String, dynamic>? parse(Uint8List bytes) {
    try {
      final String content = String.fromCharCodes(bytes);

      // 1. OGC Best Practice (ISO 32000-2) /Measure -> /GPTS
      final gptsMatch = RegExp(r'/GPTS\s*\[(.*?)\]').firstMatch(content);
      if (gptsMatch != null) {
        String nums = gptsMatch.group(1)!;
        List<double> gpts = nums
            .split(RegExp(r'[\s\[\]]+'))
            .where((s) => s.isNotEmpty)
            .map((s) => double.tryParse(s) ?? 0.0)
            .toList();

        if (gpts.length >= 8) {
          // Assume [lat, lon, lat, lon...] or [lat, lon]
          double minLat = 90.0;
          double maxLat = -90.0;
          double minLon = 180.0;
          double maxLon = -180.0;

          for (int i = 0; i < gpts.length; i += 2) {
            // Note: sometimes it is lon, lat. We assume lat is between -90 and 90
            double v1 = gpts[i];
            double v2 = gpts[i + 1];
            double lat = v1.abs() <= 90 ? v1 : v2;
            double lon = v1.abs() <= 90 ? v2 : v1;

            if (lat < minLat) minLat = lat;
            if (lat > maxLat) maxLat = lat;
            if (lon < minLon) minLon = lon;
            if (lon > maxLon) maxLon = lon;
          }

          return {
            'minLat': minLat,
            'maxLat': maxLat,
            'minLon': minLon,
            'maxLon': maxLon,
            'type': 'GPTS',
          };
        }
      }

      // 2. TerraGo /LGIDict -> /CTM or just simple Neatline
      // TerraGo uses /Neatline [ ... ] but the coordinate system could be projected.
    } catch (e) {
      debugPrint("Error parsing GeoPDF: $e");
    }
    return null;
  }
}
