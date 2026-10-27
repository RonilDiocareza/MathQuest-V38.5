import 'dart:io';
import 'package:image/image.dart';

void main() {
  const int sheetCols = 4;
  const int sheetRows = 4;
  const int frameW = 64;
  const int frameH = 64;

  final Image sheet =
      Image(width: sheetCols * frameW, height: sheetRows * frameH);
  sheet.clear(ColorRgba8(0, 0, 0, 0));

  final ColorRgba8 skin = ColorRgba8(238, 195, 132, 255);
  final ColorRgba8 hair = ColorRgba8(56, 32, 17, 255);
  final ColorRgba8 hairShadow = ColorRgba8(38, 24, 12, 255);
  final ColorRgba8 shirt = ColorRgba8(58, 124, 220, 255);
  final ColorRgba8 shirt2 = ColorRgba8(36, 91, 183, 255);
  final ColorRgba8 pants = ColorRgba8(39, 79, 133, 255);
  final ColorRgba8 boots = ColorRgba8(34, 33, 33, 255);
  final ColorRgba8 outline = ColorRgba8(21, 51, 78, 255);
  final ColorRgba8 line = ColorRgba8(243, 252, 253, 255);

  for (int row = 0; row < sheetRows; row++) {
    for (int col = 0; col < sheetCols; col++) {
      final int baseX = col * frameW;
      final int baseY = row * frameH;

      final int walkOffset = row % 4;

      // shadow under the sprite
      fillRect(sheet,
          x1: baseX + 12,
          y1: baseY + 58,
          x2: baseX + 54,
          y2: baseY + 62,
          color: ColorRgba8(25, 25, 30, 120));

      // legs / boots
      final int legLift = (walkOffset == 1 || walkOffset == 3) ? 2 : -2;
      fillRect(sheet,
          x1: baseX + 22,
          y1: baseY + 44,
          x2: baseX + 29,
          y2: baseY + 56 + legLift,
          color: pants);
      fillRect(sheet,
          x1: baseX + 36,
          y1: baseY + 44,
          x2: baseX + 43,
          y2: baseY + 56 - legLift,
          color: pants);
      fillRect(sheet,
          x1: baseX + 20,
          y1: baseY + 55 + legLift,
          x2: baseX + 33,
          y2: baseY + 62 + legLift,
          color: boots);
      fillRect(sheet,
          x1: baseX + 35,
          y1: baseY + 55 - legLift,
          x2: baseX + 48,
          y2: baseY + 62 - legLift,
          color: boots);

      // arms
      final int armSwing = (walkOffset == 0 || walkOffset == 2) ? -1 : 2;
      fillRect(sheet,
          x1: baseX + 13,
          y1: baseY + 29,
          x2: baseX + 18,
          y2: baseY + 41 + armSwing,
          color: outline);
      fillRect(sheet,
          x1: baseX + 46,
          y1: baseY + 29,
          x2: baseX + 51,
          y2: baseY + 41 - armSwing,
          color: outline);

      // body / shirt block
      fillRect(sheet,
          x1: baseX + 21,
          y1: baseY + 28,
          x2: baseX + 43,
          y2: baseY + 47,
          color: shirt);
      fillRect(sheet,
          x1: baseX + 23,
          y1: baseY + 29,
          x2: baseX + 41,
          y2: baseY + 47,
          color: shirt2);
      fillRect(sheet,
          x1: baseX + 26,
          y1: baseY + 34,
          x2: baseX + 38,
          y2: baseY + 39,
          color: line);

      // belt line
      fillRect(sheet,
          x1: baseX + 20,
          y1: baseY + 45,
          x2: baseX + 45,
          y2: baseY + 47,
          color: outline);

      // neck / head
      fillRect(sheet,
          x1: baseX + 28,
          y1: baseY + 19,
          x2: baseX + 36,
          y2: baseY + 26,
          color: skin);
      fillRect(sheet,
          x1: baseX + 22,
          y1: baseY + 7,
          x2: baseX + 43,
          y2: baseY + 24,
          color: skin);

      // face / mask outline
      fillRect(sheet,
          x1: baseX + 23,
          y1: baseY + 8,
          x2: baseX + 42,
          y2: baseY + 23,
          color: skin);
      fillRect(sheet,
          x1: baseX + 24,
          y1: baseY + 6,
          x2: baseX + 40,
          y2: baseY + 8,
          color: hair);
      fillRect(sheet,
          x1: baseX + 25,
          y1: baseY + 5,
          x2: baseX + 40,
          y2: baseY + 7,
          color: hair);

      // hair tuft / top
      fillRect(sheet,
          x1: baseX + 24,
          y1: baseY + 5,
          x2: baseX + 39,
          y2: baseY + 7,
          color: hair);
      fillRect(sheet,
          x1: baseX + 25,
          y1: baseY + 1,
          x2: baseX + 38,
          y2: baseY + 5,
          color: hairShadow);

      // eyes and cheeks
      fillRect(sheet,
          x1: baseX + 25,
          y1: baseY + 13,
          x2: baseX + 27,
          y2: baseY + 14,
          color: outline);
      fillRect(sheet,
          x1: baseX + 37,
          y1: baseY + 13,
          x2: baseX + 39,
          y2: baseY + 14,
          color: outline);
      fillRect(sheet,
          x1: baseX + 23,
          y1: baseY + 17,
          x2: baseX + 25,
          y2: baseY + 18,
          color: ColorRgba8(255, 150, 150, 255));
      fillRect(sheet,
          x1: baseX + 39,
          y1: baseY + 17,
          x2: baseX + 41,
          y2: baseY + 18,
          color: ColorRgba8(255, 150, 150, 255));

      // body outline around sprite silhouette
      drawRect(sheet,
          x1: baseX + 20,
          y1: baseY + 4,
          x2: baseX + 45,
          y2: baseY + 62,
          color: outline);
    }
  }

  final File output = File('assets/images/player/player.png');
  output.parent.createSync(recursive: true);
  output.writeAsBytesSync(PngEncoder().encode(sheet));

  stdout.writeln('Generated ${output.path} (${sheet.width}x${sheet.height})');
}
