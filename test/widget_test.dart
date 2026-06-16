import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:navimap/services/geo_pdf_parser.dart';

void main() {
  test('GeoPdfParser parses empty bytes as null', () {
    final result = GeoPdfParser.parse(Uint8List(0));
    expect(result, isNull);
  });
}
