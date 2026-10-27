import 'package:flutter/material.dart';
import 'dart:math' as math;

class MathBackground extends StatelessWidget {
  final Widget child;

  const MathBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (MathBackgroundScope.isActive(context)) {
      return child;
    }

    return MathBackgroundScope(
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFB6793D),
                              Color(0xFF9A6332),
                              Color(0xFF754725),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: WoodGrainPainter(),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: ScrapbookBoardPainter(),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: ScrapbookDetailsPainter(),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: MathMarginSymbolsPainter(),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class MathBackgroundScope extends InheritedWidget {
  const MathBackgroundScope({required super.child, super.key});

  static bool isActive(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MathBackgroundScope>() != null;

  @override
  bool updateShouldNotify(MathBackgroundScope oldWidget) => false;
}

class WoodGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final boardWidth = math.min(size.width * 0.9, 940.0);
    final boardLeft = (size.width - boardWidth) / 2;
    final boardRight = boardLeft + boardWidth;
    for (final woodArea in [
      Rect.fromLTRB(0, 0, boardLeft, size.height),
      Rect.fromLTRB(boardRight, 0, size.width, size.height),
    ]) {
      if (woodArea.width <= 0) continue;
      canvas.save();
      canvas.clipRect(woodArea);
      _paintWood(canvas, size);
      canvas.restore();
    }
  }

  void _paintWood(Canvas canvas, Size size) {
    final beige = Paint()
      ..color = const Color(0xFFF2D7A5).withValues(alpha: 0.08);
    for (var i = 0; i < 18; i++) {
      final offset = i * 24.0;
      final path = Path()
        ..moveTo(offset, 0)
        ..quadraticBezierTo(
          offset + 16,
          size.height * 0.25,
          offset + 10,
          size.height,
        );
      canvas.drawPath(path, beige);
    }

    final accent = Paint()
      ..color = const Color(0xFF713F1B).withValues(alpha: 0.18);
    for (var i = 0; i < 32; i++) {
      final x = i * 18.0 + (i % 2 == 0 ? 8 : 0);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + 80, size.height),
        accent..strokeWidth = 1.2,
      );
    }

    final plankSeam = Paint()
      ..color = const Color(0xFF482B19).withValues(alpha: 0.12)
      ..strokeWidth = 2;
    for (var i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), plankSeam);
    }
  }

  @override
  bool shouldRepaint(WoodGrainPainter oldDelegate) => false;
}

class MathElementsPainter extends CustomPainter {
  final math.Random _random = math.Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE7D0A4).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    const mathSymbols = [
      '×',
      '÷',
      '√',
      '∑',
      '∫',
      '≈',
      '≠',
      '∞',
      'π',
      'α',
      'β',
      'θ',
      '∂',
      '∇',
      '±',
      '≤',
      '≥',
    ];

    for (int i = 0; i < 26; i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height * 0.82;
      if (x > size.width * 0.3 &&
          x < size.width * 0.7 &&
          y > size.height * 0.2 &&
          y < size.height * 0.8) {
        continue;
      }

      final symbol = mathSymbols[i % mathSymbols.length];
      final fontSize = 12.0 + _random.nextDouble() * 20;

      textPainter.text = TextSpan(
        text: symbol,
        style: TextStyle(
          color: const Color(0xFFFFF1D5)
              .withValues(alpha: 0.26 + _random.nextDouble() * 0.2),
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      );

      textPainter.layout();
      textPainter.paint(canvas,
          Offset(x - textPainter.width / 2, y - textPainter.height / 2));
    }

    for (int i = 0; i < 16; i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;
      final dotPaint = Paint()
        ..color = const Color(0xFFFFF4E4)
            .withValues(alpha: 0.25 + _random.nextDouble() * 0.2)
        ..style = PaintingStyle.fill;
      final radius = 2.0 + _random.nextDouble() * 3;
      canvas.drawCircle(Offset(x, y), radius, dotPaint);

      if (i % 3 == 0 && i < 15) {
        final nextX = _random.nextDouble() * size.width;
        final nextY = _random.nextDouble() * size.height;
        canvas.drawLine(
          Offset(x, y),
          Offset(nextX, nextY),
          paint..strokeWidth = 0.8,
        );
      }
    }
  }

  @override
  bool shouldRepaint(MathElementsPainter oldDelegate) => false;
}

class PaperTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paperPaint = Paint()
      ..color = const Color(0xFFEEE0C3).withValues(alpha: 0.08);
    for (int i = 0; i < 26; i++) {
      final x = i * 26.0 + (i % 3 == 0 ? 12 : 0);
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + 8, size.height)
        ..moveTo(x + 3, 0)
        ..lineTo(x + 11, size.height);
      canvas.drawPath(path, paperPaint..strokeWidth = 0.8);
    }

    final accent = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.04);
    for (int i = 0; i < 22; i++) {
      final x = (i * 31.0) % size.width;
      final y = (i * 47.0) % size.height;
      canvas.drawCircle(Offset(x, y), 1.2 + (i % 3), accent);
    }
  }

  @override
  bool shouldRepaint(PaperTexturePainter oldDelegate) => false;
}

class ScrapbookBoardPainter extends CustomPainter {
  static const _maxBoardWidth = 940.0;

  @override
  void paint(Canvas canvas, Size size) {
    final boardWidth = math.min(size.width * 0.9, _maxBoardWidth);
    final boardHeight = size.height * 0.935;
    final left = (size.width - boardWidth) / 2;
    final top = size.height * 0.035;
    final rect = Rect.fromLTWH(left, top, boardWidth, boardHeight);

    canvas.save();
    final rearSheet = RRect.fromRectAndRadius(
      rect.shift(const Offset(-10, 9)),
      const Radius.circular(3),
    );
    canvas.drawShadow(
      Path()..addRRect(rearSheet),
      const Color(0xFF29170C),
      12,
      true,
    );
    canvas.drawRRect(
      rearSheet,
      Paint()..color = const Color(0xFFD9BE91),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.shift(const Offset(5, 5)),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFE5D1AC),
    );

    final boardPath = Path()
      ..moveTo(rect.left + 10, rect.top)
      ..lineTo(rect.right - 10, rect.top)
      ..lineTo(rect.right, rect.top + 10)
      ..lineTo(rect.right, rect.bottom - 10)
      ..lineTo(rect.right - 10, rect.bottom)
      ..lineTo(rect.left + 10, rect.bottom)
      ..lineTo(rect.left, rect.bottom - 10)
      ..lineTo(rect.left, rect.top + 10)
      ..close();
    canvas.drawShadow(boardPath, const Color(0xFF321D0E), 8, true);
    canvas.drawPath(
      boardPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF4E4C5),
            Color(0xFFEEDDBB),
            Color(0xFFE9D5AE),
          ],
        ).createShader(rect),
    );
    canvas.drawPath(
      boardPath,
      Paint()
        ..color = const Color(0xFF8E6339).withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final rulePaint = Paint()
      ..color = const Color(0xFF9E8868).withValues(alpha: 0.09)
      ..strokeWidth = 1;
    for (var i = 1; i < 23; i++) {
      final y = rect.top + 16 + i * (rect.height - 32) / 23;
      canvas.drawLine(
        Offset(rect.left + 16, y),
        Offset(rect.right - 15, y + 0.6),
        rulePaint,
      );
    }

    final paperFiber = Paint()
      ..color = const Color(0xFF8C6842).withValues(alpha: 0.08)
      ..strokeWidth = 0.7;
    for (var i = 0; i < 34; i++) {
      final x = rect.left + 14 + i * (rect.width - 28) / 34;
      final y = rect.top + (i * 37.0) % rect.height;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + 3 + (i % 5), y + 1),
        paperFiber,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(ScrapbookBoardPainter oldDelegate) => false;
}

class ScrapbookDetailsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final tabs = <Color>[
      const Color(0xFFD9574D),
      const Color(0xFFE8A33C),
      const Color(0xFF36A0A2),
      const Color(0xFFD8B991),
      const Color(0xFF5F9A75),
    ];
    final boardWidth =
        math.min(size.width * 0.9, ScrapbookBoardPainter._maxBoardWidth);
    final boardLeft = (size.width - boardWidth) / 2;
    final boardTop = size.height * 0.035;
    for (var i = 0; i < tabs.length; i++) {
      final top = boardTop + 106 + i * 88;
      final tab = RRect.fromRectAndRadius(
        Rect.fromLTWH(boardLeft + boardWidth - 3, top, 16, 69),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        tab,
        Paint()..color = tabs[i].withValues(alpha: 0.86),
      );
      canvas.drawRRect(
        tab,
        Paint()
          ..color = const Color(0xFF4A2C19).withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    final clipPaint = Paint()
      ..color = const Color(0xFF41372D).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final clip = Path()
      ..moveTo(boardLeft + 28, boardTop - 6)
      ..cubicTo(
        boardLeft + 14,
        boardTop + 4,
        boardLeft + 17,
        boardTop + 29,
        boardLeft + 29,
        boardTop + 31,
      )
      ..cubicTo(
        boardLeft + 39,
        boardTop + 33,
        boardLeft + 39,
        boardTop + 17,
        boardLeft + 29,
        boardTop + 14,
      )
      ..cubicTo(
        boardLeft + 20,
        boardTop + 12,
        boardLeft + 22,
        boardTop + 25,
        boardLeft + 29,
        boardTop + 25,
      );
    canvas.drawPath(clip, clipPaint);

    final pencilPaint = Paint()
      ..color = const Color(0xFFC87532).withValues(alpha: 0.82)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(boardLeft + boardWidth + 5, size.height * 0.84),
      Offset(boardLeft + boardWidth - 12, size.height * 0.99),
      pencilPaint,
    );
    canvas.drawLine(
      Offset(boardLeft + boardWidth + 5, size.height * 0.84),
      Offset(boardLeft + boardWidth - 12, size.height * 0.99),
      Paint()
        ..color = const Color(0xFFF0D59C).withValues(alpha: 0.8)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(ScrapbookDetailsPainter oldDelegate) => false;
}

class MathMarginSymbolsPainter extends CustomPainter {
  static const _symbols = ['π', '√', '÷', '×', 'Σ', '∞', '≠', '±'];
  static const _algebraExpressions = [
    '',
'(7/8) − (2/3) = 5/24',
'(4/5) × (15/16) = 3/4',
'(7/9) ÷ (14/27) = 3/2',
'(2/3) + (5/8) − (1/4) = 25/24',
'(18/24) = 3/4',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final boardWidth = math.min(size.width * 0.9, 940.0);
    final boardHeight = size.height * 0.935;
    final boardLeft = (size.width - boardWidth) / 2;
    final boardTop = size.height * 0.035;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (var index = 0; index < 6; index++) {
      final y = boardTop + boardHeight * (0.1 + index * 0.16);
      final symbol = _symbols[index];
      _paintSymbol(
        canvas,
        textPainter,
        symbol,
        Offset(boardLeft + 22, y),
        23 + (index % 2) * 4,
      );
      _paintSymbol(
        canvas,
        textPainter,
        symbol,
        Offset(boardLeft + boardWidth - 22, y),
        23 + (index % 2) * 4,
      );
      final expression = _algebraExpressions[index];
      final isNarrowScreen = size.width < 600;
      _paintSymbol(
        canvas,
        textPainter,
        expression,
        Offset(size.width / 2, y),
        isNarrowScreen ? 12 : 16,
      );
    }

    _paintSymbol(
      canvas,
      textPainter,
      '',
      Offset(size.width / 2, boardTop + 42),
      size.width < 600 ? 14 : 18,
    );
    _paintSymbol(
      canvas,
      textPainter,
      'x² − 5x + 6 = (x − 2)(x − 3)',
      Offset(size.width / 2, boardTop + boardHeight - 22),
      size.width < 600 ? 12 : 17,
    );
  }

  void _paintSymbol(
    Canvas canvas,
    TextPainter painter,
    String text,
    Offset center,
    double fontSize,
  ) {
    painter.text = TextSpan(
      text: text,
      style: TextStyle(
        color: const Color(0xFF71451F).withValues(alpha: 0.58),
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
      ),
    );
    painter.layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(MathMarginSymbolsPainter oldDelegate) => false;
}

class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E3A5F).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const double waveHeight = 30;
    const double waveLength = 100;

    final path1 = Path()..moveTo(0, size.height * 0.4);
    for (double i = 0; i <= size.width; i += 10) {
      final double y = size.height * 0.4 +
          waveHeight * math.sin((i / waveLength) * 2 * math.pi);
      path1.lineTo(i, y);
    }
    path1
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
        path1, paint..color = const Color(0xFF0D47A1).withValues(alpha: 0.3));

    final path2 = Path()..moveTo(0, size.height * 0.55);
    for (double i = 0; i <= size.width; i += 10) {
      final double y = size.height * 0.55 +
          waveHeight *
              0.7 *
              math.sin((i / waveLength) * 2 * math.pi + math.pi / 4);
      path2.lineTo(i, y);
    }
    path2
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
        path2, paint..color = const Color(0xFF1565C0).withValues(alpha: 0.4));

    final waveLine1 = Path()..moveTo(0, size.height * 0.5);
    for (double i = 0; i <= size.width; i += 10) {
      final double y = size.height * 0.5 +
          waveHeight * 0.5 * math.sin((i / waveLength) * 2 * math.pi);
      waveLine1.lineTo(i, y);
    }

    canvas.drawPath(waveLine1,
        paint..color = const Color(0xFF42A5F5).withValues(alpha: 0.5));
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) => false;
}
