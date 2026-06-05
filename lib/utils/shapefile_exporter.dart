import 'dart:typed_data';
import 'dart:convert';
import '../widgets/object_list_item.dart';
import 'zip_writer.dart';

class ShapefileExporter {
  static const String wgs84Prj =
      'GEOGCS["GCS_WGS_1984",DATUM["D_WGS_1984",SPHEROID["WGS_1984",6378137.0,298.257223563]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]]';

  static List<ZipFileEntry> generateShapefileFiles(
    String layerName,
    List<Map<String, dynamic>> objects,
  ) {
    final entries = <ZipFileEntry>[];

    final points =
        objects.where((o) => o['type'] == GeoObjectType.point).toList();
    final lines =
        objects.where((o) => o['type'] == GeoObjectType.line).toList();
    final polygons =
        objects.where((o) => o['type'] == GeoObjectType.polygon).toList();

    final cleanName = layerName.replaceAll(RegExp(r'[\\/:*?"<>| ]'), '_');

    if (points.isNotEmpty) {
      final shpBytes = _createPointShp(points);
      final box = _calculatePointsBox(points);
      final shxBytes = _createPointShx(points, box);
      final dbfBytes = _createDbf(points);
      entries.add(ZipFileEntry('${cleanName}_puntos.shp', shpBytes));
      entries.add(ZipFileEntry('${cleanName}_puntos.shx', shxBytes));
      entries.add(ZipFileEntry('${cleanName}_puntos.dbf', dbfBytes));
      entries.add(
        ZipFileEntry(
          '${cleanName}_puntos.prj',
          Uint8List.fromList(wgs84Prj.codeUnits),
        ),
      );
    }

    if (lines.isNotEmpty) {
      final shpBytes = _createLineShp(lines);
      final box = _calculateLinesBox(lines);
      final shxBytes = _createLineOrPolygonShx(
        objects: lines,
        shapeType: 3,
        box: box,
        isPolygon: false,
      );
      final dbfBytes = _createDbf(lines);
      entries.add(ZipFileEntry('${cleanName}_lineas.shp', shpBytes));
      entries.add(ZipFileEntry('${cleanName}_lineas.shx', shxBytes));
      entries.add(ZipFileEntry('${cleanName}_lineas.dbf', dbfBytes));
      entries.add(
        ZipFileEntry(
          '${cleanName}_lineas.prj',
          Uint8List.fromList(wgs84Prj.codeUnits),
        ),
      );
    }

    if (polygons.isNotEmpty) {
      final shpBytes = _createPolygonShp(polygons);
      final box = _calculatePolygonsBox(polygons);
      final shxBytes = _createLineOrPolygonShx(
        objects: polygons,
        shapeType: 5,
        box: box,
        isPolygon: true,
      );
      final dbfBytes = _createDbf(polygons);
      entries.add(ZipFileEntry('${cleanName}_poligonos.shp', shpBytes));
      entries.add(ZipFileEntry('${cleanName}_poligonos.shx', shxBytes));
      entries.add(ZipFileEntry('${cleanName}_poligonos.dbf', dbfBytes));
      entries.add(
        ZipFileEntry(
          '${cleanName}_poligonos.prj',
          Uint8List.fromList(wgs84Prj.codeUnits),
        ),
      );
    }

    return entries;
  }

  // --- Helper Methods ---

  static Uint8List _createHeader({
    required int shapeType,
    required int fileLengthBytes,
    required List<double> box,
  }) {
    final header = ByteData(100);
    header.setInt32(0, 9994, Endian.big); // File Code
    header.setInt32(
      24,
      fileLengthBytes ~/ 2,
      Endian.big,
    ); // File Length in 16-bit words
    header.setInt32(28, 1000, Endian.little); // Version
    header.setInt32(32, shapeType, Endian.little); // Shape Type
    header.setFloat64(36, box[0], Endian.little); // Xmin
    header.setFloat64(44, box[1], Endian.little); // Ymin
    header.setFloat64(52, box[2], Endian.little); // Xmax
    header.setFloat64(60, box[3], Endian.little); // Ymax
    return header.buffer.asUint8List();
  }

