import 'dart:io';

void main() async {
  final dir = Directory('../../../assets/maps');
  final files = dir.listSync().whereType<File>().toList();
  for (var file in files) {
    if (file.path.endsWith('.pdf')) {
      print('=== ${file.path} ===');
      final bytes = await file.readAsBytes();
      final content = String.fromCharCodes(
        bytes.take(200000).toList(),
      ); // Only need first chunk to find metadata

      final mediaBoxMatch = RegExp(
        r'/MediaBox\s*\[(.*?)\]',
      ).firstMatch(content);
      if (mediaBoxMatch != null) print('MediaBox: [${mediaBoxMatch.group(1)}]');

      final cropBoxMatch = RegExp(r'/CropBox\s*\[(.*?)\]').firstMatch(content);
      if (cropBoxMatch != null) print('CropBox: [${cropBoxMatch.group(1)}]');

      final gptsMatch = RegExp(r'/GPTS\s*\[(.*?)\]').firstMatch(content);
      if (gptsMatch != null) print('GPTS: [${gptsMatch.group(1)}]');

      final lptsMatch = RegExp(r'/LPTS\s*\[(.*?)\]').firstMatch(content);
      if (lptsMatch != null) print('LPTS: [${lptsMatch.group(1)}]');

      final wktMatch = RegExp(r'/WKT\s*\((.*?)\)').firstMatch(content);
      if (wktMatch != null) print('WKT: ${wktMatch.group(1)}');

      final bboxMatch = RegExp(r'/BBox\s*\[(.*?)\]').firstMatch(content);
      if (bboxMatch != null) print('BBox: [${bboxMatch.group(1)}]');

      final bboxMatches = RegExp(r'/BBox\s*\[(.*?)\]').allMatches(content);
      print('All BBox matches:');
      for (var m in bboxMatches) {
        print('  [${m.group(1)}]');
      }

      print('');
    }
  }
}
