import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:proj4dart/proj4dart.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import '../services/user_location_service.dart';

enum MapSpatialStatus { within, outside, notReferenced }

class MapCalibration {
  final double matrixA, matrixB, matrixC, matrixD, matrixE, matrixF;
  final double originalImageWidth, originalImageHeight;
  final double cropX, cropY;
  final String? projectionIdentifier;
  final bool isProjected;
  final double firstGpts;
  final double firstLpts;
  double manualOffsetX;
  double manualOffsetY;
  final double? boundsSouth, boundsNorth, boundsWest, boundsEast;
  final double? minLptsX, minLptsY, maxLptsX, maxLptsY;

  MapCalibration({
    required this.matrixA,
    required this.matrixB,
    required this.matrixC,
    required this.matrixD,
    required this.matrixE,
    required this.matrixF,
    required this.originalImageWidth,
    required this.originalImageHeight,
    required this.cropX,
    required this.cropY,
    required this.projectionIdentifier,
    required this.isProjected,
    this.firstGpts = 0,
    this.firstLpts = 0,
    this.manualOffsetX = 0,
    this.manualOffsetY = 0,
    this.boundsSouth,
    this.boundsNorth,
    this.boundsWest,
    this.boundsEast,
    this.minLptsX,
    this.minLptsY,
    this.maxLptsX,
    this.maxLptsY,
  });
}

class GeoreferenceService {
  static final GeoreferenceService _instance = GeoreferenceService._internal();
  factory GeoreferenceService() => _instance;
  GeoreferenceService._internal() {
    Projection.add(
      'EPSG:3116',
      '+proj=tmerc +lat_0=4.59620041666667 +lon_0=-74.0775079166667 +k=1 +x_0=1000000 +y_0=1000000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
    );
    Projection.add(
      'EPSG:3115',
      '+proj=tmerc +lat_0=4.59620041666667 +lon_0=-77.0775079166667 +k=1 +x_0=1000000 +y_0=1000000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
    );
    Projection.add(
      'EPSG:3114',
      '+proj=tmerc +lat_0=4.59620041666667 +lon_0=-71.0775079166667 +k=1 +x_0=1000000 +y_0=1000000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
    );
    Projection.add(
      'EPSG:9377',
      '+proj=tmerc +lat_0=4 +lon_0=-73 +k=0.9992 +x_0=5000000 +y_0=2000000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
    );
  }

  final Map<String, MapCalibration> _dynamicCalibrations = {};
  String debugInfo = "";

  void clearCache(String mapTitle) {
    _dynamicCalibrations.remove(mapTitle);
  }

  Future<void> scanGeoPdfMetadata(String mapTitle, Uint8List bytes) async {
    if (_dynamicCalibrations.containsKey(mapTitle)) return;
    try {
      final cal = _extractCalibrationFromPdf(bytes);
      if (cal != null) {
        _dynamicCalibrations[mapTitle] = cal;
      } else {
        debugInfo = "Sin metadatos GeoPDF";
      }
    } catch (e) {
      debugInfo = "Error: $e";
    }
  }

  bool hasCalibrationFor(String mapTitle) {
    return _dynamicCalibrations.containsKey(mapTitle);
  }

  MapCalibration? _getCalibration(String mapTitle) {
    return _dynamicCalibrations[mapTitle];
  }

  List<double> _parseNumbers(String text) {
    return text
        .split(RegExp(r'[\s\[\],]+'))
        .where((s) => s.isNotEmpty)
        .map((s) => double.tryParse(s) ?? 0.0)
        .toList();
  }

