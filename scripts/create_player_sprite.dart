import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

int crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (var b in bytes) {
    crc ^= b;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

void setPixel(List<int> pixels, int size, int x, int y, List<int> color) {
  var idx = (y * size + x) * 4;
  pixels[idx] = color[0];
  pixels[idx + 1] = color[1];
  pixels[idx + 2] = color[2];
  pixels[idx + 3] = color[3];
}

void main() {
  const size = 128;
  final pixels = List<int>.filled(size * size * 4, 0);

  final outline = [0, 0, 0, 255];
  final skin = [255, 204, 153, 255];
  final hair = [78, 52, 46, 255];
  final shirt = [21, 101, 192, 255];
  final pants = [62, 39, 35, 255];
  final boot = [33, 33, 33, 255];

  for (var fy = 0; fy < 4; fy++) {
    for (var fx = 0; fx < 4; fx++) {
      final baseX = fx * 32;
      final baseY = fy * 32;
      final frameIndex = fy * 4 + fx;
      final armOffset = (frameIndex % 4) - 1;

      for (var y = 0; y < 32; y++) {
        for (var x = 0; x < 32; x++) {
          final gx = baseX + x;
          final gy = baseY + y;
          List<int> color = [0, 0, 0, 0];

          if ((x - 16) * (x - 16) + (y - 10) * (y - 10) <= 49) {
            color = skin;
          }
          if (x >= 10 && x <= 22 && y >= 14 && y <= 26) {
            color = shirt;
          }
          if (x >= 12 && x <= 14 && y >= 26 && y <= 36) {
            color = pants;
          }
          if (x >= 18 && x <= 20 && y >= 26 && y <= 36) {
            color = pants;
          }
          if (x >= 12 && x <= 14 && y >= 36 && y <= 40) {
            color = boot;
          }
          if (x >= 18 && x <= 20 && y >= 36 && y <= 40) {
            color = boot;
          }
          if ((x - 16).abs() <= 5 && y >= 4 && y <= 8) {
            color = hair;
          }
          if (x >= 22 + armOffset &&
              x <= 24 + armOffset &&
              y >= 18 &&
              y <= 24) {
            color = shirt;
          }
          if (x >= 8 - armOffset && x <= 10 - armOffset && y >= 18 && y <= 24) {
            color = shirt;
          }
          if (color[3] == 0) {
            if ((x == 9 || x == 23) && y >= 13 && y <= 25) {
              color = outline;
            }
            if ((y == 13 || y == 25) && x >= 10 && x <= 23) {
              color = outline;
            }
            if ((x == 16 || x == 17) && y == 7) {
              color = outline;
            }
          }

          setPixel(pixels, size, gx, gy, color);
        }
      }
    }
  }

  final data = BytesBuilder();
  data.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

  void chunk(String tag, List<int> bytes) {
    final tagBytes = utf8.encode(tag);
    final len = ByteData(4)..setUint32(0, bytes.length, Endian.big);
    data.add(len.buffer.asUint8List());
    data.add(tagBytes);
    data.add(bytes);
    final crc = crc32(tagBytes + bytes);
    final crcBytes = ByteData(4)..setUint32(0, crc, Endian.big);
    data.add(crcBytes.buffer.asUint8List());
  }

  final rowBytes = <int>[];
  for (var y = 0; y < size; y++) {
    rowBytes.add(0);
    rowBytes.addAll(pixels.sublist(y * size * 4, y * size * 4 + size * 4));
  }
  final raw = ZLibEncoder().convert(Uint8List.fromList(rowBytes));

  final ihdr = ByteData(13)
    ..setUint32(0, size, Endian.big)
    ..setUint32(4, size, Endian.big)
    ..setUint8(8, 8)
    ..setUint8(9, 6)
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);

  chunk('IHDR', ihdr.buffer.asUint8List());
  chunk('IDAT', raw);
  chunk('IEND', []);

  final path1 = File('assets/images/player/player.png');
  final path2 = File('assets/images/player.png');
  path1.createSync(recursive: true);
  path2.createSync(recursive: true);
  path1.writeAsBytesSync(data.toBytes());
  path2.writeAsBytesSync(data.toBytes());
  print('Wrote sprite to ${path1.path} and ${path2.path}');
}
