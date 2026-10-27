import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/experimental.dart' as flame;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/user_progress_service.dart';
import 'player.dart';
import 'number_item.dart';
import 'npc_question.dart';
import 'question_npc.dart';
import 'tile_map.dart';

class _CollisionBucket {
  final List<int> rectangleIndices = [];
  final List<int> polygonIndices = [];
}

class MathWorldGame extends FlameGame
    with HasKeyboardHandlerComponents, HasCollisionDetection {
  static const double playerFeetCollisionRadius = 6;
  static const double _cameraFollowSpeed = 240;
  static const Color _gameBackgroundColor = Color(0xFF55B83B);

  late Character character;
  late Player player;

  late int correctAnswer;
  final int level;
  List<NumberItem> numberItems = [];

  int num1 = 0;
  int num2 = 0;
  String problem = '';

  double mapWidth = 800;
  double mapHeight = 640;

  bool isGameLoaded = false;
  bool isMovementPaused = false;
  bool hasCollectedCorrectAnswer = false;
  final ValueNotifier<bool> readiness = ValueNotifier(false);
  final Set<int> completedNpcQuestions = {};

  late double deviceScaleFactor;
  late bool isSmallDevice;
  int currentQuestionNumber = 1;
  bool allNpcQuestionsCompleted = false;
  final NpcQuestionCycle _npcQuestionCycle = NpcQuestionCycle();
  final Map<int, List<NpcQuestion>> _npcQuestionPools = {};
  final Map<int, NpcQuestion> _currentNpcQuestions = {};
  final Set<String> _correctlyAnsweredQuestionKeys = {};
  VoidCallback? onNumberCollected;
  VoidCallback? onWrongNumberCollected;
  ValueChanged<NpcQuestion>? onNpcQuestion;
  ValueChanged<int>? onNpcQuestionLocked;

  Vector2 startPosition = Vector2.zero();
  bool _isNpcQuestionOpen = false;

  QuestionNpcPlacement? get nextUnansweredNpcPlacement {
    for (var questionNumber = 1;
        questionNumber <= NpcQuestion.all.length;
        questionNumber++) {
      if (completedNpcQuestions.contains(questionNumber)) continue;
      for (final placement in npcPlacements) {
        if (placement.questionNumber == questionNumber) {
          return placement;
        }
      }
    }
    return null;
  }

  final List<List<ui.Offset>> collisionPolygons = [];
  final List<ui.Rect> collisionRectangles = [];
  final List<({ui.Offset center, double radius})> npcCollisionCircles = [];
  List<QuestionNpcPlacement> npcPlacements = const [];
  static const double _collisionCellSize = 256;
  final Map<(int, int), _CollisionBucket> _collisionBuckets = {};
  final List<ui.Rect> _collisionPolygonBounds = [];
  final List<int> _rectangleQueryStamps = [];
  final List<int> _polygonQueryStamps = [];
  final List<int> _nearbyRectangles = [];
  final List<int> _nearbyPolygons = [];
  int _collisionQueryStamp = 0;
  bool _collisionLookupBuilt = false;
  int _indexedRectangleCount = -1;
  int _indexedPolygonCount = -1;

  MathWorldGame({
    required this.correctAnswer,
    required this.problem,
    this.level = 1,
    this.onNumberCollected,
    this.onWrongNumberCollected,
    this.onNpcQuestion,
    this.onNpcQuestionLocked,
  });

  @override
  Color backgroundColor() => _gameBackgroundColor;

  void _buildCollisionLookup() {
    _collisionBuckets.clear();
    _collisionPolygonBounds
      ..clear()
      ..addAll(collisionPolygons.map(
        (polygon) =>
            polygon.length < 3 ? ui.Rect.zero : _polygonBounds(polygon),
      ));
    _rectangleQueryStamps
      ..clear()
      ..addAll(List<int>.filled(collisionRectangles.length, 0));
    _polygonQueryStamps
      ..clear()
      ..addAll(List<int>.filled(collisionPolygons.length, 0));
    _collisionQueryStamp = 0;

    for (var index = 0; index < collisionRectangles.length; index++) {
      final rectangle = collisionRectangles[index];
      _addToCollisionBuckets(
        rectangle.left,
        rectangle.top,
        rectangle.right,
        rectangle.bottom,
        (bucket) => bucket.rectangleIndices.add(index),
      );
    }

    for (var polygonIndex = 0;
        polygonIndex < _collisionPolygonBounds.length;
        polygonIndex++) {
      if (collisionPolygons[polygonIndex].length < 3) continue;
      final bounds = _collisionPolygonBounds[polygonIndex];
      _addToCollisionBuckets(
        bounds.left,
        bounds.top,
        bounds.right,
        bounds.bottom,
        (bucket) => bucket.polygonIndices.add(polygonIndex),
      );
    }

    _indexedRectangleCount = collisionRectangles.length;
    _indexedPolygonCount = collisionPolygons.length;
    _collisionLookupBuilt = true;
  }

  ui.Rect _polygonBounds(List<ui.Offset> polygon) {
    var left = polygon.first.dx;
    var top = polygon.first.dy;
    var right = left;
    var bottom = top;

    for (final point in polygon.skip(1)) {
      left = point.dx < left ? point.dx : left;
      top = point.dy < top ? point.dy : top;
      right = point.dx > right ? point.dx : right;
      bottom = point.dy > bottom ? point.dy : bottom;
    }

    return ui.Rect.fromLTRB(left, top, right, bottom);
  }

  void _addToCollisionBuckets(
    double left,
    double top,
    double right,
    double bottom,
    void Function(_CollisionBucket bucket) add,
  ) {
    final firstCellX = (left / _collisionCellSize).floor();
    final lastCellX = (right / _collisionCellSize).floor();
    final firstCellY = (top / _collisionCellSize).floor();
    final lastCellY = (bottom / _collisionCellSize).floor();

    for (var cellX = firstCellX; cellX <= lastCellX; cellX++) {
      for (var cellY = firstCellY; cellY <= lastCellY; cellY++) {
        final bucket = _collisionBuckets.putIfAbsent(
          (cellX, cellY),
          _CollisionBucket.new,
        );
        add(bucket);
      }
    }
  }

  bool canPlayerMoveTo(
    Vector2 center,
    double radius, {
    bool checkNpcCollisions = true,
  }) {
    if (center.x - radius < 0 ||
        center.y - radius < 0 ||
        center.x + radius > mapWidth ||
        center.y + radius > mapHeight) {
      return false;
    }

    if (checkNpcCollisions) {
      for (final npcCollider in npcCollisionCircles) {
        final dx = center.x - npcCollider.center.dx;
        final dy = center.y - npcCollider.center.dy;
        final combinedRadius = radius + npcCollider.radius;
        if (dx * dx + dy * dy <= combinedRadius * combinedRadius) {
          return false;
        }
      }
    }

    final circleCenter = ui.Offset(center.x, center.y);

    if (!_collisionLookupBuilt ||
        _indexedRectangleCount != collisionRectangles.length ||
        _indexedPolygonCount != collisionPolygons.length) {
      _buildCollisionLookup();
    }

    if (_collisionQueryStamp == 0x7fffffff) {
      _rectangleQueryStamps.fillRange(0, _rectangleQueryStamps.length, 0);
      _polygonQueryStamps.fillRange(0, _polygonQueryStamps.length, 0);
      _collisionQueryStamp = 0;
    }
    final queryStamp = ++_collisionQueryStamp;
    _nearbyRectangles.clear();
    _nearbyPolygons.clear();

    final firstCellX = ((center.x - radius) / _collisionCellSize).floor();
    final lastCellX = ((center.x + radius) / _collisionCellSize).floor();
    final firstCellY = ((center.y - radius) / _collisionCellSize).floor();
    final lastCellY = ((center.y + radius) / _collisionCellSize).floor();
    for (var cellX = firstCellX; cellX <= lastCellX; cellX++) {
      for (var cellY = firstCellY; cellY <= lastCellY; cellY++) {
        final bucket = _collisionBuckets[(cellX, cellY)];
        if (bucket != null) {
          for (final index in bucket.rectangleIndices) {
            if (_rectangleQueryStamps[index] != queryStamp) {
              _rectangleQueryStamps[index] = queryStamp;
              _nearbyRectangles.add(index);
            }
          }
          for (final index in bucket.polygonIndices) {
            if (_polygonQueryStamps[index] != queryStamp) {
              _polygonQueryStamps[index] = queryStamp;
              _nearbyPolygons.add(index);
            }
          }
        }
      }
    }

    for (final index in _nearbyRectangles) {
      if (_circleIntersectsRectangle(
        circleCenter,
        radius,
        collisionRectangles[index],
      )) {
        return false;
      }
    }

    for (final polygonIndex in _nearbyPolygons) {
      final polygon = collisionPolygons[polygonIndex];
      if (polygon.length < 3) continue;

      if (_collisionPolygonBounds[polygonIndex].contains(circleCenter) &&
          _isInsidePolygon(circleCenter, polygon)) {
        return false;
      }

      for (var vertexIndex = 0; vertexIndex < polygon.length; vertexIndex++) {
        final currentPoint = polygon[vertexIndex];
        final nextPoint = polygon[(vertexIndex + 1) % polygon.length];

        if (_circleHitsLineSegment(
            circleCenter, radius, currentPoint, nextPoint)) {
          return false;
        }
      }
    }

    return true;
  }

  void registerNpcCollisionCircle({
    required ui.Offset center,
    required double radius,
  }) {
    if (!center.dx.isFinite ||
        !center.dy.isFinite ||
        !radius.isFinite ||
        radius <= 0) {
      throw ArgumentError(
          'NPC collision circles require finite positive data.');
    }
    npcCollisionCircles.add((center: center, radius: radius));
  }

  void checkNpcCollisionsAt(Vector2 playerCenter, double playerRadius) {
    for (final npc in world.children.query<QuestionNpc>()) {
      npc.checkPlayerContactAt(playerCenter, playerRadius);
    }
  }

  bool _circleIntersectsRectangle(
    ui.Offset circleCenter,
    double radius,
    ui.Rect rectangle,
  ) {
    final closestX = circleCenter.dx.clamp(rectangle.left, rectangle.right);
    final closestY = circleCenter.dy.clamp(rectangle.top, rectangle.bottom);

    final dx = circleCenter.dx - closestX;
    final dy = circleCenter.dy - closestY;

    return (dx * dx + dy * dy) <= (radius * radius);
  }

  bool _circleHitsLineSegment(
    ui.Offset center,
    double radius,
    ui.Offset start,
    ui.Offset end,
  ) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final lengthSquared = dx * dx + dy * dy;

    if (lengthSquared == 0) {
      final diffX = center.dx - start.dx;
      final diffY = center.dy - start.dy;
      return (diffX * diffX + diffY * diffY) <= (radius * radius);
    }

    final projection =
        ((center.dx - start.dx) * dx + (center.dy - start.dy) * dy) /
            lengthSquared;
    final clampedT = projection.clamp(0.0, 1.0);

    final closestX = start.dx + dx * clampedT;
    final closestY = start.dy + dy * clampedT;

    final offsetX = center.dx - closestX;
    final offsetY = center.dy - closestY;

    return (offsetX * offsetX + offsetY * offsetY) <=
        (radius * radius + 0.0001);
  }

  bool _isInsidePolygon(ui.Offset point, List<ui.Offset> polygon) {
    var inside = false;
    for (var index = 0, previous = polygon.length - 1;
        index < polygon.length;
        previous = index++) {
      final currentPoint = polygon[index];
      final previousPoint = polygon[previous];

      final crosses =
          (currentPoint.dy > point.dy) != (previousPoint.dy > point.dy);

      if (crosses &&
          point.dx <
              (previousPoint.dx - currentPoint.dx) *
                      (point.dy - currentPoint.dy) /
                      (previousPoint.dy - currentPoint.dy) +
                  currentPoint.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  @override
  Future<void> onLoad() async {
    var stage = 'base game setup';
    try {
      await super.onLoad();
      _calculateResponsiveScaling();

      stage = 'Tiled map data';
      debugPrint('Game initialization: loading Tiled map data.');
      final mapData = await TileMap.loadMapData();
      mapWidth = (mapData['worldWidth'] as int).toDouble();
      mapHeight = (mapData['worldHeight'] as int).toDouble();
      if (!mapWidth.isFinite ||
          !mapHeight.isFinite ||
          mapWidth <= 0 ||
          mapHeight <= 0) {
        throw StateError('The Tiled map has invalid world bounds.');
      }
      collisionRectangles
        ..clear()
        ..addAll(mapData['collisionRectangles'] as List<ui.Rect>);
      collisionPolygons
        ..clear()
        ..addAll(
          (mapData['collisionPolygons'] as List).cast<List<ui.Offset>>(),
        );
      _buildCollisionLookup();

      startPosition = Vector2(570, 620);
      final zoom = _mapZoom;
      if (!zoom.isFinite || zoom <= 0) {
        throw StateError('The game camera has an invalid zoom value.');
      }
      camera.viewfinder
        ..anchor = Anchor.center
        ..zoom = zoom
        ..position = startPosition.clone();

      final tileMap = TileMap(mapData: mapData);
      world.add(tileMap);
      await tileMap.loaded;
      debugPrint('Game initialization: Tiled map loaded.');

      stage = 'Firestore character lookup';
      final characterId = await _loadCharacterId();

      stage = 'player sprite';
      character = Character(characterId: characterId)
        ..position = startPosition.clone()
        ..anchor = Anchor.center;
      player = character;
      world.add(player);
      await player.loaded;
      debugPrint('Game initialization: player loaded ($characterId).');

      stage = 'NPC sprites';
      await _loadNpcQuestionProgress();
      await loadCorrectQuestionHistory();
      npcPlacements = NpcQuestion.createNpcPlacements(
        playerSpawn: startPosition,
        canOccupy: (center, radius) => canPlayerMoveTo(center, radius),
        level: level,
        random: Random(),
      );
      final questionNpcs = <QuestionNpc>[];
      for (final placement in npcPlacements) {
        final question = NpcQuestion.forPlacement(placement);
        if (question == null) {
          throw StateError(
            'No question is configured for NPC "${placement.questionId}".',
          );
        }
        _questionPoolForNpc(question);
        final npc = QuestionNpc(
          question: question,
          spriteAssetPath: placement.spriteAssetPath,
          position: placement.position,
          collisionRadius: placement.collisionRadius,
        );
        registerNpcCollisionCircle(
          center: ui.Offset(
            placement.position.x,
            placement.position.y - placement.collisionRadius,
          ),
          radius: placement.collisionRadius,
        );
        questionNpcs.add(npc);
        world.add(npc);
      }
      await _loadNpcQuestionHistory();
      await Future.wait(questionNpcs.map((npc) => npc.loaded));
      debugPrint('Game initialization: ${questionNpcs.length} NPCs loaded.');
      if (nextUnansweredNpcPlacement != null && !allNpcQuestionsCompleted) {
        world.add(QuestionArrowGuide());
      }

      stage = 'camera initialization';
      _updateCameraBounds();
      camera.follow(
        player,
        maxSpeed: _cameraFollowSpeed,
        snap: true,
      );
      debugPrint('Game initialization: camera following player.');

      isGameLoaded = true;
      readiness.value = true;
      debugPrint('Game initialization complete.');
    } catch (error, stackTrace) {
      debugPrint('Game initialization failed during $stage: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  void onRemove() {
    readiness.dispose();
    super.onRemove();
  }

  Future<String> _loadCharacterId() async {
    try {
      final uid = AuthService.currentUser?.uid;
      if (uid == null) return 'boy';
      final account = await AuthService.getAccount(uid).timeout(
        const Duration(seconds: 5),
      );
      return account?.character == 'girl' ? 'girl' : 'boy';
    } catch (error, stackTrace) {
      debugPrint('Unable to load Firestore character; using Boy: $error');
      debugPrintStack(stackTrace: stackTrace);
      return 'boy';
    }
  }

  Future<void> _loadNpcQuestionProgress() async {
    try {
      final uid = AuthService.currentUser?.uid;
      if (uid == null) return;
      final progress = await UserProgressService.getProgressForUid(uid).timeout(
        const Duration(seconds: 5),
      );
      completedNpcQuestions
        ..clear()
        ..addAll(progress.completedNpcQuestionsForLevel(level));
      currentQuestionNumber = progress.currentNpcQuestionNumberForLevel(level);
      allNpcQuestionsCompleted =
          progress.areNpcQuestionsCompletedForLevel(level);
      debugPrint(
        'Loaded NPC question progress for level $level: '
        '${completedNpcQuestions.length}/${NpcQuestion.all.length} completed.',
      );
    } catch (error, stackTrace) {
      debugPrint('Unable to load NPC question progress: $error');
      debugPrintStack(stackTrace: stackTrace);
      currentQuestionNumber = 1;
      completedNpcQuestions.clear();
      allNpcQuestionsCompleted = false;
    }
  }

  void interactWithNpc(NpcQuestion question) {
    if (!isGameLoaded ||
        isMovementPaused ||
        allNpcQuestionsCompleted ||
        _isNpcQuestionOpen ||
        completedNpcQuestions.contains(question.questionNumber)) {
      return;
    }

    if (question.questionNumber < currentQuestionNumber) return;
    if (question.questionNumber > currentQuestionNumber) {
      onNpcQuestionLocked?.call(currentQuestionNumber);
      return;
    }
    openNpcQuestion(questionForNpc(question));
  }

  NpcQuestion questionForNpc(NpcQuestion originalQuestion) {
    return _currentNpcQuestions.putIfAbsent(
      originalQuestion.questionNumber,
      () => _nextQuestionForNpc(originalQuestion),
    );
  }

  List<NpcQuestion> _questionPoolForNpc(NpcQuestion originalQuestion) {
    return _npcQuestionPools.putIfAbsent(originalQuestion.questionNumber, () {
      final extras = NpcQuestion.extraQuestionsForLevel(
        originalQuestion.questionNumber,
        level,
        random: Random(),
      ).toList()
        ..shuffle(Random());
      return [originalQuestion, ...extras];
    });
  }

  NpcQuestion _nextQuestionForNpc(NpcQuestion originalQuestion) {
    final pool = _questionPoolForNpc(originalQuestion);
    var available = _availableQuestions(pool);
    for (var attempt = 0; available.isEmpty && attempt < 32; attempt++) {
      final generated = NpcQuestion.extraQuestionsForLevel(
        originalQuestion.questionNumber,
        level,
        random: Random(),
      );
      final existingKeys = pool
          .map((question) => NpcQuestion.normalizedPrompt(question.prompt))
          .toSet();
      for (final question in generated) {
        final key = NpcQuestion.normalizedPrompt(question.prompt);
        if (!_correctlyAnsweredQuestionKeys.contains(key) &&
            existingKeys.add(key)) {
          pool.add(question);
        }
      }
      available = _availableQuestions(pool);
    }
    if (available.isEmpty) {
      throw StateError(
        'Could not generate an unused question for NPC '
        '${originalQuestion.questionNumber} at level $level.',
      );
    }
    final question = _npcQuestionCycle.nextForNpc(available);
    _saveNpcQuestionHistory(originalQuestion.questionNumber);
    return question;
  }

  List<NpcQuestion> _availableQuestions(List<NpcQuestion> pool) => pool
      .where(
        (question) => !_correctlyAnsweredQuestionKeys
            .contains(NpcQuestion.normalizedPrompt(question.prompt)),
      )
      .toList(growable: false);

  NpcQuestion nextNpcQuestionAfterIncorrect(int questionNumber) {
    final pool = _npcQuestionPools[questionNumber];
    if (pool == null) {
      throw StateError(
        'NPC $questionNumber has no active question cycle to advance.',
      );
    }
    final original = pool.first;
    final question = _nextQuestionForNpc(original);
    _currentNpcQuestions[questionNumber] = question;
    return question;
  }

  Future<void> recordCorrectlyAnsweredQuestion(NpcQuestion question) async {
    final key = NpcQuestion.normalizedPrompt(question.prompt);
    restoreCorrectQuestionHistory([key]);
    final uid = AuthService.currentUser?.uid ?? 'guest';
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedKeys = _correctlyAnsweredQuestionKeys.toList()..sort();
      final saved = await preferences.setStringList(
        'mathquest.game-mode-correct-question-history.v1.$uid',
        savedKeys,
      );
      if (!saved) {
        throw StateError('Local storage rejected correct question history.');
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Correct Game Mode answer was saved remotely, but its local '
        'question-history cache could not be updated: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> loadCorrectQuestionHistory() => _loadCorrectQuestionHistory();

  void restoreCorrectQuestionHistory(Iterable<String> questionKeys) {
    _correctlyAnsweredQuestionKeys.addAll(
      questionKeys.map(NpcQuestion.normalizedPrompt),
    );
  }

  String _npcQuestionHistoryKey(int npcNumber) {
    final userId = AuthService.currentUser?.uid ?? 'guest';
    return 'mathquest.npc-question-history.v1.$userId.$level.$npcNumber';
  }

  Future<void> _loadCorrectQuestionHistory() async {
    final uid = AuthService.currentUser?.uid;
    final userId = uid ?? 'guest';
    final cacheKey = 'mathquest.game-mode-correct-question-history.v1.$userId';
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
      _correctlyAnsweredQuestionKeys.addAll(
        preferences.getStringList(cacheKey) ?? const <String>[],
      );
    } catch (error, stackTrace) {
      debugPrint('Unable to load cached correct-question history: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    if (uid != null) {
      final savedQuestions =
          await UserProgressService.getCorrectGameModeQuestions(uid: uid)
              .timeout(const Duration(seconds: 15));
      _correctlyAnsweredQuestionKeys.addAll(
        savedQuestions.map(NpcQuestion.normalizedPrompt),
      );
      if (preferences != null) {
        try {
          final saved = await preferences.setStringList(
            cacheKey,
            _correctlyAnsweredQuestionKeys.toList()..sort(),
          );
          if (!saved) {
            throw StateError(
              'Local storage rejected correct question history.',
            );
          }
        } catch (error, stackTrace) {
          debugPrint('Unable to cache correct-question history: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
    }
  }

  Future<void> _loadNpcQuestionHistory() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      for (final entry in _npcQuestionPools.entries) {
        final questionIds =
            preferences.getStringList(_npcQuestionHistoryKey(entry.key)) ??
                const <String>[];
        _npcQuestionCycle.restoreShownQuestionIds(
          entry.key,
          questionIds,
          validQuestionIds: entry.value.map((question) => question.id).toSet(),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to load NPC question history: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _saveNpcQuestionHistory(int npcNumber) {
    final questionIds =
        _npcQuestionCycle.shownQuestionIdsForNpc(npcNumber).toList();
    unawaited(_writeNpcQuestionHistory(npcNumber, questionIds));
  }

  Future<void> _writeNpcQuestionHistory(
    int npcNumber,
    List<String> questionIds,
  ) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setStringList(
        _npcQuestionHistoryKey(npcNumber),
        questionIds,
      );
      if (!saved) {
        throw StateError('Local storage rejected NPC question history.');
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to save NPC question history: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool> completeNpcQuestion(int questionNumber) async {
    if (!isGameLoaded ||
        allNpcQuestionsCompleted ||
        questionNumber != currentQuestionNumber ||
        completedNpcQuestions.contains(questionNumber)) {
      return false;
    }

    final uid = AuthService.currentUser?.uid;
    final saved = await UserProgressService.completeNpcQuestion(
      questionNumber,
      uid: uid,
      level: level,
    );
    if (!saved) {
      await _loadNpcQuestionProgress();
      return false;
    }

    completedNpcQuestions.add(questionNumber);
    if (questionNumber == NpcQuestion.all.length) {
      allNpcQuestionsCompleted = true;
    } else {
      currentQuestionNumber = questionNumber + 1;
    }
    return true;
  }

  void openNpcQuestion(NpcQuestion question) {
    final callback = onNpcQuestion;
    if (_isNpcQuestionOpen || callback == null) return;

    _isNpcQuestionOpen = true;
    pauseWorld();
    callback(question);
  }

  void closeNpcQuestion() {
    if (!_isNpcQuestionOpen) return;

    _isNpcQuestionOpen = false;
    resumeWorld();
  }

  void startMoveLeft() {
    if (isGameLoaded) player.moveDirection.x = -1;
  }

  void startMoveRight() {
    if (isGameLoaded) player.moveDirection.x = 1;
  }

  void startMoveUp() {
    if (isGameLoaded) player.moveDirection.y = -1;
  }

  void startMoveDown() {
    if (isGameLoaded) player.moveDirection.y = 1;
  }

  void stopMove() {
    if (isGameLoaded) player.moveDirection.setZero();
  }

  void pauseWorld() {
    isMovementPaused = true;
    if (!isGameLoaded) return;
    stopMove();
    player.lastMove.setZero();
    player.isMoving = false;
  }

  void resumeWorld() {
    isMovementPaused = false;
    if (!isGameLoaded) return;
    player.moveDirection.setZero();
    player.isMoving = false;
  }

  void _calculateResponsiveScaling() {
    final screenDiagonal = sqrt((size.x * size.x) + (size.y * size.y));
    isSmallDevice = screenDiagonal < 1000;
    deviceScaleFactor = (size.x / 400).clamp(0.6, 1.5);
    mapWidth = mapWidth.clamp(1.0, double.infinity);
    mapHeight = mapHeight.clamp(1.0, double.infinity);
  }

  double get _mapZoom {
    return calculateResponsiveCameraZoom(
      viewportSize: size,
      mapSize: Vector2(mapWidth, mapHeight),
    );
  }

  static double calculateResponsiveCameraZoom({
    required Vector2 viewportSize,
    required Vector2 mapSize,
  }) {
    if (viewportSize.x <= 0 ||
        viewportSize.y <= 0 ||
        mapSize.x <= 0 ||
        mapSize.y <= 0) {
      return 1.0;
    }

    return max(
          viewportSize.x / mapSize.x,
          viewportSize.y / mapSize.y,
        ) *
        2;
  }

  void _updateCameraBounds() {
    final zoom = _mapZoom;
    camera.viewfinder.zoom = zoom;
    camera.setBounds(
      calculateCameraCenterBounds(
        viewportSize: size,
        mapSize: Vector2(mapWidth, mapHeight),
        zoom: zoom,
      ),
    );
  }

  static flame.Rectangle calculateCameraCenterBounds({
    required Vector2 viewportSize,
    required Vector2 mapSize,
    required double zoom,
  }) {
    if (viewportSize.x <= 0 ||
        viewportSize.y <= 0 ||
        mapSize.x <= 0 ||
        mapSize.y <= 0 ||
        !zoom.isFinite ||
        zoom <= 0) {
      throw ArgumentError('Viewport, map size, and zoom must be positive.');
    }

    final halfVisibleWorldWidth = viewportSize.x / zoom / 2;
    final halfVisibleWorldHeight = viewportSize.y / zoom / 2;
    return flame.Rectangle.fromLTRB(
      halfVisibleWorldWidth,
      halfVisibleWorldHeight,
      mapSize.x - halfVisibleWorldWidth,
      mapSize.y - halfVisibleWorldHeight,
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      _calculateResponsiveScaling();
      _updateCameraBounds();
    }
  }

  void spawnNumbers() {
    numberItems.clear();
  }
}

class QuestionArrowGuide extends PositionComponent
    with HasGameReference<MathWorldGame> {
  static const double _headOffset = 38;
  static const double _arrowWidth = 20;
  static const double _arrowHeight = 22;
  static const double _rotationResponse = 12;
  static const double _bobAmplitude = 1.25;
  static const double _bobFrequency = 1.8;

  double _elapsed = 0;
  bool _hasDirection = false;

  QuestionArrowGuide()
      : super(
          size: Vector2(_arrowWidth, _arrowHeight),
          anchor: Anchor.center,
          priority: 1 << 30,
        );

  @override
  void update(double dt) {
    super.update(dt);
    if (!game.isGameLoaded) return;

    final target = game.nextUnansweredNpcPlacement;
    if (target == null || game.allNpcQuestionsCompleted) {
      removeFromParent();
      return;
    }

    final direction = target.position - game.player.position;
    _elapsed += dt;
    final bob = sin(_elapsed * _bobFrequency * 2 * pi) * _bobAmplitude;
    position.setFrom(
      game.player.position + Vector2(0, -_headOffset + bob),
    );

    if (direction.length2 == 0) return;
    final targetAngle = atan2(direction.y, direction.x) + pi / 2;
    if (!_hasDirection) {
      angle = targetAngle;
      _hasDirection = true;
      return;
    }

    final fullTurn = 2 * pi;
    final shortestTurn =
        ((targetAngle - angle + pi) % fullTurn + fullTurn) % fullTurn - pi;
    angle += shortestTurn * (1 - exp(-_rotationResponse * dt));
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    final arrow = Path()
      ..moveTo(0, -10)
      ..quadraticBezierTo(0.6, -10, 1.1, -9.4)
      ..lineTo(7, -2.5)
      ..quadraticBezierTo(8, -1.3, 6.5, -1.3)
      ..lineTo(2.2, -1.3)
      ..lineTo(2.2, 7)
      ..quadraticBezierTo(2.2, 8, 1.2, 8)
      ..lineTo(-1.2, 8)
      ..quadraticBezierTo(-2.2, 8, -2.2, 7)
      ..lineTo(-2.2, -1.3)
      ..lineTo(-6.5, -1.3)
      ..quadraticBezierTo(-8, -1.3, -7, -2.5)
      ..lineTo(-1.1, -9.4)
      ..quadraticBezierTo(-0.6, -10, 0, -10)
      ..close();
    canvas.drawPath(
      arrow,
      Paint()
        ..color = const Color(0x99543F2B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      arrow,
      Paint()
        ..color = const Color(0xE8E4C879)
        ..style = PaintingStyle.fill,
    );
    canvas.restore();
  }
}