  MapCalibration? _extractCalibrationFromPdf(Uint8List bytes) {
    String content = String.fromCharCodes(
      bytes.take(math.min(bytes.length, 10000000)).toList(),
    );

    double mediaWidth = 1000.0, mediaHeight = 1000.0, cropX = 0.0, cropY = 0.0;
    final mediaBoxMatch = RegExp(
      r'/MediaBox\s*\[\s*([\d\.\s-]+)\s*\]',
    ).firstMatch(content);
    if (mediaBoxMatch != null) {
      final parts = _parseNumbers(mediaBoxMatch.group(1)!);
      if (parts.length >= 4) {
        mediaWidth = (parts[2] - parts[0]).abs();
        mediaHeight = (parts[3] - parts[1]).abs();
      }
    }
    final cropBoxMatch = RegExp(
      r'/CropBox\s*\[\s*([\d\.\s-]+)\s*\]',
    ).firstMatch(content);
    if (cropBoxMatch != null) {
      final parts = _parseNumbers(cropBoxMatch.group(1)!);
      if (parts.length >= 4) {
        cropX = parts[0];
        cropY = parts[1];
        mediaWidth = (parts[2] - parts[0]).abs();
        mediaHeight = (parts[3] - parts[1]).abs();
      }
    }

    try {
      content = String.fromCharCodes(bytes);

      double userUnit = 1.0;
      final uuMatch = RegExp(r'/UserUnit\s+(\d+\.?\d*)').firstMatch(content);
      if (uuMatch != null) userUnit = double.parse(uuMatch.group(1)!);

      // Decompress FlateDecode to find hidden CTM, LGIDict, and WKT
      try {
        final streamMatches = RegExp(
          r'<<[^>]*?/Filter\s*/FlateDecode[^>]*?>>\s*stream\r?\n(.*?)\r?\nendstream',
          dotAll: true,
        ).allMatches(content);
        print(
          "DEBUG: Encontrados ${streamMatches.length} streams comprimidos.",
        );
        for (var match in streamMatches) {
          try {
            List<int> compressed = match.group(1)!.codeUnits;
            List<int> decompressed = zlib.decode(compressed);
            content += "\n" + String.fromCharCodes(decompressed);
          } catch (_) {}
        }
      } catch (_) {}

      String? wkt;
      final wktMatches = [
        ...RegExp(r'/WKT\s*\(([^)]+)\)').allMatches(content),
        ...RegExp(r'(PROJCS\[.*?\])').allMatches(content),
        ...RegExp(r'(GEOGCS\[.*?\])').allMatches(content),
      ];
      
      for (var match in wktMatches) {
        String candidate = match.group(1) ?? match.group(0)!;
        if (!candidate.contains("Web_Mercator") && 
            !candidate.contains("Auxiliary_Sphere") && 
            !candidate.contains("EPSG:3857")) {
          wkt = candidate;
          print("DEBUG: WKT Válido Encontrado: $wkt");
          break; // Tomar el primero que no sea Web Mercator
        }
      }
      
      if (wkt == null && wktMatches.isNotEmpty) {
        wkt = wktMatches.first.group(1) ?? wktMatches.first.group(0)!;
        print("DEBUG: WKT Fallback Encontrado (Web Mercator): $wkt");
      }

      if (wkt != null) {
        // TerraGo fallback
        final projDictMatch = RegExp(
          r'/Projection\s*<<\s*(.*?)\s*>>',
          dotAll: true,
        ).firstMatch(content);
        if (projDictMatch != null) {
          String pDict = projDictMatch.group(1)!;
          String projType =
              RegExp(
                r'/ProjectionType\s*\(?(TC)\)?',
              ).firstMatch(pDict)?.group(1) ??
              '';
          if (projType == 'TC') {
            double cm =
                double.tryParse(
                  RegExp(
                        r'/CentralMeridian\s*\(?([-\d.]+)\)?',
                      ).firstMatch(pDict)?.group(1) ??
                      '0',
                ) ??
                0.0;
            double fe =
                double.tryParse(
                  RegExp(
                        r'/FalseEasting\s*\(?([-\d.]+)\)?',
                      ).firstMatch(pDict)?.group(1) ??
                      '0',
                ) ??
                0.0;
            double fn =
                double.tryParse(
                  RegExp(
                        r'/FalseNorthing\s*\(?([-\d.]+)\)?',
                      ).firstMatch(pDict)?.group(1) ??
                      '0',
                ) ??
                0.0;
            double sf =
                double.tryParse(
                  RegExp(
                        r'/ScaleFactor\s*\(?([-\d.]+)\)?',
                      ).firstMatch(pDict)?.group(1) ??
                      '1',
                ) ??
                1.0;
            double lat0 =
                double.tryParse(
                  RegExp(
                        r'/OriginLatitude\s*\(?([-\d.]+)\)?',
                      ).firstMatch(pDict)?.group(1) ??
                      '0',
                ) ??
                0.0;
            wkt =
                '+proj=tmerc +lat_0=$lat0 +lon_0=$cm +k=$sf +x_0=$fe +y_0=$fn +datum=WGS84 +units=m +no_defs';
            print("DEBUG: Generado proj4 desde TerraGo: $wkt");
          }
        }
      }

      // 1. OGC GeoPDF CTM
      final ctmMatch = RegExp(
        r'/CTM\s*\[\s*([\d\.\s-]+)\s*\]',
      ).firstMatch(content);
      if (ctmMatch != null) {
        print("DEBUG: /CTM encontrado: ${ctmMatch.group(1)}");
        List<double> ctm = _parseNumbers(ctmMatch.group(1)!);
        if (ctm.length >= 6) {
          double a = ctm[0],
              b = ctm[1],
              c = ctm[2],
              d = ctm[3],
              e = ctm[4],
              f = ctm[5];
          if (a.abs() > 0.0001 && e.abs() > 0.0001) {
            return MapCalibration(
              matrixA: a,
              matrixB: c,
              matrixC: e,
              matrixD: b,
              matrixE: d,
              matrixF: f,
              originalImageWidth: mediaWidth,
              originalImageHeight: mediaHeight,
              cropX: cropX,
              cropY: cropY,
              projectionIdentifier: wkt,
              isProjected: true,
            );
          }
        }
      }

      // 2. TiePoints
      final tiePointsMatch =
          RegExp(r'/TiePoint\s*\[\s*([\d\.\s-]+)\s*\]').firstMatch(content) ??
          RegExp(r'/TiePoints\s*\[\s*([\d\.\s-]+)\s*\]').firstMatch(content);
      if (tiePointsMatch != null) {
        print("DEBUG: /TiePoint encontrado: ${tiePointsMatch.group(1)}");
        List<double> tp = _parseNumbers(tiePointsMatch.group(1)!);
        if (tp.length >= 12) {
          List<math.Point<double>> pdfPoints = [];
          List<math.Point<double>> mapPoints = [];
          for (int i = 0; i < tp.length - 3; i += 4) {
            pdfPoints.add(math.Point(tp[i], tp[i + 1]));
            mapPoints.add(math.Point(tp[i + 2], tp[i + 3]));
          }
          double x1 = pdfPoints[0].x, y1 = pdfPoints[0].y, m1x = mapPoints[0].x;
          double x2 = pdfPoints[1].x, y2 = pdfPoints[1].y, m2x = mapPoints[1].x;
          double x3 = pdfPoints[2].x, y3 = pdfPoints[2].y, m3x = mapPoints[2].x;
          double det = x1 * (y2 - y3) + x2 * (y3 - y1) + x3 * (y1 - y2);
          if (det.abs() > 1e-9) {
            double A =
                (m1x * (y2 - y3) + m2x * (y3 - y1) + m3x * (y1 - y2)) / det;
            double B =
                (m1x * (x3 - x2) + m2x * (x1 - x3) + m3x * (x2 - x1)) / det;
            double C =
                (m1x * (x2 * y3 - x3 * y2) +
                    m2x * (x3 * y1 - x1 * y3) +
                    m3x * (x1 * y2 - x2 * y1)) /
                det;
            double m1y = mapPoints[0].y,
                m2y = mapPoints[1].y,
                m3y = mapPoints[2].y;
            double D =
                (m1y * (y2 - y3) + m2y * (y3 - y1) + m3y * (y1 - y2)) / det;
            double E =
                (m1y * (x3 - x2) + m2y * (x1 - x3) + m3y * (x2 - x1)) / det;
            double F =
                (m1y * (x2 * y3 - x3 * y2) +
                    m2y * (x3 * y1 - x1 * y3) +
                    m3y * (x1 * y2 - x2 * y1)) /
                det;
            return MapCalibration(
              matrixA: A,
              matrixB: B,
              matrixC: C,
              matrixD: D,
              matrixE: E,
              matrixF: F,
              originalImageWidth: mediaWidth,
              originalImageHeight: mediaHeight,
              cropX: cropX,
              cropY: cropY,
              projectionIdentifier: wkt,
              isProjected: true,
              boundsSouth: null, boundsNorth: null, boundsWest: null, boundsEast: null,
            );
          }
        }
      }

      // 3. Adobe Geospatial (GPTS/LPTS)
      final gptsMatches = RegExp(
        r'/GPTS\s*\[\s*([\d\.\s-]+)\s*\]',
      ).allMatches(content);
      final lptsMatches = RegExp(
        r'/LPTS\s*\[\s*([\d\.\s-]+)\s*\]',
      ).allMatches(content);
      print(
        "DEBUG: Encontrados ${gptsMatches.length} /GPTS y ${lptsMatches.length} /LPTS",
      );

      if (gptsMatches.isNotEmpty) {
        List<double> bestGpts = [];
        List<double> bestLpts = [];
        double maxArea = -1;

        for (int i = 0; i < gptsMatches.length; i++) {
          List<double> gpts = _parseNumbers(gptsMatches.elementAt(i).group(1)!);
          List<double> lpts = (lptsMatches.length > i)
              ? _parseNumbers(lptsMatches.elementAt(i).group(1)!)
              : [];

          if (gpts.length >= 6) {
            if (lpts.isEmpty) {
              final boundsMatches = RegExp(
                r'/Bounds\s*\[\s*([\d\.\s-]+)\s*\]',
              ).allMatches(content);
              if (boundsMatches.length > i) {
                lpts = _parseNumbers(boundsMatches.elementAt(i).group(1)!);
                print("DEBUG: Usando /Bounds: $lpts");
              } else {
                lpts = [0, 0, 1, 0, 1, 1, 0, 1];
              }
            } else {
              final lgiMatch = RegExp(
                r'/LGIDict.*?/Neatline\s*\[(.*?)\]',
                dotAll: true,
              ).firstMatch(content);
              if (lgiMatch != null) {
                var neatline = _parseNumbers(lgiMatch.group(1)!);
                if (neatline.length >= 8) {
                  lpts = neatline;
                  print("DEBUG: Usando /LGIDict /Neatline: $lpts");
                }
              }
            }
            print("DEBUG: Evaluando GPTS: $gpts, con LPTS: $lpts");

            double minX = lpts[0],
                maxX = lpts[0],
                minY = lpts[1],
                maxY = lpts[1];
            for (int k = 0; k < lpts.length - 1; k += 2) {
              if (lpts[k] < minX) minX = lpts[k];
              if (lpts[k] > maxX) maxX = lpts[k];
              if (lpts[k + 1] < minY) minY = lpts[k + 1];
              if (lpts[k + 1] > maxY) maxY = lpts[k + 1];
            }
            double area = (maxX - minX).abs() * (maxY - minY).abs();

            // If areas are equal (e.g. multiple full-page garbage GPTS from QGIS),
            // we prefer the FIRST one found, as QGIS usually writes the active map frame first.
            if (area > maxArea) {
              maxArea = area;
              bestGpts = gpts;
              bestLpts = lpts;
            }
          }
        }

        List<double> gpts = bestGpts;
        List<double> lpts = bestLpts;

        // Intentar leer el BBox real del mapa desde un /Viewport
        final vpDictMatches = RegExp(
          r'<<[^>]*?/Type\s*/Viewport[^>]*?>>', 
          dotAll: true
        ).allMatches(content);
        
        List<double>? vpBBox;
        for (var m in vpDictMatches) {
          var bboxMatch = RegExp(r'/BBox\s*\[\s*([\d\.\s-]+)\s*\]').firstMatch(m.group(0)!);
          if (bboxMatch != null) {
            vpBBox = _parseNumbers(bboxMatch.group(1)!);
            break;
          }
        }

        if (vpBBox != null && vpBBox.length >= 4 && mediaWidth > 0 && mediaHeight > 0) {
          double minX = vpBBox[0] / mediaWidth;
          double minY = vpBBox[1] / mediaHeight;
          double maxX = vpBBox[2] / mediaWidth;
          double maxY = vpBBox[3] / mediaHeight;
          
          lpts = [
            minX, maxY,
            maxX, maxY,
            minX, minY,
            maxX, minY
          ];
          print("DEBUG: LPTS reparado usando /Viewport /BBox: $lpts");
        }

        if (gpts.length >= 6) {
          bool isProjected = gpts.any((n) => n.abs() > 180);
          
          double? bSouth, bNorth, bWest, bEast;
          if (!isProjected && vpBBox != null) {
            // Compute bounds extrapolating Viewport GPTS to Full Page
            double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
            for (int i = 0; i < gpts.length - 1; i += 2) {
              double v1 = gpts[i], v2 = gpts[i + 1], lat, lon;
              if (v1.abs() < 15 && v2.abs() > 60) {
                lat = v1; lon = v2;
              } else if (v2.abs() < 15 && v1.abs() > 60) {
                lat = v2; lon = v1;
              } else {
                lat = v1; lon = v2;
              }
              if (lat < minLat) minLat = lat;
              if (lat > maxLat) maxLat = lat;
              if (lon < minLon) minLon = lon;
              if (lon > maxLon) maxLon = lon;
            }
            
            // Web Mercator constants
            double r = 6378137.0;
            double d = math.pi / 180.0;
            double maxLatClamped = 85.0511287798;
            
            double swLat = math.max(-maxLatClamped, math.min(maxLatClamped, minLat));
            double neLat = math.max(-maxLatClamped, math.min(maxLatClamped, maxLat));
            
            // Project GPTS to Web Mercator
            double minEasting = r * minLon * d;
            double minNorthing = r * math.log(math.tan((math.pi / 4.0) + (swLat * d / 2.0)));
            double maxEasting = r * maxLon * d;
            double maxNorthing = r * math.log(math.tan((math.pi / 4.0) + (neLat * d / 2.0)));
            
            double vpWidthPts = vpBBox[2] - vpBBox[0];
            double vpHeightPts = vpBBox[3] - vpBBox[1];
            
            double pixelWidth = (maxEasting - minEasting) / vpWidthPts;
            double pixelHeight = (maxNorthing - minNorthing) / vpHeightPts;
            
            // Extrapolate to MediaBox Origin (Top-Left of page)
            double originX = minEasting - (vpBBox[0] * pixelWidth);
            double originY = maxNorthing + ((mediaHeight - vpBBox[3]) * pixelHeight);
            
            // Extrapolate to MediaBox Bottom-Right
            double brX = originX + (mediaWidth * pixelWidth);
            double brY = originY - (mediaHeight * pixelHeight);
            
            // Unproject back to Lat/Lon
            double dInv = 180.0 / math.pi;
            double tlLon = originX * dInv / r;
            double tlLat = (2.0 * math.atan(math.exp(originY / r)) - (math.pi / 2.0)) * dInv;
            
            double brLon = brX * dInv / r;
            double brLat = (2.0 * math.atan(math.exp(brY / r)) - (math.pi / 2.0)) * dInv;
            
            bSouth = brLat;
            bNorth = tlLat;
            bWest = tlLon;
            bEast = brLon;
            print("DEBUG: Bounds extrapolados a página completa: SW(\$bSouth, \$bWest) NE(\$bNorth, \$bEast)");
          } else if (!isProjected) {
            // Compute bounds directly from GPTS if they are Lat/Lon
            double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
            for (int i = 0; i < gpts.length - 1; i += 2) {
              double v1 = gpts[i], v2 = gpts[i + 1], lat, lon;
              if (v1.abs() < 15 && v2.abs() > 60) {
                lat = v1; lon = v2;
              } else if (v2.abs() < 15 && v1.abs() > 60) {
                lat = v2; lon = v1;
              } else {
                lat = v1; lon = v2;
              }
              if (lat < minLat) minLat = lat;
              if (lat > maxLat) maxLat = lat;
              if (lon < minLon) minLon = lon;
              if (lon > maxLon) maxLon = lon;
            }
            if (minLat >= -90 && maxLat <= 90 && minLon >= -180 && maxLon <= 180) {
              bSouth = minLat; bNorth = maxLat; bWest = minLon; bEast = maxLon;
              print("DEBUG: Bounds directos desde GPTS: SW(\$bSouth, \$bWest) NE(\$bNorth, \$bEast)");
            }
          }
          
          double? minLX, minLY, maxLX, maxLY;
          if (lpts.length >= 8) {
            minLX = 2.0; maxLX = -2.0; minLY = 2.0; maxLY = -2.0;
            for (int i = 0; i < lpts.length - 1; i += 2) {
              double x = lpts[i], y = lpts[i + 1];
              if (x < minLX!) minLX = x;
              if (x > maxLX!) maxLX = x;
              if (y < minLY!) minLY = y;
              if (y > maxLY!) maxLY = y;
            }
          }

          Projection? projection;
          String? projId;

          if (wkt != null && wkt.isNotEmpty) {
            if (wkt.contains('Web_Mercator') ||
                wkt.contains('Mercator_Auxiliary_Sphere')) {
              try {
                projection = Projection.get('EPSG:3857');
                projId = 'EPSG:3857';
              } catch (_) {}
            } else {
              try {
                projection = Projection.parse(wkt);
                projId = wkt;
              } catch (e) {
                final epsgMatch = RegExp(
                  r'["\x27]EPSG["\x27]\s*,\s*["\x27]?(\d+)["\x27]?',
                ).allMatches(wkt);
                if (epsgMatch.isNotEmpty) {
                  String code = epsgMatch.last.group(1)!;
                  try {
                    projection = Projection.get('EPSG:$code');
                    projId = 'EPSG:$code';
                  } catch (_) {}
                }
              }
            }
            print("DEBUG: Projection asignada: $projId");
          }

          if (projection == null && isProjected && gpts[0].abs() > 1000000) {
            try {
              projection = Projection.get('EPSG:3857');
              projId = 'EPSG:3857';
            } catch (_) {}
          }

          List<math.Point<double>> mapPoints = [];
          for (int i = 0; i < gpts.length - 1; i += 2) {
            double v1 = gpts[i], v2 = gpts[i + 1], lat, lon;
            if (!isProjected) {
              if (v1.abs() < 15 && v2.abs() > 60) {
                lat = v1;
                lon = v2;
              } else if (v2.abs() < 15 && v1.abs() > 60) {
                lat = v2;
                lon = v1;
              } else {
                lat = v1;
                lon = v2;
              }
            } else {
              lat = v1;
              lon = v2;
            }

            double mx, my;
            if (isProjected) {
              mx = lon;
              my = lat;
            } else if (projection != null) {
              try {
                final p = Projection.get(
                  'EPSG:4326',
                )!.transform(projection, Point(x: lon, y: lat));
                mx = p.x;
                my = p.y;
              } catch (e) {
                mx = lon;
                my = lat;
              }
            } else {
              mx = lon;
              my = lat;
            }
            mapPoints.add(math.Point(mx, my));
          }

          List<math.Point<double>> pdfPoints = [];
          for (int i = 0; i < lpts.length - 1; i += 2) {
            double px = lpts[i] * userUnit, py = lpts[i + 1] * userUnit;
            if (lpts.every((n) => n >= -0.01 && n <= 1.01)) {
              px = px * (mediaWidth + cropX);
              py = py * (mediaHeight + cropY);
            }
            py = mediaHeight - py;
            pdfPoints.add(math.Point(px, py));
          }

          double x1 = pdfPoints[0].x, y1 = pdfPoints[0].y, m1x = mapPoints[0].x;
          double x2 = pdfPoints[1].x, y2 = pdfPoints[1].y, m2x = mapPoints[1].x;
          double x3 = pdfPoints[2].x, y3 = pdfPoints[2].y, m3x = mapPoints[2].x;
          double det = x1 * (y2 - y3) + x2 * (y3 - y1) + x3 * (y1 - y2);
          if (det.abs() > 1e-9) {
            double A =
                (m1x * (y2 - y3) + m2x * (y3 - y1) + m3x * (y1 - y2)) / det;
            double B =
                (m1x * (x3 - x2) + m2x * (x1 - x3) + m3x * (x2 - x1)) / det;
            double C =
                (m1x * (x2 * y3 - x3 * y2) +
                    m2x * (x3 * y1 - x1 * y3) +
                    m3x * (x1 * y2 - x2 * y1)) /
                det;
            double m1y = mapPoints[0].y,
                m2y = mapPoints[1].y,
                m3y = mapPoints[2].y;
            double D =
                (m1y * (y2 - y3) + m2y * (y3 - y1) + m3y * (y1 - y2)) / det;
            double E =
                (m1y * (x3 - x2) + m2y * (x1 - x3) + m3y * (x2 - x1)) / det;
            double F =
                (m1y * (x2 * y3 - x3 * y2) +
                    m2y * (x3 * y1 - x1 * y3) +
                    m3y * (x1 * y2 - x2 * y1)) /
                det;

            double maxLptsX = 0, maxLptsY = 0;
            for (var p in pdfPoints) {
              if (p.x.abs() > maxLptsX) maxLptsX = p.x.abs();
              if (p.y.abs() > maxLptsY) maxLptsY = p.y.abs();
            }
            double logicalWidth = mediaWidth;
            double logicalHeight = mediaHeight;
            if (maxLptsX > mediaWidth * 1.5) {
              logicalWidth = maxLptsX - cropX;
              logicalHeight = maxLptsY - cropY;
            }

            return MapCalibration(
              matrixA: A,
              matrixB: B,
              matrixC: C,
              matrixD: D,
              matrixE: E,
              matrixF: F,
              originalImageWidth: logicalWidth,
              originalImageHeight: logicalHeight,
              cropX: cropX,
              cropY: cropY,
              projectionIdentifier: projId,
              isProjected: isProjected,
              firstGpts: gpts[0],
              firstLpts: lpts[0],
              boundsSouth: bSouth,
              boundsNorth: bNorth,
              boundsWest: bWest,
              boundsEast: bEast,
              minLptsX: minLX,
              minLptsY: minLY,
              maxLptsX: maxLX,
              maxLptsY: maxLY,
            );
          }
        }
      }
    } catch (e) {
      debugInfo = "Error: $e";
    }
    return null;
  }

