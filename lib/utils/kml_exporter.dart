import '../widgets/object_list_item.dart';

class KmlExporter {
  static String generate(String layerName, List<Map<String, dynamic>> objects) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    buffer.writeln('  <Document>');
    buffer.writeln('    <name>${_escapeXml(layerName)}</name>');
    buffer.writeln('    <description>Exportado desde NaviMap</description>');

    for (final obj in objects) {
      final name = _escapeXml(obj['name'] ?? 'Objeto sin nombre');
      final type = obj['type'];

      buffer.writeln('    <Placemark>');
      buffer.writeln('      <name>$name</name>');

      if (type == GeoObjectType.point) {
        final lat = obj['latitude'] as double?;
        final lon = obj['longitude'] as double?;
        if (lat != null && lon != null) {
          buffer.writeln('      <Point>');
          buffer.writeln('        <coordinates>$lon,$lat,0</coordinates>');
          buffer.writeln('      </Point>');
        }
      } else if (type == GeoObjectType.line) {
        final points = obj['points'] as List?;
        if (points != null && points.isNotEmpty) {
          buffer.writeln('      <LineString>');
          buffer.writeln('        <coordinates>');
          for (final pt in points) {
            final lat = pt['latitude'] as double?;
            final lon = pt['longitude'] as double?;
            if (lat != null && lon != null) {
              buffer.writeln('          $lon,$lat,0');
            }
          }
          buffer.writeln('        </coordinates>');
          buffer.writeln('      </LineString>');
        }
      } else if (type == GeoObjectType.polygon) {
        final points = obj['points'] as List?;
        if (points != null && points.isNotEmpty) {
          buffer.writeln('      <Polygon>');
          buffer.writeln('        <outerBoundaryIs>');
          buffer.writeln('          <LinearRing>');
          buffer.writeln('            <coordinates>');
          for (final pt in points) {
            final lat = pt['latitude'] as double?;
            final lon = pt['longitude'] as double?;
            if (lat != null && lon != null) {
              buffer.writeln('              $lon,$lat,0');
            }
          }
          // Close the loop
          final first = points.first;
          final last = points.last;
          if (first['latitude'] != last['latitude'] ||
              first['longitude'] != last['longitude']) {
            buffer.writeln(
              '              ${first['longitude']},${first['latitude']},0',
            );
          }
          buffer.writeln('            </coordinates>');
          buffer.writeln('          </LinearRing>');
          buffer.writeln('        </outerBoundaryIs>');
          buffer.writeln('      </Polygon>');
        }
      }
      buffer.writeln('    </Placemark>');
    }

    buffer.writeln('  </Document>');
    buffer.writeln('</kml>');
    return buffer.toString();
  }

  static String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
