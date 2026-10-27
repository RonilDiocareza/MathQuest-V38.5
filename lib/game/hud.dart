import 'dart:math';

import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';

class GameHUD extends StatelessWidget {
  final int score;
  final int health;
  final VoidCallback? onBackPressed;
  final VoidCallback onMusicPressed;
  final VoidCallback onMenuPressed;
  final VoidCallback? onHelpPressed;
  final bool isMusicEnabled;

  const GameHUD({
    super.key,
    required this.score,
    required this.health,
    this.onBackPressed,
    required this.onMusicPressed,
    required this.onMenuPressed,
    this.onHelpPressed,
    this.isMusicEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double minSide = min(screenSize.width, screenSize.height);
    final double buttonSize = (minSide * 0.13).clamp(48.0, 72.0);
    final double iconSize = (minSide * 0.075).clamp(24.0, 32.0);
    final double cornerPadding = (minSide * 0.04).clamp(12.0, 20.0);
    final double spacing = (minSide * 0.03).clamp(10.0, 16.0);
    final double scoreHorizontal = (minSide * 0.035).clamp(12.0, 18.0);
    final double scoreVertical = (minSide * 0.02).clamp(8.0, 12.0);
    final double scoreFontSize = (minSide * 0.045).clamp(16.0, 22.0);
    final double heartSize = (minSide * 0.05).clamp(18.0, 24.0);

    return Stack(
      children: [
        Positioned(
          top: cornerPadding,
          left: cornerPadding,
          child: Row(
            children: [
              if (onBackPressed != null) ...[
                SizedBox(width: buttonSize + spacing),
              ],
              GestureDetector(
                onTap: onMusicPressed,
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8D5B2B),
                    shape: BoxShape.circle,
                    boxShadow: [
                      const BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    isMusicEnabled ? Icons.music_note : Icons.music_off,
                    color: Colors.white,
                    size: iconSize,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (onBackPressed != null)
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: CustomButton(
                text: 'Back',
                width: double.infinity,
                onPressed: onBackPressed,
              ),
          ),
        Positioned(
          top: cornerPadding,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: scoreHorizontal, vertical: scoreVertical),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(110, 75, 42, 0.82),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  const BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  health,
                  (index) => Padding(
                    padding: EdgeInsets.symmetric(horizontal: spacing / 2),
                    child: Icon(
                      Icons.favorite,
                      color: const Color(0xFFE53935),
                      size: heartSize,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: cornerPadding,
          right: cornerPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: scoreHorizontal, vertical: scoreVertical),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(110, 75, 42, 0.82),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    const BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  'SCORE: $score',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: scoreFontSize,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Arial',
                  ),
                ),
              ),
              SizedBox(height: spacing),
              GestureDetector(
                onTap: onMenuPressed,
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD89B4A),
                    shape: BoxShape.circle,
                    boxShadow: [
                      const BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.menu,
                    color: Colors.white,
                    size: iconSize,
                  ),
                ),
              ),
              if (onHelpPressed != null) ...[
                SizedBox(height: spacing),
                GestureDetector(
                  onTap: onHelpPressed,
                  child: Container(
                    width: buttonSize,
                    height: buttonSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5E7CFF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        const BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.3),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/Icon/help.png',
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