  MapCalibration? getCalibration(String mapTitle) {
    return _dynamicCalibrations[mapTitle];
  }

  MapSpatialStatus isLocationInMap(
    String mapTitle,
    double lat,
    double lon,
    double mapWidth,
    double mapHeight,
  ) {
    final cal = getCalibration(mapTitle);
    if (cal == null) return MapSpatialStatus.notReferenced;
    final pt = getPixelOffset(
      mapTitle: mapTitle,
      lat: lat,
      lon: lon,
      mapWidth: mapWidth,
      mapHeight: mapHeight,
    );
    if (pt == null) return MapSpatialStatus.outside;
    if (pt.dx >= 0 && pt.dx <= mapWidth && pt.dy >= 0 && pt.dy <= mapHeight)
      return MapSpatialStatus.within;
    return MapSpatialStatus.outside;
  }

  bool isUserInsideMap(String mapTitle, double lat, double lon) {
    final cal = getCalibration(mapTitle);
    if (cal == null) return false;
    final pt = getPixelOffset(
      mapTitle: mapTitle,
      lat: lat,
      lon: lon,
      mapWidth: cal.originalImageWidth,
      mapHeight: cal.originalImageHeight,
    );
    if (pt == null) return false;
    return pt.dx >= 0 &&
        pt.dx <= cal.originalImageWidth &&
        pt.dy >= 0 &&
        pt.dy <= cal.originalImageHeight;
  }

