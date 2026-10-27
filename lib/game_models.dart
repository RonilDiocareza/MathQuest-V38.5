import 'dart:math' as math;

enum ObjType { tree, bush, stone, litter, bird }

class WorldObject {
  math.Point<double> position;
  String asset;
  double size;
  ObjType type;
  bool isActive;
  int? dbIndex;
  int spriteType;

  WorldObject({
    required this.position,
    required this.asset,
    required this.size,
    required this.type,
    this.dbIndex,
    this.spriteType = 0,
  }) : isActive = true;
}

class FloorPatch {
  math.Point<double> position;
  double width;
  double height;
  
  FloorPatch({required this.position, required this.width, required this.height});
}
