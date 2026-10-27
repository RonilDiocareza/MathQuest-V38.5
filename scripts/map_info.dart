import 'dart:io';
import 'package:image/image.dart';

void main() {
  final file = File('assets/kenney_medieval-rts/map.png');
  if (!file.existsSync()) {
    stderr.writeln('File not found: ${file.path}');
    exit(1);
  }
  final bytes = file.readAsBytesSync();
  final img = decodeImage(bytes);
  if (img == null) {
    stderr.writeln('Could not decode image');
    exit(1);
  }
  print('size: ${img.width}x${img.height}');
  print('channels: ${img.numChannels}');
  print('tile size guess: 64');
  print('cols: ${img.width ~/ 64}, rows: ${img.height ~/ 64}');
}
