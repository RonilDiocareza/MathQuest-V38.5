import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../game_models.dart';
import '../gamedata.dart';
import '../result_dialog.dart';
import '../game_joystick.dart';
import '../char_dialog.dart';
import '../litter_dialog.dart';
import '../widgets/hiker_sprite.dart';
import '../widgets/custom_button.dart';
import '../services/leaderboard_service.dart';

class BirdSpottingScreen extends StatefulWidget {
  final int moduleId;
  final Function({required bool passed, required int score}) onComplete;
  const BirdSpottingScreen(
      {super.key, required this.moduleId, required this.onComplete});

  @override
  State<BirdSpottingScreen> createState() => _BirdSpottingScreenState();
}

class _BirdSpottingScreenState extends State<BirdSpottingScreen> {
  double playerX = 0;
  double playerY = 0;
  double walkableBoundary = 2500.0;

  Offset joystickOffset = Offset.zero;
  Timer? movementTimer;

  int spriteColumn = 0;
  int spriteRow = 0;
  int walkFrameTimer = 0;

  int playerHealth = 3;
  int litterCleaned = 0;
  int birdsSpotted = 0;
  int score = 0;
  bool isMissionOpen = false;
  WorldObject? nearbyObject;

  List<WorldObject> depthSortedObjects = [];
  List<FloorPatch> dirtPockets = [];

  final bgPlayer = AudioPlayer();
  final sfxPlayer = AudioPlayer();
  bool isMusicPlaying = true;
  bool _isLeaving = false;
  final Map<WorldObject, String> _scoreAwardIds = {};
  final Set<String> _savingScoreAwardIds = {};

  String _scoreAwardIdFor(WorldObject object) =>
      _scoreAwardIds.putIfAbsent(object, LeaderboardService.newScoreAwardId);

