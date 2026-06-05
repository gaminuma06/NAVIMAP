import 'dart:typed_data';

class ZipFileEntry {
  final String name;
  final Uint8List data;
  final int crc32;

  ZipFileEntry(this.name, this.data) : crc32 = _computeCrc32(data);

  static final List<int> _crcTable = List<int>.generate(256, (i) {
    int c = i;
    for (int k = 0; k < 8; k++) {
      if ((c & 1) != 0) {
        c = 0xEDB88320 ^ (c >>> 1);
      } else {
        c = c >>> 1;
      }
    }
    return c;
  });

  static int _computeCrc32(Uint8List bytes) {
    int crc = 0xFFFFFFFF;
    for (final b in bytes) {
      crc = _crcTable[(crc ^ b) & 0xFF] ^ (crc >>> 8);
    }
    return crc ^ 0xFFFFFFFF;
  }
}

class ZipWriter {
  static Uint8List createZip(List<ZipFileEntry> entries) {
    final builder = BytesBuilder();
    final localHeaderOffsets = <String, int>{};

    // 1. Write local file headers and file data
    for (final entry in entries) {
      final nameBytes = Uint8List.fromList(entry.name.codeUnits);
      localHeaderOffsets[entry.name] = builder.length;

      final header = ByteData(30);
      header.setUint32(0, 0x04034b50, Endian.little); // Local file header signature
      header.setUint16(4, 10, Endian.little); // Version needed to extract (1.0)
      header.setUint16(6, 0, Endian.little); // General purpose bit flag (0)
      header.setUint16(8, 0, Endian.little); // Compression method (0 = store)
      header.setUint16(10, 0, Endian.little); // Last mod file time
      header.setUint16(12, 0, Endian.little); // Last mod file date
      header.setUint32(14, entry.crc32, Endian.little); // CRC-32
      header.setUint32(18, entry.data.length, Endian.little); // Compressed size
      header.setUint32(22, entry.data.length, Endian.little); // Uncompressed size
      header.setUint16(26, nameBytes.length, Endian.little); // File name length
      header.setUint16(28, 0, Endian.little); // Extra field length (0)

      builder.add(header.buffer.asUint8List());
      builder.add(nameBytes);
      builder.add(entry.data);
    }

    final centralDirectoryStart = builder.length;

    // 2. Write central directory headers
    for (final entry in entries) {
      final nameBytes = Uint8List.fromList(entry.name.codeUnits);
      final offset = localHeaderOffsets[entry.name] ?? 0;

      final header = ByteData(46);
      header.setUint32(0, 0x02014b50, Endian.little); // Central directory file header signature
      header.setUint16(4, 20, Endian.little); // Version made by (2.0)
      header.setUint16(6, 10, Endian.little); // Version needed to extract (1.0)
      header.setUint16(8, 0, Endian.little); // General purpose bit flag (0)
      header.setUint16(10, 0, Endian.little); // Compression method (0 = store)
      header.setUint16(12, 0, Endian.little); // Last mod file time
      header.setUint16(14, 0, Endian.little); // Last mod file date
      header.setUint32(16, entry.crc32, Endian.little); // CRC-32
      header.setUint32(20, entry.data.length, Endian.little); // Compressed size
      header.setUint32(24, entry.data.length, Endian.little); // Uncompressed size
      header.setUint16(28, nameBytes.length, Endian.little); // File name length
      header.setUint16(30, 0, Endian.little); // Extra field length (0)
      header.setUint16(32, 0, Endian.little); // File comment length (0)
      header.setUint16(34, 0, Endian.little); // Disk number start (0)
      header.setUint16(36, 0, Endian.little); // Internal file attributes (0)
      header.setUint32(38, 0, Endian.little); // External file attributes (0)
      header.setUint32(42, offset, Endian.little); // Local header offset

      builder.add(header.buffer.asUint8List());
      builder.add(nameBytes);
    }

    final centralDirectorySize = builder.length - centralDirectoryStart;

    // 3. Write end of central directory record
    final eocd = ByteData(22);
    eocd.setUint32(0, 0x06054b50, Endian.little); // End of central directory signature
    eocd.setUint16(4, 0, Endian.little); // Number of this disk (0)
    eocd.setUint16(6, 0, Endian.little); // Disk where central directory starts (0)
    eocd.setUint16(8, entries.length, Endian.little); // Number of central directory records on this disk
    eocd.setUint16(10, entries.length, Endian.little); // Total number of central directory records
    eocd.setUint32(12, centralDirectorySize, Endian.little); // Size of central directory
    eocd.setUint32(16, centralDirectoryStart, Endian.little); // Offset of start of central directory
    eocd.setUint16(20, 0, Endian.little); // Comment length (0)

    builder.add(eocd.buffer.asUint8List());
    return builder.toBytes();
  }
}