  static List<double> _calculatePointsBox(List<Map<String, dynamic>> points) {
    double xMin = double.infinity, yMin = double.infinity;
    double xMax = -double.infinity, yMax = -double.infinity;

    for (final obj in points) {
      final lat = obj['latitude'] as double?;
      final lon = obj['longitude'] as double?;
      if (lat != null && lon != null) {
        if (lon < xMin) xMin = lon;
        if (lon > xMax) xMax = lon;
        if (lat < yMin) yMin = lat;
        if (lat > yMax) yMax = lat;
      }
    }

    if (xMin == double.infinity) {
      xMin = yMin = xMax = yMax = 0.0;
    }
    return [xMin, yMin, xMax, yMax];
  }

  static List<double> _calculateLinesBox(List<Map<String, dynamic>> lines) {
    double xMin = double.infinity, yMin = double.infinity;
    double xMax = -double.infinity, yMax = -double.infinity;

    for (final obj in lines) {
      final points = obj['points'] as List?;
      if (points != null && points.isNotEmpty) {
        for (final pt in points) {
          final lat = pt['latitude'] as double?;
          final lon = pt['longitude'] as double?;
          if (lat != null && lon != null) {
            if (lon < xMin) xMin = lon;
            if (lon > xMax) xMax = lon;
            if (lat < yMin) yMin = lat;
            if (lat > yMax) yMax = lat;
          }
        }
      }
    }

    if (xMin == double.infinity) {
      xMin = yMin = xMax = yMax = 0.0;
    }
    return [xMin, yMin, xMax, yMax];
  }

  static List<double> _calculatePolygonsBox(
    List<Map<String, dynamic>> polygons,
  ) {
    double xMin = double.infinity, yMin = double.infinity;
    double xMax = -double.infinity, yMax = -double.infinity;

    for (final obj in polygons) {
      final points = obj['points'] as List?;
      if (points != null && points.isNotEmpty) {
        for (final pt in points) {
          final lat = pt['latitude'] as double?;
          final lon = pt['longitude'] as double?;
          if (lat != null && lon != null) {
            if (lon < xMin) xMin = lon;
            if (lon > xMax) xMax = lon;
            if (lat < yMin) yMin = lat;
            if (lat > yMax) yMax = lat;
          }
        }
      }
    }

    if (xMin == double.infinity) {
      xMin = yMin = xMax = yMax = 0.0;
    }
    return [xMin, yMin, xMax, yMax];
  }

  static Uint8List _createPointShp(List<Map<String, dynamic>> objects) {
    final recordsBuffer = BytesBuilder();
    int recordNum = 1;

    for (final obj in objects) {
      final lat = obj['latitude'] as double?;
      final lon = obj['longitude'] as double?;
      if (lat != null && lon != null) {
        final recHeader = ByteData(8);
        recHeader.setInt32(0, recordNum++, Endian.big);
        recHeader.setInt32(4, 10, Endian.big); // 20 bytes = 10 words
        recordsBuffer.add(recHeader.buffer.asUint8List());

        final recContent = ByteData(20);
        recContent.setInt32(0, 1, Endian.little); // Point = 1
        recContent.setFloat64(4, lon, Endian.little);
        recContent.setFloat64(12, lat, Endian.little);
        recordsBuffer.add(recContent.buffer.asUint8List());
      }
    }

    final recordsBytes = recordsBuffer.toBytes();
    final fileLengthBytes = 100 + recordsBytes.length;
    final box = _calculatePointsBox(objects);

    final finalBuilder = BytesBuilder();
    finalBuilder.add(
      _createHeader(
        shapeType: 1,
        fileLengthBytes: fileLengthBytes,
        box: box,
      ),
    );
    finalBuilder.add(recordsBytes);
    return finalBuilder.toBytes();
  }

