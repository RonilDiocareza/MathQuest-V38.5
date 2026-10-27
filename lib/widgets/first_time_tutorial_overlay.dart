import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class FirstTimeTutorialStep {
  const FirstTimeTutorialStep({
    required this.title,
    required this.message,
    this.targetKey,
    this.guideAtTop = false,
    this.guideAssetPath = 'assets/images/npcs/guide1.png',
  });

  final String title;
  final String message;
  final GlobalKey? targetKey;
  final bool guideAtTop;
  final String guideAssetPath;
}

class FirstTimeTutorialOverlay extends StatefulWidget {
  const FirstTimeTutorialOverlay({
    required this.steps,
    required this.onComplete,
    this.title,
    this.onStepChanged,
    this.gameModeLayout = false,
    this.typewriterText = false,
    super.key,
  }) : assert(steps.length > 0);

  final List<FirstTimeTutorialStep> steps;
  final Future<void> Function() onComplete;
  final String? title;
  final Future<void> Function(int index)? onStepChanged;
  final bool gameModeLayout;
  final bool typewriterText;

  @override
  State<FirstTimeTutorialOverlay> createState() =>
      _FirstTimeTutorialOverlayState();
}

class _FirstTimeTutorialOverlayState extends State<FirstTimeTutorialOverlay> {
  final GlobalKey _overlayBoundsKey = GlobalKey();
  int _stepIndex = 0;
  bool _isSaving = false;
  bool _isAdvancing = false;
  bool _isCompleted = false;
  String? _saveError;
  Timer? _typingTimer;
  int _visibleCharacters = 0;

  String get _currentMessage => widget.steps[_stepIndex].message;
  bool get _isTyping =>
      widget.typewriterText &&
      _visibleCharacters < _currentMessage.runes.length;

  @override
  void initState() {
    super.initState();
    _startTyping();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    super.dispose();
  }