  Offset? getPixelOffset({
    required String mapTitle,
    required double lat,
    required double lon,
    required double mapWidth,
    required double mapHeight,
  }) {
    final cal = _getCalibration(mapTitle);
    if (cal == null) return null;

    double mx, my;
    if (cal.projectionIdentifier != null) {
      try {
        final projection = cal.projectionIdentifier!.startsWith('EPSG:')
            ? Projection.get(cal.projectionIdentifier!)
            : Projection.parse(cal.projectionIdentifier!);
        final p = Projection.get(
          'EPSG:4326',
        )!.transform(projection!, Point(x: lon, y: lat));
        mx = p.x;
        my = p.y;
      } catch (e) {
        mx = lon;
        my = lat;
      }
    } else {
      mx = lon;
      my = lat;
    }

    mx -= cal.manualOffsetX;
    my -= cal.manualOffsetY;

    double det = cal.matrixA * cal.matrixE - cal.matrixB * cal.matrixD;
    if (det.abs() < 1e-15) return null;

    double pdfX =
        ((mx - cal.matrixC) * cal.matrixE - (my - cal.matrixF) * cal.matrixB) /
        det;
    double pdfY =
        (cal.matrixA * (my - cal.matrixF) - cal.matrixD * (mx - cal.matrixC)) /
        det;

    double viewX = pdfX - cal.cropX;
    double viewY = pdfY - cal.cropY;

    double xPercent = viewX / cal.originalImageWidth;
    double yPercent = viewY / cal.originalImageHeight;

    if (xPercent < -10.0 ||
        xPercent > 11.0 ||
        yPercent < -10.0 ||
        yPercent > 11.0)
      return null;
    return Offset(xPercent * mapWidth, yPercent * mapHeight);
  }

