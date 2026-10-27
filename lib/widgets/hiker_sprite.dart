import 'package:flutter/material.dart';

/// Simple sprite wrapper that uses the project's player PNG
/// as a 4x4 sprite sheet and exposes `column`/`row`.
class HikerSprite extends StatelessWidget {
  final int column;
  final int row;
  final double width;
  final double height;
  final String assetPath;

  const HikerSprite({
    super.key,
    this.column = 0,
    this.row = 0,
    this.width = 45,
    this.height = 45,
    this.assetPath = 'assets/images/player/player.png',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: FittedBox(
        fit: BoxFit.contain,
        child: ClipRect(
          child: Align(
            alignment: FractionalOffset(column / 3.0, row / 3.0),
            widthFactor: 0.25,
            heightFactor: 0.25,
            child: Image.asset(assetPath, filterQuality: FilterQuality.none),
          ),
        ),
      ),
    );
  }
}