  static Uint8List _createPointShx(
    List<Map<String, dynamic>> objects,
    List<double> box,
  ) {
    final recordsBuffer = BytesBuilder();
    int offsetWords = 50;

    for (final obj in objects) {
      final lat = obj['latitude'] as double?;
      final lon = obj['longitude'] as double?;
      if (lat != null && lon != null) {
        final idxRecord = ByteData(8);
        idxRecord.setInt32(0, offsetWords, Endian.big);
        idxRecord.setInt32(4, 10, Endian.big);
        recordsBuffer.add(idxRecord.buffer.asUint8List());
        offsetWords += 4 + 10;
      }
    }

    final recordsBytes = recordsBuffer.toBytes();
    final fileLengthBytes = 100 + recordsBytes.length;

    final finalBuilder = BytesBuilder();
    finalBuilder.add(
      _createHeader(
        shapeType: 1,
        fileLengthBytes: fileLengthBytes,
        box: box,
      ),
    );
    finalBuilder.add(recordsBytes);
    return finalBuilder.toBytes();
  }

  static Uint8List _createLineShp(List<Map<String, dynamic>> objects) {
    final recordsBuffer = BytesBuilder();
    int recordNum = 1;

    for (final obj in objects) {
      final points = obj['points'] as List?;
      if (points != null && points.isNotEmpty) {
        double rxMin = double.infinity, ryMin = double.infinity;
        double rxMax = -double.infinity, ryMax = -double.infinity;

        for (final pt in points) {
          final lat = pt['latitude'] as double?;
          final lon = pt['longitude'] as double?;
          if (lat != null && lon != null) {
            if (lon < rxMin) rxMin = lon;
            if (lon > rxMax) rxMax = lon;
            if (lat < ryMin) ryMin = lat;
            if (lat > ryMax) ryMax = lat;
          }
        }

        final numPoints = points.length;
        final contentLengthBytes = 44 + 4 + 16 * numPoints;

        final recHeader = ByteData(8);
        recHeader.setInt32(0, recordNum++, Endian.big);
        recHeader.setInt32(4, contentLengthBytes ~/ 2, Endian.big);
        recordsBuffer.add(recHeader.buffer.asUint8List());

        final recContent = ByteData(48);
        recContent.setInt32(0, 3, Endian.little); // PolyLine = 3
        recContent.setFloat64(4, rxMin, Endian.little);
        recContent.setFloat64(12, ryMin, Endian.little);
        recContent.setFloat64(20, rxMax, Endian.little);
        recContent.setFloat64(28, ryMax, Endian.little);
        recContent.setInt32(36, 1, Endian.little); // NumParts = 1
        recContent.setInt32(40, numPoints, Endian.little);
        recContent.setInt32(44, 0, Endian.little); // Parts[0] = 0
        recordsBuffer.add(recContent.buffer.asUint8List());

        final ptsData = ByteData(numPoints * 16);
        for (int i = 0; i < numPoints; i++) {
          final pt = points[i];
          final lat = pt['latitude'] as double? ?? 0.0;
          final lon = pt['longitude'] as double? ?? 0.0;
          ptsData.setFloat64(i * 16, lon, Endian.little);
          ptsData.setFloat64(i * 16 + 8, lat, Endian.little);
        }
        recordsBuffer.add(ptsData.buffer.asUint8List());
      }
    }

    final recordsBytes = recordsBuffer.toBytes();
    final fileLengthBytes = 100 + recordsBytes.length;
    final box = _calculateLinesBox(objects);

    final finalBuilder = BytesBuilder();
    finalBuilder.add(
      _createHeader(
        shapeType: 3,
        fileLengthBytes: fileLengthBytes,
        box: box,
      ),
    );
    finalBuilder.add(recordsBytes);
    return finalBuilder.toBytes();
  }