  void alignMapByPixel(
    String mapTitle,
    double gpsLat,
    double gpsLon,
    double px,
    double py,
    double mapWidth,
    double mapHeight,
  ) {
    final cal = getCalibration(mapTitle);
    if (cal == null) return;

    double xPercent = px / mapWidth, yPercent = py / mapHeight;
    double viewX = xPercent * cal.originalImageWidth;
    double viewY = yPercent * cal.originalImageHeight;
    double pdfX = viewX + cal.cropX, pdfY = viewY + cal.cropY;

    double mxRaw = cal.matrixA * pdfX + cal.matrixB * pdfY + cal.matrixC;
    double myRaw = cal.matrixD * pdfX + cal.matrixE * pdfY + cal.matrixF;

    if (cal.projectionIdentifier != null) {
      try {
        final projection = cal.projectionIdentifier!.startsWith('EPSG:')
            ? Projection.get(cal.projectionIdentifier!)
            : Projection.parse(cal.projectionIdentifier!);
        final pGPS = Projection.get(
          'EPSG:4326',
        )!.transform(projection!, Point(x: gpsLon, y: gpsLat));
        cal.manualOffsetX = (pGPS.x - mxRaw);
        cal.manualOffsetY = (pGPS.y - myRaw);
      } catch (e) {
        cal.manualOffsetX = (gpsLon - mxRaw);
        cal.manualOffsetY = (gpsLat - myRaw);
      }
    } else {
      cal.manualOffsetX = (gpsLon - mxRaw);
      cal.manualOffsetY = (gpsLat - myRaw);
    }
  }

