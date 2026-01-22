import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../services/settings_service.dart';

/// A vintage telegraph key (straight key) widget - TOP DOWN VIEW
/// Designed to replicate the look of a classic morse code key from above
class TelegraphKey extends StatefulWidget {
  /// Called when the key is pressed down
  final VoidCallback? onKeyDown;

  /// Called when the key is released
  final VoidCallback? onKeyUp;

  /// Called with the duration of the press in milliseconds
  final Function(int duration)? onPress;

  /// Whether the key is currently active/enabled
  final bool enabled;

  /// Size multiplier (1.0 = default size)
  final double scale;

  const TelegraphKey({
    super.key,
    this.onKeyDown,
    this.onKeyUp,
    this.onPress,
    this.enabled = true,
    this.scale = 1.0,
  });

  @override
  State<TelegraphKey> createState() => _TelegraphKeyState();
}

class _TelegraphKeyState extends State<TelegraphKey>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  DateTime? _pressStartTime;
  late AnimationController _animationController;
  late Animation<double> _pressAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 60),
    );
    _pressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onPressStart() {
    if (!widget.enabled) return;

    setState(() => _isPressed = true);
    _pressStartTime = DateTime.now();
    _animationController.forward();

    // Haptic feedback
    final settings = context.read<SettingsService>();
    if (settings.hapticFeedback) {
      HapticFeedback.mediumImpact();
    }

    widget.onKeyDown?.call();
  }

  void _onPressEnd() {
    if (!widget.enabled || !_isPressed) return;

    setState(() => _isPressed = false);
    _animationController.reverse();

    // Calculate press duration
    if (_pressStartTime != null) {
      final duration = DateTime.now().difference(_pressStartTime!).inMilliseconds;
      widget.onPress?.call(duration);
    }

    widget.onKeyUp?.call();
    _pressStartTime = null;
  }

  @override
  Widget build(BuildContext context) {
    final baseWidth = 180.0 * widget.scale;
    final baseHeight = 340.0 * widget.scale;

    return GestureDetector(
      onTapDown: (_) => _onPressStart(),
      onTapUp: (_) => _onPressEnd(),
      onTapCancel: _onPressEnd,
      child: AnimatedBuilder(
        animation: _pressAnimation,
        builder: (context, child) {
          return SizedBox(
            width: baseWidth,
            height: baseHeight,
            child: CustomPaint(
              painter: _TopDownKeyPainter(
                pressAmount: _pressAnimation.value,
                enabled: widget.enabled,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TopDownKeyPainter extends CustomPainter {
  final double pressAmount;
  final bool enabled;

  _TopDownKeyPainter({
    required this.pressAmount,
    required this.enabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    
    // === BASE PLATE (stadium/pill shape) ===
    final basePaint = Paint()
      ..color = enabled ? const Color(0xFF1A1A1A) : const Color(0xFF2A2A2A);
    
    final baseRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.08,
        size.height * 0.08,
        size.width * 0.84,
        size.height * 0.52,
      ),
      Radius.circular(size.width * 0.42),
    );
    
    // Base shadow
    canvas.drawRRect(
      baseRect.shift(const Offset(3, 4)),
      Paint()
        ..color = Colors.black.withAlpha(80)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    
    canvas.drawRRect(baseRect, basePaint);
    
    // Base inner bevel/highlight
    final baseHighlight = Paint()
      ..color = Colors.white.withAlpha(15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.10,
          size.height * 0.09,
          size.width * 0.80,
          size.height * 0.50,
        ),
        Radius.circular(size.width * 0.40),
      ),
      baseHighlight,
    );

    // === PIVOT MECHANISM (top) ===
    _drawPivotMechanism(canvas, size, centerX);

    // === LEVER ARM ===
    _drawLeverArm(canvas, size, centerX);

    // === CONTACT POINTS ===
    _drawContactPoints(canvas, size, centerX);

    // === TAPPER KNOB (bottom) ===
    _drawTapperKnob(canvas, size, centerX);

    // === DECORATIVE SCREWS ===
    _drawScrews(canvas, size);
  }

  void _drawPivotMechanism(Canvas canvas, Size size, double centerX) {
    final pivotY = size.height * 0.12;
    
    // Pivot housing
    final pivotPaint = Paint()
      ..color = enabled ? const Color(0xFF606060) : const Color(0xFF505050);
    
    canvas.drawCircle(
      Offset(centerX, pivotY),
      size.width * 0.08,
      pivotPaint,
    );
    
    // Pivot center screw
    final screwPaint = Paint()
      ..color = enabled ? const Color(0xFFD0D0D0) : const Color(0xFF909090);
    canvas.drawCircle(
      Offset(centerX, pivotY),
      size.width * 0.04,
      screwPaint,
    );
    
    // Screw slot
    canvas.drawLine(
      Offset(centerX - size.width * 0.025, pivotY),
      Offset(centerX + size.width * 0.025, pivotY),
      Paint()
        ..color = const Color(0xFF404040)
        ..strokeWidth = 2,
    );
  }

  void _drawLeverArm(Canvas canvas, Size size, double centerX) {
    final armWidth = size.width * 0.09;
    final armTop = size.height * 0.14;
    final armBottom = size.height * 0.72;
    
    // Arm moves noticeably based on press (perspective shift)
    final pressOffset = pressAmount * 12;
    
    // Arm shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - armWidth / 2 + 2,
          armTop + 3,
          armWidth,
          armBottom - armTop,
        ),
        Radius.circular(armWidth / 4),
      ),
      Paint()
        ..color = Colors.black.withAlpha(60)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    
    // Main arm body - brushed metal gradient
    final armRect = Rect.fromLTWH(
      centerX - armWidth / 2,
      armTop - pressOffset,
      armWidth,
      armBottom - armTop,
    );
    
    final armGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: enabled
          ? [
              const Color(0xFF909090),
              const Color(0xFFD8D8D8),
              const Color(0xFFE8E8E8),
              const Color(0xFFD0D0D0),
              const Color(0xFF808080),
            ]
          : [
              const Color(0xFF606060),
              const Color(0xFF888888),
              const Color(0xFF909090),
              const Color(0xFF808080),
              const Color(0xFF505050),
            ],
      stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
    );
    
    final armPaint = Paint()
      ..shader = armGradient.createShader(armRect);
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(armRect, Radius.circular(armWidth / 4)),
      armPaint,
    );
    
    // Arm edge highlights
    canvas.drawLine(
      Offset(centerX - armWidth / 2 + 1, armTop - pressOffset + 10),
      Offset(centerX - armWidth / 2 + 1, armBottom - pressOffset - 10),
      Paint()
        ..color = Colors.white.withAlpha(40)
        ..strokeWidth = 1,
    );
  }

  void _drawContactPoints(Canvas canvas, Size size, double centerX) {
    final contactY = size.height * 0.38;
    
    // Contact block housing (left and right)
    final blockPaint = Paint()
      ..color = const Color(0xFF2A2A2A);
    
    final blockWidth = size.width * 0.12;
    final blockHeight = size.height * 0.06;
    
    // Left contact block
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX - size.width * 0.18, contactY),
          width: blockWidth,
          height: blockHeight,
        ),
        const Radius.circular(3),
      ),
      blockPaint,
    );
    
    // Right contact block
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX + size.width * 0.18, contactY),
          width: blockWidth,
          height: blockHeight,
        ),
        const Radius.circular(3),
      ),
      blockPaint,
    );
    
    // Contact screws
    final contactScrewPaint = Paint()
      ..color = enabled ? AppColors.brass : AppColors.brass.withAlpha(128);
    
    canvas.drawCircle(
      Offset(centerX - size.width * 0.18, contactY),
      size.width * 0.035,
      contactScrewPaint,
    );
    canvas.drawCircle(
      Offset(centerX + size.width * 0.18, contactY),
      size.width * 0.035,
      contactScrewPaint,
    );
    
    // Spark effect when pressed
    if (pressAmount > 0.3 && enabled) {
      final sparkPaint = Paint()
        ..color = AppColors.warningAmber.withAlpha((pressAmount * 180).toInt())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      
      canvas.drawCircle(
        Offset(centerX, contactY),
        4 + pressAmount * 3,
        sparkPaint,
      );
    }
  }

  void _drawTapperKnob(Canvas canvas, Size size, double centerX) {
    final knobCenterY = size.height * 0.82;
    final knobRadius = size.width * 0.22;
    
    // Press animation - knob moves down noticeably
    final pressOffset = pressAmount * 16;
    final adjustedY = knobCenterY + pressOffset;
    
    // Knob outer shadow
    canvas.drawCircle(
      Offset(centerX + 2, adjustedY + 4),
      knobRadius,
      Paint()
        ..color = Colors.black.withAlpha(100)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    
    // Knob outer ring (brass/gold)
    final outerRingGradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      radius: 1.0,
      colors: enabled
          ? [
              const Color(0xFFE8C860),
              AppColors.brass,
              const Color(0xFFB08020),
            ]
          : [
              const Color(0xFF907830),
              const Color(0xFF706020),
              const Color(0xFF504010),
            ],
    );
    
    canvas.drawCircle(
      Offset(centerX, adjustedY),
      knobRadius,
      Paint()
        ..shader = outerRingGradient.createShader(
          Rect.fromCircle(center: Offset(centerX, adjustedY), radius: knobRadius),
        ),
    );
    
    // Knob inner (black bakelite)
    final innerRadius = knobRadius * 0.82;
    const innerGradient = RadialGradient(
      center: Alignment(-0.2, -0.3),
      radius: 1.2,
      colors: [
        Color(0xFF3A3A3A),
        Color(0xFF1A1A1A),
        Color(0xFF0A0A0A),
      ],
    );
    
    canvas.drawCircle(
      Offset(centerX, adjustedY),
      innerRadius,
      Paint()
        ..shader = innerGradient.createShader(
          Rect.fromCircle(center: Offset(centerX, adjustedY), radius: innerRadius),
        ),
    );
    
    // Knob highlight arc
    final highlightPath = Path()
      ..addArc(
        Rect.fromCircle(center: Offset(centerX, adjustedY), radius: innerRadius * 0.85),
        -2.5, // start angle
        1.2, // sweep angle
      );
    canvas.drawPath(
      highlightPath,
      Paint()
        ..color = Colors.white.withAlpha(25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    
    // Center dimple
    canvas.drawCircle(
      Offset(centerX, adjustedY),
      size.width * 0.03,
      Paint()..color = const Color(0xFF0A0A0A),
    );
  }

  void _drawScrews(Canvas canvas, Size size) {
    final screwPaint = Paint()
      ..color = enabled ? const Color(0xFF707070) : const Color(0xFF505050);
    final slotPaint = Paint()
      ..color = const Color(0xFF303030)
      ..strokeWidth = 1.5;
    
    // Corner screws on base
    final screwPositions = [
      Offset(size.width * 0.22, size.height * 0.14),
      Offset(size.width * 0.78, size.height * 0.14),
      Offset(size.width * 0.22, size.height * 0.52),
      Offset(size.width * 0.78, size.height * 0.52),
    ];
    
    for (final pos in screwPositions) {
      // Screw head
      canvas.drawCircle(pos, size.width * 0.028, screwPaint);
      
      // Screw slot (alternating directions for realism)
      final slotAngle = screwPositions.indexOf(pos) % 2 == 0 ? 0.0 : 0.7;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(slotAngle);
      canvas.drawLine(
        Offset(-size.width * 0.018, 0),
        Offset(size.width * 0.018, 0),
        slotPaint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _TopDownKeyPainter oldDelegate) {
    return oldDelegate.pressAmount != pressAmount ||
        oldDelegate.enabled != enabled;
  }
}

/// A simpler paddle-style key for iambic keying (advanced users)
class PaddleKey extends StatelessWidget {
  final VoidCallback? onDotPress;
  final VoidCallback? onDotRelease;
  final VoidCallback? onDashPress;
  final VoidCallback? onDashRelease;
  final bool enabled;

  const PaddleKey({
    super.key,
    this.onDotPress,
    this.onDotRelease,
    this.onDashPress,
    this.onDashRelease,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dot paddle (left)
        _PaddleButton(
          label: '●',
          onPress: onDotPress,
          onRelease: onDotRelease,
          enabled: enabled,
          isLeft: true,
        ),
        const SizedBox(width: 20),
        // Dash paddle (right)
        _PaddleButton(
          label: '━',
          onPress: onDashPress,
          onRelease: onDashRelease,
          enabled: enabled,
          isLeft: false,
        ),
      ],
    );
  }
}

class _PaddleButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPress;
  final VoidCallback? onRelease;
  final bool enabled;
  final bool isLeft;

  const _PaddleButton({
    required this.label,
    this.onPress,
    this.onRelease,
    required this.enabled,
    required this.isLeft,
  });

  @override
  State<_PaddleButton> createState() => _PaddleButtonState();
}

class _PaddleButtonState extends State<_PaddleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (!widget.enabled) return;
        setState(() => _isPressed = true);
        HapticFeedback.lightImpact();
        widget.onPress?.call();
      },
      onTapUp: (_) {
        if (!widget.enabled) return;
        setState(() => _isPressed = false);
        widget.onRelease?.call();
      },
      onTapCancel: () {
        if (!widget.enabled) return;
        setState(() => _isPressed = false);
        widget.onRelease?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: 80,
        height: 100,
        decoration: BoxDecoration(
          color: _isPressed
              ? AppColors.brass
              : (widget.enabled ? AppColors.mahogany : AppColors.mahogany.withAlpha(128)),
          borderRadius: BorderRadius.horizontal(
            left: widget.isLeft ? const Radius.circular(20) : Radius.zero,
            right: widget.isLeft ? Radius.zero : const Radius.circular(20),
          ),
          border: Border.all(
            color: widget.enabled ? AppColors.brass : AppColors.brass.withAlpha(128),
            width: 3,
          ),
          boxShadow: _isPressed
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(77),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Center(
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 32,
              color: _isPressed
                  ? AppColors.darkWood
                  : (widget.enabled ? AppColors.brass : AppColors.brass.withAlpha(128)),
            ),
          ),
        ),
      ),
    );
  }
}
