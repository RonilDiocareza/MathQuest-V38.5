import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart';

void main() {
  final mapFile = File('assets/kenney_medieval-rts/map.png');
  final mapJsonFile = File('assets/kenney_medieval-rts/map.json');
  final outputFile = File('assets/kenney_medieval-rts/tiled_map.json');

  if (!mapFile.existsSync()) {
    stderr.writeln('Missing assets/kenney_medieval-rts/map.png');
    exit(1);
  }

  final image = decodeImage(mapFile.readAsBytesSync());
  if (image == null) {
    stderr.writeln('Unable to decode map.png');
    exit(1);
  }

  const tileWidth = 64;
  const tileHeight = 64;
  final cols = image.width ~/ tileWidth;
  final rows = image.height ~/ tileHeight;
  final data = List<int>.generate(cols * rows, (index) => index + 1);

  final collisionObjects = <Map<String, dynamic>>[];
  if (mapJsonFile.existsSync()) {
    try {
      final decoded =
          json.decode(mapJsonFile.readAsStringSync()) as Map<String, dynamic>;
      final structures = (decoded['structures'] as List?) ?? [];
      for (final item in structures) {
        if (item is List && item.length >= 2) {
          final x = int.tryParse(item[0].toString());
          final y = int.tryParse(item[1].toString());
          if (x != null && y != null) {
            collisionObjects.add({
              'id': collisionObjects.length + 1,
              'name': 'structure',
              'type': 'collision',
              'x': x * tileWidth,
              'y': y * tileHeight,
              'width': tileWidth,
              'height': tileHeight,
              'rotation': 0,
              'visible': true,
              'properties': [],
            });
          }
        }
      }
    } catch (e) {
      stderr.writeln('Warning: could not parse map.json: $e');
    }
  }

  final tiledMap = {
    'height': rows,
    'width': cols,
    'tilewidth': tileWidth,
    'tileheight': tileHeight,
    'orientation': 'orthogonal',
    'renderorder': 'right-down',
    'nextlayerid': 3,
    'nextobjectid': collisionObjects.length + 1,
    'layers': [
      {
        'id': 1,
        'name': 'Ground',
        'type': 'tilelayer',
        'x': 0,
        'y': 0,
        'width': cols,
        'height': rows,
        'visible': true,
        'opacity': 1,
        'data': data,
      },
      {
        'id': 2,
        'name': 'Collision',
        'type': 'objectgroup',
        'visible': true,
        'opacity': 1,
        'objects': collisionObjects,
      }
    ],
    'tilesets': [
      {
        'firstgid': 1,
        'name': 'full_map',
        'tilewidth': tileWidth,
        'tileheight': tileHeight,
        'tilecount': data.length,
        'columns': cols,
        'image': 'map.png',
        'imagewidth': image.width,
        'imageheight': image.height,
      }
    ],
  };

  outputFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(tiledMap));
  print('Generated ${outputFile.path}');
  print('Map size: ${image.width}x${image.height} (${cols}x$rows tiles)');
  print('Collision objects: ${collisionObjects.length}');
}