  static Uint8List _createPolygonShp(List<Map<String, dynamic>> objects) {
    final recordsBuffer = BytesBuilder();
    int recordNum = 1;

    for (final obj in objects) {
      final origPoints = obj['points'] as List?;
      if (origPoints != null && origPoints.isNotEmpty) {
        final points = List<Map<String, dynamic>>.from(origPoints);
        final first = points.first;
        final last = points.last;
        if (first['latitude'] != last['latitude'] ||
            first['longitude'] != last['longitude']) {
          points.add(first);
        }

        double rxMin = double.infinity, ryMin = double.infinity;
        double rxMax = -double.infinity, ryMax = -double.infinity;

        for (final pt in points) {
          final lat = pt['latitude'] as double? ?? 0.0;
          final lon = pt['longitude'] as double? ?? 0.0;
          if (lon < rxMin) rxMin = lon;
          if (lon > rxMax) rxMax = lon;
          if (lat < ryMin) ryMin = lat;
          if (lat > ryMax) ryMax = lat;
        }

        final numPoints = points.length;
        final contentLengthBytes = 44 + 4 + 16 * numPoints;

        final recHeader = ByteData(8);
        recHeader.setInt32(0, recordNum++, Endian.big);
        recHeader.setInt32(4, contentLengthBytes ~/ 2, Endian.big);
        recordsBuffer.add(recHeader.buffer.asUint8List());

        final recContent = ByteData(48);
        recContent.setInt32(0, 5, Endian.little); // Polygon = 5
        recContent.setFloat64(4, rxMin, Endian.little);
        recContent.setFloat64(12, ryMin, Endian.little);
        recContent.setFloat64(20, rxMax, Endian.little);
        recContent.setFloat64(28, ryMax, Endian.little);
        recContent.setInt32(36, 1, Endian.little); // NumParts = 1
        recContent.setInt32(40, numPoints, Endian.little);
        recContent.setInt32(44, 0, Endian.little); // Parts[0] = 0
        recordsBuffer.add(recContent.buffer.asUint8List());

        final ptsData = ByteData(numPoints * 16);
        for (int i = 0; i < numPoints; i++) {
          final pt = points[i];
          final lat = pt['latitude'] as double? ?? 0.0;
          final lon = pt['longitude'] as double? ?? 0.0;
          ptsData.setFloat64(i * 16, lon, Endian.little);
          ptsData.setFloat64(i * 16 + 8, lat, Endian.little);
        }
        recordsBuffer.add(ptsData.buffer.asUint8List());
      }
    }

    final recordsBytes = recordsBuffer.toBytes();
    final fileLengthBytes = 100 + recordsBytes.length;
    final box = _calculatePolygonsBox(objects);

    final finalBuilder = BytesBuilder();
    finalBuilder.add(
      _createHeader(
        shapeType: 5,
        fileLengthBytes: fileLengthBytes,
        box: box,
      ),
    );
    finalBuilder.add(recordsBytes);
    return finalBuilder.toBytes();
  }

  static Uint8List _createLineOrPolygonShx({
    required List<Map<String, dynamic>> objects,
    required int shapeType,
    required List<double> box,
    bool isPolygon = false,
  }) {
    final recordsBuffer = BytesBuilder();
    int offsetWords = 50;

    for (final obj in objects) {
      final points = obj['points'] as List?;
      if (points != null && points.isNotEmpty) {
        int numPoints = points.length;
        if (isPolygon) {
          final first = points.first;
          final last = points.last;
          if (first['latitude'] != last['latitude'] ||
              first['longitude'] != last['longitude']) {
            numPoints += 1;
          }
        }
        final contentLengthBytes = 44 + 4 + 16 * numPoints;
        final contentLengthWords = contentLengthBytes ~/ 2;

        final idxRecord = ByteData(8);
        idxRecord.setInt32(0, offsetWords, Endian.big);
        idxRecord.setInt32(4, contentLengthWords, Endian.big);
        recordsBuffer.add(idxRecord.buffer.asUint8List());

        offsetWords += 4 + contentLengthWords;
      }
    }

    final recordsBytes = recordsBuffer.toBytes();
    final fileLengthBytes = 100 + recordsBytes.length;

    final finalBuilder = BytesBuilder();
    finalBuilder.add(
      _createHeader(
        shapeType: shapeType,
        fileLengthBytes: fileLengthBytes,
        box: box,
      ),
    );
    finalBuilder.add(recordsBytes);
    return finalBuilder.toBytes();
  }