  Map<String, double>? getLatLonFromPixel({
    required String mapTitle,
    required double px,
    required double py,
    required double mapWidth,
    required double mapHeight,
  }) {
    final cal = _getCalibration(mapTitle);
    if (cal == null) return null;

    double xPercent = px / mapWidth, yPercent = py / mapHeight;
    double viewX = xPercent * cal.originalImageWidth,
        viewY = yPercent * cal.originalImageHeight;
    double pdfX = viewX + cal.cropX, pdfY = viewY + cal.cropY;
    double mx = cal.matrixA * pdfX + cal.matrixB * pdfY + cal.matrixC;
    double my = cal.matrixD * pdfX + cal.matrixE * pdfY + cal.matrixF;

    mx += cal.manualOffsetX;
    my += cal.manualOffsetY;

    if (cal.projectionIdentifier != null) {
      try {
        final projection = cal.projectionIdentifier!.startsWith('EPSG:')
            ? Projection.get(cal.projectionIdentifier!)
            : Projection.parse(cal.projectionIdentifier!);
        final p = projection!.transform(
          Projection.get('EPSG:4326')!,
          Point(x: mx, y: my),
        );
        return {'lat': p.y, 'lon': p.x};
      } catch (e) {
        return {'lat': my, 'lon': mx};
      }
    }
    return {'lat': my, 'lon': mx};
  }