  Future<void> _saveLeaderboardPoints(int points, String awardId) async {
    if (!_savingScoreAwardIds.add(awardId)) return;
    try {
      await LeaderboardService.addPoints(points, awardId: awardId);
    } catch (error, stackTrace) {
      final firebaseDetails =
          error is FirebaseException ? ' (${error.plugin}/${error.code})' : '';
      debugPrint('Unable to save leaderboard points$firebaseDetails: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      final canRetry = error is! FirebaseException ||
          !{'permission-denied', 'unauthenticated'}.contains(error.code);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is FirebaseException &&
                    {'unavailable', 'deadline-exceeded', 'aborted'}
                        .contains(error.code)
                ? 'Your score is still waiting to save. Check your connection and retry.'
                : 'Could not save your leaderboard score${error is FirebaseException ? ' (${error.code})' : ''}.',
          ),
          action: canRetry
              ? SnackBarAction(
                  label: 'Retry',
                  onPressed: () =>
                      unawaited(_saveLeaderboardPoints(points, awardId)),
                )
              : null,
        ),
      );
    } finally {
      _savingScoreAwardIds.remove(awardId);
    }
  }

  @override
  void initState() {
    super.initState();
    _initAudio();
    _generateMtPalayPalay();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showStartDialog();
    });

    movementTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (playerHealth > 0 && !isMissionOpen) {
        if (joystickOffset != Offset.zero) {
          _updateMovement();
        } else if (spriteColumn != 0) {
          setState(() {
            spriteColumn = 0;
          });
        }
        _checkProximity();
      }
    });
  }

  Future<void> _initAudio() async {
    try {
      await bgPlayer.setAsset('assets/audio/bg2d.ogg');
      await bgPlayer.setLoopMode(LoopMode.one);
      if (isMusicPlaying) {
        await bgPlayer.play();
      }
    } catch (e) {
      if (e is MissingPluginException ||
          e.toString().contains('MissingPluginException')) {
        debugPrint(
            'Audio unavailable in this environment; skipping background music.');
        return;
      }
      debugPrint('BGM Error: $e');
    }
  }

  void _toggleMusic() {
    setState(() {
      isMusicPlaying = !isMusicPlaying;
      if (isMusicPlaying) {
        bgPlayer.play().catchError((error) {
          if (error is MissingPluginException ||
              error.toString().contains('MissingPluginException')) {
            return;
          }
          throw error;
        });
      } else {
        bgPlayer.pause().catchError((error) {
          if (error is MissingPluginException ||
              error.toString().contains('MissingPluginException')) {
            return;
          }
          throw error;
        });
      }
    });
  }

  Future<void> _playSFX(String fileName) async {
    try {
      await sfxPlayer.setAsset('assets/audio/$fileName');
      await sfxPlayer.play();
    } catch (e) {
      if (e is MissingPluginException ||
          e.toString().contains('MissingPluginException')) {
        return;
      }
      debugPrint('SFX Error: $e');
    }
  }

  void _generateMtPalayPalay() {
    final random = math.Random();
    _scoreAwardIds.clear();

    for (int p = 0; p < 15; p++) {
      double pw = 500 + random.nextInt(500).toDouble();
      double ph = 500 + random.nextInt(500).toDouble();
      double px = (random.nextDouble() * (walkableBoundary * 2 - pw)) -
          walkableBoundary;
      double py = (random.nextDouble() * (walkableBoundary * 2 - ph)) -
          walkableBoundary;
      dirtPockets
          .add(FloorPatch(position: math.Point(px, py), width: pw, height: ph));
    }

    for (int i = 0; i < 250; i++) {
      double rx =
          (random.nextDouble() * walkableBoundary * 2) - walkableBoundary;
      double ry =
          (random.nextDouble() * walkableBoundary * 2) - walkableBoundary;
      math.Point<double> pos = math.Point(rx, ry);
      double picker = random.nextDouble();

      if (picker < 0.60) {
        depthSortedObjects.add(WorldObject(
          position: pos,
          asset: 'assets/Tiles/trees.png',
          size: 180 + random.nextInt(60).toDouble(),
          type: ObjType.tree,
          spriteType: random.nextInt(2),
        ));
      } else if (picker < 0.85) {
        depthSortedObjects.add(WorldObject(
          position: pos,
          asset: 'assets/Tiles/bushes.png',
          size: 90 + random.nextInt(30).toDouble(),
          type: ObjType.bush,
        ));
      } else {
        depthSortedObjects.add(WorldObject(
          position: pos,
          asset: 'assets/Tiles/stones.png',
          size: 50 + random.nextInt(20).toDouble(),
          type: ObjType.stone,
        ));
      }
    }

    final totalLitter = getTotalLitterTrivia();
    final numLitterToSpawn = math.min(totalLitter, 10);

    for (int i = 0; i < numLitterToSpawn; i++) {
      double rx = (random.nextDouble() * walkableBoundary * 1.5) -
          walkableBoundary * 0.75;
      double ry = (random.nextDouble() * walkableBoundary * 1.5) -
          walkableBoundary * 0.75;
      depthSortedObjects.add(WorldObject(
        position: math.Point(rx, ry),
        asset: 'litter',
        size: 40,
        type: ObjType.litter,
        dbIndex: i % totalLitter,
      ));
    }

    final totalBirds = getTotalBirds();
    final numBirdsToSpawn = math.min(totalBirds, 5);

    for (int i = 0; i < numBirdsToSpawn; i++) {
      double rx = (random.nextDouble() * walkableBoundary * 1.8) -
          walkableBoundary * 0.9;
      double ry = (random.nextDouble() * walkableBoundary * 1.8) -
          walkableBoundary * 0.9;

      final birdData = getBirdData(i);
      if (birdData != null) {
        depthSortedObjects.add(WorldObject(
          position: math.Point(rx, ry),
          asset: birdData['map_asset'] as String,
          size: 60,
          type: ObjType.bird,
          dbIndex: i,
        ));
      }
    }

    depthSortedObjects.sort((a, b) => a.position.y.compareTo(b.position.y));
  }

  void _updateMovement() {
    setState(() {
      double baseSpeed = 5.0;
      double analogMultiplier = joystickOffset.distance.clamp(0.0, 1.0);

      Offset dir = joystickOffset;
      if (joystickOffset.distance > 0) {
        dir = joystickOffset / joystickOffset.distance;
      }

      playerX -= dir.dx * baseSpeed * analogMultiplier;
      playerY -= dir.dy * baseSpeed * analogMultiplier;

      if (joystickOffset.dy > 0.4) {
        spriteRow = 0;
      } else if (joystickOffset.dy < -0.4) {
        spriteRow = 1;
      } else if (joystickOffset.dx < -0.3) {
        spriteRow = 2;
      } else if (joystickOffset.dx > 0.3) {
        spriteRow = 3;
      }

      playerX = playerX.clamp(-walkableBoundary, walkableBoundary);
      playerY = playerY.clamp(-walkableBoundary, walkableBoundary);

      if (analogMultiplier > 0.1) {
        walkFrameTimer++;
        if (walkFrameTimer > (8 - (analogMultiplier * 4)).toInt()) {
          walkFrameTimer = 0;
          spriteColumn = (spriteColumn + 1) % 4;
        }
      }
    });
  }

  void _checkProximity() {
    WorldObject? closest;
    double minDistanceSq = 15000;

    for (var obj in depthSortedObjects) {
      if (!obj.isActive ||
          (obj.type != ObjType.litter && obj.type != ObjType.bird)) {
        continue;
      }

      double dx = (-playerX) - obj.position.x;
      double dy = (-playerY) - obj.position.y;
      double distSq = (dx * dx) + (dy * dy);

      if (distSq < minDistanceSq) {
        minDistanceSq = distSq;
        closest = obj;
      }
    }
    if (nearbyObject != closest) setState(() => nearbyObject = closest);
  }

  bool _isVisible(math.Point<double> pos, Size screenSize) {
    double screenX = screenSize.width / 2 + playerX + pos.x;
    double screenY = screenSize.height / 2 + playerY + pos.y;
    return screenX > -200 &&
        screenX < screenSize.width + 200 &&
        screenY > -200 &&
        screenY < screenSize.height + 200;
  }

  void _handleWrongAnswer() {
    _playSFX('wrong.ogg');
    setState(() {
      playerHealth--;
      if (playerHealth <= 0) {
        _showGameOver();
      }
    });
  }

  void _showGameOver() async {
    await bgPlayer.stop();
    if (!mounted) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (context, anim1, anim2) => ResultDialog(
        failed: true,
        score: score,
        onRetry: () {
          Navigator.pop(context);
          setState(() {
            playerHealth = 3;
            litterCleaned = 0;
            birdsSpotted = 0;
            score = 0;
            depthSortedObjects.clear();
            dirtPockets.clear();
            _generateMtPalayPalay();
          });
          if (isMusicPlaying) _initAudio();
        },
        onExit: () {
          _closeDialogAndLeave(context);
        },
      ),
    );
  }

  void _checkWin() async {
    final totalLitterRequired = getTotalLitterTrivia();
    final totalBirdsRequired = getTotalBirds();
    if (litterCleaned >= totalLitterRequired &&
        birdsSpotted >= totalBirdsRequired) {
      await bgPlayer.stop();
      if (!mounted) return;
      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        pageBuilder: (context, anim1, anim2) => ResultDialog(
          failed: false,
          score: score,
          onRetry: () {
            Navigator.pop(context);
            widget.onComplete(passed: true, score: score);
          },
          onExit: () {
            Navigator.pop(context);
            widget.onComplete(passed: true, score: score);
          },
        ),
      );
    }
  }

  void _showStartDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF4E342E), width: 4),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tr('ranger_mission_title'),
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF4E342E))),
                  Divider(color: Colors.brown.shade300, thickness: 2),
                  const SizedBox(height: 10),
                  Text(
                    tr('ranger_mission_description'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF388E3C),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(tr('ranger_start_mission'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openBirdIdentification(WorldObject bird) {
    joystickOffset = Offset.zero;

    if (bird.dbIndex == null || bird.dbIndex! < 0) {
      debugPrint('Invalid bird dbIndex');
      return;
    }

    final birdData = getBirdData(bird.dbIndex!);
    if (birdData == null) {
      debugPrint('Bird data not found for index ${bird.dbIndex}');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => BirdDialog(
        imagePath: birdData['asset'] as String,
        acceptedAnswers:
            List<String>.from(birdData['accepted_answers'] as List),
        trivia: birdData['trivia'] as String,
        birdName: birdData['name'] as String,
        onCorrect: () {
          if (!bird.isActive) return;
          _playSFX('right.ogg');
          setState(() {
            bird.isActive = false;
            birdsSpotted++;
            score += 10;
            nearbyObject = null;
          });
          unawaited(
            _saveLeaderboardPoints(10, _scoreAwardIdFor(bird)),
          );
          _checkWin();
        },
        onWrong: () {
          _handleWrongAnswer();
        },
      ),
    );
  }

  void _openLitterTrivia(WorldObject litter) {
    joystickOffset = Offset.zero;

    if (litter.dbIndex == null || litter.dbIndex! < 0) {
      debugPrint('Invalid litter dbIndex');
      return;
    }

    final litterData = getLitterData(litter.dbIndex!);
    if (litterData == null) {
      debugPrint('Litter data not found for index ${litter.dbIndex}');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => LitterDialog(
        question: litterData['question'] as String,
        choices: List<String>.from(litterData['choices'] as List),
        correctAnswerIndex: litterData['correct_answer'] as int,
        onCorrect: () {
          if (!litter.isActive) return;
          Navigator.pop(c);
          _playSFX('right.ogg');
          setState(() {
            litter.isActive = false;
            litterCleaned++;
            score += 5;
            nearbyObject = null;
          });
          unawaited(
            _saveLeaderboardPoints(5, _scoreAwardIdFor(litter)),
          );
          _checkWin();
        },
        onWrong: () {
          Navigator.pop(c);
          _handleWrongAnswer();
        },
      ),
    );
  }

  void _interact() {
    if (nearbyObject != null) {
      if (nearbyObject!.type == ObjType.bird) {
        _openBirdIdentification(nearbyObject!);
      } else if (nearbyObject!.type == ObjType.litter) {
        _openLitterTrivia(nearbyObject!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    List<Widget> behindObjects = [];
    List<Widget> inFrontObjects = [];
    double playerWorldY = -playerY;

    for (var obj in depthSortedObjects) {
      if (!obj.isActive || !_isVisible(obj.position, size)) continue;

      Widget w = Positioned(
        left: obj.position.x - (obj.size / 2),
        top: obj.position.y - obj.size,
        child: _buildWorldObjectWidget(obj),
      );

      if (obj.position.y < playerWorldY) {
        behindObjects.add(w);
      } else {
        inFrontObjects.add(w);
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) => _leaveScreen(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: const Color(0xFFD09F5C),
        body: Stack(
          children: [
            Transform.translate(
              offset:
                  Offset(size.width / 2 + playerX, size.height / 2 + playerY),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildBoundaryShoreline(),
                  Positioned(
                    left: -walkableBoundary,
                    top: -walkableBoundary,
                    child: Image.asset('assets/Tiles/grass.png',
                        width: walkableBoundary * 2,
                        height: walkableBoundary * 2,
                        repeat: ImageRepeat.repeat,
                        filterQuality: FilterQuality.none),
                  ),
                  ...dirtPockets.map((pocket) => Positioned(
                        left: pocket.position.x,
                        top: pocket.position.y,
                        child: Image.asset('assets/Tiles/grass_dirt.png',
                            width: pocket.width,
                            height: pocket.height,
                            repeat: ImageRepeat.repeat,
                            filterQuality: FilterQuality.none),
                      )),
                  ...behindObjects,
                  Positioned(
                      left: -playerX - 22.5,
                      top: -playerY - 45,
                      child: _buildPlayer()),
                  ...inFrontObjects,
                ],
              ),
            ),
            Positioned(
                bottom: 30,
                left: 30,
                child: GameJoystick(
                  onJoystickChanged: (offset) =>
                      setState(() => joystickOffset = offset),
                  onJoystickEnd: () =>
                      setState(() => joystickOffset = Offset.zero),
                )),
            _buildTopBar(),
            _buildBackButton(),
            _buildMissionPaper(),
            if (nearbyObject != null && !isMissionOpen) _buildInteractButton(),
            if (isMissionOpen) _buildLargeMissionBoard(size),
          ],
        ),
      ),
    );
  }

  Future<void> _closeDialogAndLeave(BuildContext dialogContext) async {
    if (_isLeaving) return;
    _isLeaving = true;
    Navigator.pop(dialogContext);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted) Navigator.of(context).maybePop();
  }

  void _leaveScreen() {
    if (_isLeaving || !mounted) return;
    _isLeaving = true;
    bgPlayer.stop();
    Navigator.of(context).maybePop();
  }

  Widget _buildWorldObjectWidget(WorldObject obj) {
    if (obj.type == ObjType.tree) {
      return SizedBox(
        width: obj.size,
        height: obj.size,
        child: ClipRect(
          child: Align(
            alignment: obj.spriteType == 0
                ? Alignment.topCenter
                : Alignment.bottomCenter,
            heightFactor: 0.5,
            child: Image.asset(obj.asset,
                fit: BoxFit.fitHeight, filterQuality: FilterQuality.none),
          ),
        ),
      );
    } else if (obj.type == ObjType.litter) {
      return Container(
        width: obj.size,
        height: obj.size,
        decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)]),
        child: Icon(Icons.delete_outline,
            color: Colors.brown, size: obj.size * 0.6),
      );
    }
    return Image.asset(obj.asset,
        width: obj.size, height: obj.size, filterQuality: FilterQuality.none);
  }

  Widget _buildPlayer() {
    final facingLeft = joystickOffset.dx < -0.3;
    return SizedBox(
      width: 45,
      height: 45,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
          facingLeft ? -1.0 : 1.0,
          1.0,
          1.0,
        ),
        child: HikerSprite(
          column: spriteColumn,
          row: spriteRow,
          width: 45,
          height: 45,
          assetPath: 'assets/images/player/player.png',
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 20,
      left: 20,
      child: Row(
        children: [
          const SizedBox(width: 46),
          const SizedBox(width: 10),
          _buildCircleButton(
              isMusicPlaying
                  ? Icons.music_note_rounded
                  : Icons.music_off_rounded,
              _toggleMusic),
          const SizedBox(width: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white30, width: 2)),
            child: Row(
              children: List.generate(
                  3,
                  (index) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(
                          index < playerHealth
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: const Color(0xFFD32F2F),
                          size: 22,
                        ),
                      )),
            ),
          ),
          const SizedBox(width: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white30, width: 2)),
            child: Text(
                tr('score_label', namedArgs: {'score': score.toString()}),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Positioned(
      bottom: 30,
      left: 20,
      right: 20,
      child: CustomButton(
        text: 'Back',
        width: double.infinity,
        onPressed: _leaveScreen,
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white30, width: 2)),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildMissionPaper() {
    return Positioned(
      top: 20,
      right: 20,
      child: GestureDetector(
        onTap: () {
          _playSFX('mission.ogg');
          setState(() {
            isMissionOpen = true;
            joystickOffset = Offset.zero;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xFFFFB703),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 5)
              ]),
          child:
              const Icon(Icons.assignment, color: Color(0xFF4E342E), size: 30),
        ),
      ),
    );
  }

  Widget _buildLargeMissionBoard(Size size) {
    final totalLitterRequired = getTotalLitterTrivia();
    final totalBirdsRequired = getTotalBirds();
    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 400),
            child: Container(
              margin: const EdgeInsets.all(20),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: const Color(0xFF4E342E), width: 4),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(tr('ranger_missions_title'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 24,
                                  color: Color(0xFF4E342E),
                                  letterSpacing: 1.5)),
                          Divider(color: Colors.brown.shade300, thickness: 2),
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete_sweep,
                                  size: 35,
                                  color: litterCleaned >= totalLitterRequired
                                      ? const Color(0xFF388E3C)
                                      : Colors.brown),
                              const SizedBox(width: 10),
                              Flexible(
                                  child: Text(
                                      tr('mission_clean_up_litter', namedArgs: {
                                        'cleaned': '$litterCleaned',
                                        'total': '$totalLitterRequired'
                                      }),
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: litterCleaned >=
                                                  totalLitterRequired
                                              ? const Color(0xFF388E3C)
                                              : const Color(0xFF4E342E)))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt,
                                  size: 35,
                                  color: birdsSpotted >= totalBirdsRequired
                                      ? const Color(0xFF388E3C)
                                      : Colors.blue.shade700),
                              const SizedBox(width: 10),
                              Flexible(
                                  child: Text(
                                      tr('mission_spot_birds', namedArgs: {
                                        'spotted': '$birdsSpotted',
                                        'total': '$totalBirdsRequired'
                                      }),
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color:
                                              birdsSpotted >= totalBirdsRequired
                                                  ? const Color(0xFF388E3C)
                                                  : const Color(0xFF4E342E)))),
                            ],
                          ),
                          const SizedBox(height: 30),
                          Text(tr('mission_note'),
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.black54),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -10,
                    top: -10,
                    child: GestureDetector(
                      onTap: () => setState(() => isMissionOpen = false),
                      child: Container(
                        decoration: const BoxDecoration(
                            color: Color(0xFFD32F2F),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 4)
                            ]),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInteractButton() {
    bool isBird = nearbyObject!.type == ObjType.bird;
    return Positioned(
      bottom: 50,
      right: 50,
      child: GestureDetector(
        onTap: _interact,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: isBird ? Colors.blue.shade700 : const Color(0xFF388E3C),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black54, blurRadius: 8, offset: Offset(0, 4))
            ],
          ),
          child: Row(
            children: [
              Icon(isBird ? Icons.camera_alt : Icons.pan_tool,
                  color: Colors.white),
              const SizedBox(width: 10),
              Text(isBird ? tr('identify_button') : tr('clean_up_button'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoundaryShoreline() {
    return Positioned(
      left: -walkableBoundary - 100,
      top: -walkableBoundary - 100,
      child: Container(
        width: (walkableBoundary + 100) * 2,
        height: (walkableBoundary + 100) * 2,
        decoration: BoxDecoration(
            color: const Color(0xFFFFE4B5),
            border: Border.all(color: const Color(0xFFFFDAB9), width: 20)),
      ),
    );
  }

  @override
  void dispose() {
    movementTimer?.cancel();
    try {
      bgPlayer.stop();
    } catch (error) {
      if (error is! MissingPluginException &&
          !error.toString().contains('MissingPluginException')) {
        rethrow;
      }
    }
    try {
      bgPlayer.dispose();
    } catch (error) {
      if (error is! MissingPluginException &&
          !error.toString().contains('MissingPluginException')) {
        rethrow;
      }
    }
    try {
      sfxPlayer.dispose();
    } catch (error) {
      if (error is! MissingPluginException &&
          !error.toString().contains('MissingPluginException')) {
        rethrow;
      }
    }
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }
}