  static Uint8List _createDbf(List<Map<String, dynamic>> objects) {
    final builder = BytesBuilder();
    final now = DateTime.now();
    final yy = now.year % 100;
    final mm = now.month;
    final dd = now.day;

    final numRecords = objects.length;
    final headerLength = 32 + 3 * 32 + 1; // 129
    final recordLength =
        111; // 1 (delete flag) + 10 (ID) + 50 (Name) + 50 (Value)

    final header = ByteData(32);
    header.setUint8(0, 0x03);
    header.setUint8(1, yy);
    header.setUint8(2, mm);
    header.setUint8(3, dd);
    header.setInt32(4, numRecords, Endian.little);
    header.setUint16(8, headerLength, Endian.little);
    header.setUint16(10, recordLength, Endian.little);
    builder.add(header.buffer.asUint8List());

    // Field 1: ID (Numeric, length 10)
    final f1 = ByteData(32);
    f1.setUint8(0, 0x49); // 'I'
    f1.setUint8(1, 0x44); // 'D'
    f1.setUint8(11, 0x4E); // 'N'
    f1.setUint8(16, 10);
    builder.add(f1.buffer.asUint8List());

    // Field 2: NAME (Character, length 50)
    final f2 = ByteData(32);
    f2.setUint8(0, 0x4E); // 'N'
    f2.setUint8(1, 0x41); // 'A'
    f2.setUint8(2, 0x4D); // 'M'
    f2.setUint8(3, 0x45); // 'E'
    f2.setUint8(11, 0x43); // 'C'
    f2.setUint8(16, 50);
    builder.add(f2.buffer.asUint8List());

    // Field 3: VALUE (Character, length 50)
    final f3 = ByteData(32);
    f3.setUint8(0, 0x56); // 'V'
    f3.setUint8(1, 0x41); // 'A'
    f3.setUint8(2, 0x4C); // 'L'
    f3.setUint8(3, 0x55); // 'U'
    f3.setUint8(4, 0x45); // 'E'
    f3.setUint8(11, 0x43); // 'C'
    f3.setUint8(16, 50);
    builder.add(f3.buffer.asUint8List());

    // Header terminator
    builder.add([0x0D]);

    // Records
    int id = 1;
    for (final obj in objects) {
      final rec = BytesBuilder();
      rec.add([0x20]); // not deleted

      final idStr = (id++).toString().padRight(10).substring(0, 10);
      rec.add(utf8.encode(idStr));

      final nameStr =
          (obj['name'] ?? '').toString().padRight(50).substring(0, 50);
      rec.add(_encodeStringToDbf(nameStr));

      final valStr =
          (obj['value'] ?? '').toString().padRight(50).substring(0, 50);
      rec.add(_encodeStringToDbf(valStr));

      builder.add(rec.toBytes());
    }

    // File terminator
    builder.add([0x1A]);

    return builder.toBytes();
  }

  static Uint8List _encodeStringToDbf(String text) {
    final bytes = utf8.encode(text);
    if (bytes.length == 50) {
      return Uint8List.fromList(bytes);
    } else if (bytes.length > 50) {
      return Uint8List.fromList(bytes.sublist(0, 50));
    } else {
      final padded = List<int>.filled(50, 0x20); // filled with spaces
      for (int i = 0; i < bytes.length; i++) {
        padded[i] = bytes[i];
      }
      return Uint8List.fromList(padded);
    }
  }
}