  void _startTyping() {
    _typingTimer?.cancel();
    if (!widget.typewriterText) {
      _visibleCharacters = _currentMessage.runes.length;
      return;
    }

    _visibleCharacters = 0;
    _typingTimer = Timer.periodic(const Duration(milliseconds: 24), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_visibleCharacters >= _currentMessage.runes.length) {
        timer.cancel();
        _typingTimer = null;
        return;
      }
      setState(() => _visibleCharacters++);
      if (_visibleCharacters >= _currentMessage.runes.length) {
        timer.cancel();
        _typingTimer = null;
      }
    });
  }

  void _revealCurrentLine() {
    if (!_isTyping) return;
    _typingTimer?.cancel();
    _typingTimer = null;
    setState(() => _visibleCharacters = _currentMessage.runes.length);
  }

  Future<void> _advance() async {
    if (_isSaving || _isAdvancing) return;
    if (_isTyping) {
      _revealCurrentLine();
      return;
    }
    _isAdvancing = true;

    if (_stepIndex == widget.steps.length - 1) {
      _typingTimer?.cancel();
      _typingTimer = null;
      setState(() {
        _isSaving = true;
        _saveError = null;
      });
      try {
        await widget.onComplete();
        if (!mounted) return;
        setState(() => _isCompleted = true);
      } catch (error, stackTrace) {
        debugPrint(
          '[FirstTimeTutorialOverlay] Finish save callback failed: '
          'type=${error.runtimeType}, message=$error.',
        );
        if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
        if (mounted) {
          setState(() {
            _isSaving = false;
            _isAdvancing = false;
            _saveError = 'Could not save your progress. Please try again.';
          });
        }
      }
      return;
    }

    final nextIndex = _stepIndex + 1;
    try {
      await widget.onStepChanged?.call(nextIndex);
      if (!mounted) return;
      setState(() {
        _stepIndex = nextIndex;
        _isAdvancing = false;
        _saveError = null;
        _startTyping();
      });
    } catch (error, stackTrace) {
      debugPrint('Unable to focus tutorial feature: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) setState(() => _isAdvancing = false);
    }
  }

  Rect? _targetRect() {
    final targetContext = widget.steps[_stepIndex].targetKey?.currentContext;
    final overlayContext = _overlayBoundsKey.currentContext;
    final targetObject = targetContext?.findRenderObject();
    final overlayObject = overlayContext?.findRenderObject();
    if (targetObject is! RenderBox ||
        overlayObject is! RenderBox ||
        !targetObject.hasSize ||
        !overlayObject.hasSize) {
      return null;
    }

    final topLeft = targetObject.localToGlobal(Offset.zero);
    final overlayTopLeft = overlayObject.localToGlobal(Offset.zero);
    return (topLeft - overlayTopLeft & targetObject.size).inflate(5);
  }

  double _overlapArea(Rect first, Rect second) {
    final intersection = first.intersect(second);
    return intersection.isEmpty ? 0 : intersection.width * intersection.height;
  }

  @override
  Widget build(BuildContext context) {
    if (_isCompleted) return const SizedBox.shrink();

    final step = widget.steps[_stepIndex];
    final targetRect = _targetRect();

    return LayoutBuilder(
      key: _overlayBoundsKey,
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        if (widget.gameModeLayout) {
          return _buildGameModeLayout(
            context: context,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            safeInsets: MediaQuery.paddingOf(context),
            step: step,
          );
        }

        final isWide = maxWidth > maxHeight;
        final characterWidth = math.min(
          math.max(maxWidth * (isWide ? 0.30 : 0.42), 90.0),
          isWide ? 230.0 : 180.0,
        );
        final guideSize = math.min(
          characterWidth,
          maxHeight * (isWide ? 0.30 : 0.24),
        );
        final safeInsets = MediaQuery.paddingOf(context);
        final groupWidth = math.min(maxWidth - 24, 820.0);
        final dialogueHeight = widget.title == null
            ? math.min(maxHeight * 0.32, 190.0)
            : math.min(maxHeight * 0.32 + 30, 220.0);
        final groupHeight = guideSize + 8 + dialogueHeight;
        final groupLeft = (maxWidth - groupWidth) / 2;
        final top = safeInsets.top + 12;
        final bottom = math.max(
          top,
          maxHeight - safeInsets.bottom - groupHeight - 12,
        );
        final topGroupRect = Rect.fromLTWH(
          groupLeft,
          top,
          groupWidth,
          groupHeight,
        );
        final bottomGroupRect = Rect.fromLTWH(
          groupLeft,
          bottom,
          groupWidth,
          groupHeight,
        );
        final topOverlap =
            targetRect == null ? 0.0 : _overlapArea(topGroupRect, targetRect);
        final bottomOverlap = targetRect == null
            ? 0.0
            : _overlapArea(bottomGroupRect, targetRect);
        final placeAtTop = topOverlap < bottomOverlap ||
            (topOverlap == bottomOverlap && step.guideAtTop);
        final groupTop = placeAtTop ? top : bottom;
        final guideComesFirst = placeAtTop;

        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: CustomPaint(
                painter: _TutorialScrimPainter(targetRect: targetRect),
                size: Size.infinite,
              ),
            ),
            if (targetRect != null)
              Positioned.fromRect(
                rect: targetRect,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: const Color(0xFFFFD65A), width: 4),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xCCFFD65A),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              top: groupTop,
              left: groupLeft,
              width: groupWidth,
              height: groupHeight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (guideComesFirst) ...[
                    _buildGuide(guideSize),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: dialogueHeight,
                      width: groupWidth,
                      child: _buildDialogue(step, maxHeight),
                    ),
                  ] else ...[
                    SizedBox(
                      height: dialogueHeight,
                      width: groupWidth,
                      child: _buildDialogue(step, maxHeight),
                    ),
                    const SizedBox(height: 8),
                    _buildGuide(guideSize),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGameModeLayout({
    required double maxWidth,
    required double maxHeight,
    required BuildContext context,
    required EdgeInsets safeInsets,
    required FirstTimeTutorialStep step,
  }) {
    final isLandscape = maxWidth > maxHeight;
    final availableWidth = math.max(0.0, maxWidth - safeInsets.horizontal - 24);
    final groupWidth = math.min(
      isLandscape ? math.min(availableWidth, maxWidth * 0.5) : availableWidth,
      600.0,
    );
    final availableHeight = math.max(0.0, maxHeight - safeInsets.vertical - 24);
    final maxDialogueHeight = math.min(availableHeight * 0.65, 280.0);
    final dialogueMetrics = _gameModeDialogueMetrics(
      context: context,
      step: step,
      dialogueWidth: groupWidth,
      maxHeight: maxDialogueHeight,
    );
    final dialogueHeight = math.min(dialogueMetrics.height, maxDialogueHeight);
    final groupLeft = safeInsets.left + 12 + (availableWidth - groupWidth) / 2;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: groupLeft,
          width: groupWidth,
          bottom: safeInsets.bottom + 12,
          height: dialogueHeight,
          child: _buildDialogue(
            step,
            dialogueHeight,
            useAvailableHeight: true,
            messageFontSize: dialogueMetrics.messageFontSize,
            scrollMessage: dialogueMetrics.scrollMessage,
          ),
        ),
      ],
    );
  }

  ({
    double height,
    double messageFontSize,
    bool scrollMessage,
  }) _gameModeDialogueMetrics({
    required BuildContext context,
    required FirstTimeTutorialStep step,
    required double dialogueWidth,
    required double maxHeight,
  }) {
    const horizontalPadding = 28.0;
    const verticalChrome = 100.0;
    final textWidth = math.max(0.0, dialogueWidth - horizontalPadding);
    final titleWidth = math.max(0.0, textWidth - 42);
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);

    double measure(String text, TextStyle style, double width) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout(maxWidth: width);
      return painter.height;
    }

    const titleStyle = TextStyle(
      color: Colors.white,
      fontSize: 15,
      height: 1.15,
      fontWeight: FontWeight.w800,
    );
    const messageStyle = TextStyle(
      color: Colors.white,
      fontSize: 13,
      height: 1.3,
    );
    final saveErrorHeight = _saveError == null
        ? 0.0
        : measure(
              _saveError!,
              const TextStyle(fontSize: 12),
              textWidth,
            ) +
            4;
    final titleHeight = measure(step.title, titleStyle, titleWidth);
    for (var fontSize = 13.0; fontSize >= 10.5; fontSize -= 0.5) {
      final messageHeight = measure(
        step.message,
        messageStyle.copyWith(fontSize: fontSize),
        textWidth,
      );
      final desiredHeight =
          titleHeight + messageHeight + verticalChrome + saveErrorHeight;
      if (desiredHeight <= maxHeight) {
        return (
          height: math.max(100, desiredHeight).toDouble(),
          messageFontSize: fontSize,
          scrollMessage: false,
        );
      }
    }

    return (
      height: maxHeight,
      messageFontSize: 10.5,
      scrollMessage: true,
    );
  }

  Widget _buildGuide(double size) => ClipRect(
        child: SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            widget.steps[_stepIndex].guideAssetPath,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
      );

  Widget _buildDialogue(
    FirstTimeTutorialStep step,
    double availableHeight, {
    bool useAvailableHeight = false,
    double? messageFontSize,
    bool scrollMessage = false,
  }) {
    final isFinalStep = _stepIndex == widget.steps.length - 1;

    return GestureDetector(
      onTap: widget.typewriterText && !widget.gameModeLayout
          ? _revealCurrentLine
          : null,
      child: Container(
        key: const ValueKey('tutorial-dialogue'),
        constraints: BoxConstraints(
          maxHeight: useAvailableHeight
              ? availableHeight
              : math.min(availableHeight * 0.32, 190),
        ),
        padding: widget.gameModeLayout
            ? const EdgeInsets.fromLTRB(12, 10, 10, 8)
            : const EdgeInsets.fromLTRB(16, 12, 12, 10),
        decoration: BoxDecoration(
          color: widget.gameModeLayout ? const Color(0xCC000000) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: widget.gameModeLayout
                ? Colors.white54
                : const Color(0xFF5A3620),
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.title != null) ...[
              Text(
                widget.title!,
                style: const TextStyle(
                  color: Color(0xFF3C2A1C),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    step.title,
                    maxLines: widget.gameModeLayout ? null : 1,
                    overflow: widget.gameModeLayout
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.gameModeLayout
                          ? Colors.white
                          : const Color(0xFF3C2A1C),
                      fontSize: widget.gameModeLayout ? 15 : 17,
                      height: widget.gameModeLayout ? 1.15 : null,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${_stepIndex + 1}/${widget.steps.length}',
                  style: TextStyle(
                    color: widget.gameModeLayout
                        ? Colors.white70
                        : const Color(0xFF76563D),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (widget.gameModeLayout) ...[
              if (scrollMessage)
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('tutorial-message-scroll'),
                    child: Text(
                      widget.typewriterText
                          ? String.fromCharCodes(
                              _currentMessage.runes.take(_visibleCharacters),
                            )
                          : step.message,
                      key: const ValueKey('tutorial-message'),
                      style: TextStyle(
                        color: Colors.white,
                        height: 1.3,
                        fontSize: messageFontSize ?? 13,
                      ),
                    ),
                  ),
                )
              else
                Text(
                  widget.typewriterText
                      ? String.fromCharCodes(
                          _currentMessage.runes.take(_visibleCharacters),
                        )
                      : step.message,
                  key: const ValueKey('tutorial-message'),
                  style: TextStyle(
                    color: Colors.white,
                    height: 1.3,
                    fontSize: messageFontSize ?? 13,
                  ),
                ),
            ] else ...[
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    widget.typewriterText
                        ? String.fromCharCodes(
                            _currentMessage.runes.take(_visibleCharacters),
                          )
                        : step.message,
                    key: const ValueKey('tutorial-message'),
                    style: const TextStyle(
                      color: Color(0xFF3C2A1C),
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ],
            if (_saveError != null) ...[
              const SizedBox(height: 4),
              Text(
                _saveError!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isSaving ? null : _advance,
                style: TextButton.styleFrom(
                  minimumSize: const Size(64, 34),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  backgroundColor: const Color(0xFF8F5C2D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isFinalStep
                            ? (_saveError == null ? 'Finish' : 'Retry Save')
                            : 'Next',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialScrimPainter extends CustomPainter {
  const _TutorialScrimPainter({required this.targetRect});

  final Rect? targetRect;

  @override
  void paint(Canvas canvas, Size size) {
    final screenPath = Path()..addRect(Offset.zero & size);
    final scrimPath = targetRect == null
        ? screenPath
        : Path.combine(
            PathOperation.difference,
            screenPath,
            Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  targetRect!,
                  const Radius.circular(15),
                ),
              ),
          );
    canvas.drawPath(
      scrimPath,
      Paint()..color = const Color(0xB8000000),
    );
  }

  @override
  bool shouldRepaint(_TutorialScrimPainter oldDelegate) =>
      targetRect != oldDelegate.targetRect;
}