  flutter_map.LatLngBounds? getMapBounds(String mapTitle) {
    final cal = _getCalibration(mapTitle);
    if (cal == null) return null;

    if (cal.boundsSouth != null && cal.boundsNorth != null && cal.boundsWest != null && cal.boundsEast != null) {
      final bounds = flutter_map.LatLngBounds(
        latlong2.LatLng(cal.boundsSouth!, cal.boundsWest!),
        latlong2.LatLng(cal.boundsNorth!, cal.boundsEast!),
      );

      return bounds;
    }

    final corners = [
      getLatLonFromPixel(mapTitle: mapTitle, px: 0, py: 0, mapWidth: cal.originalImageWidth, mapHeight: cal.originalImageHeight),
      getLatLonFromPixel(mapTitle: mapTitle, px: cal.originalImageWidth, py: cal.originalImageHeight, mapWidth: cal.originalImageWidth, mapHeight: cal.originalImageHeight),
    ];

    if (corners[0] == null || corners[1] == null) return null;

    final bounds = flutter_map.LatLngBounds(
      latlong2.LatLng(corners[0]!['lat']!, corners[0]!['lon']!),
      latlong2.LatLng(corners[1]!['lat']!, corners[1]!['lon']!),
    );
    
    // TEMPORARY DEBUG
    print('=== DEBUG GEOREF ===');
    print('Esquina SW: ${bounds.southWest}');
    print('Esquina NE: ${bounds.northEast}');
    print('Proyección usada: ${cal.projectionIdentifier}');
    print('Matriz Afín: A=${cal.matrixA}, B=${cal.matrixB}, C=${cal.matrixC}, D=${cal.matrixD}, E=${cal.matrixE}, F=${cal.matrixF}');
    print('===================');

    return bounds;
  }
}
