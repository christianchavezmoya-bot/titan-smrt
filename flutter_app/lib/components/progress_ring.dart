import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../design_tokens/tokens.dart';

/// ProgressRing Component
/// States: loading | animating | complete | error
/// A11y: role="progressbar", aria-valuenow/min/max, VoiceOver "X of Y completed"
/// Perf: CustomPainter, 60fps spring animation

enum ProgressRingState {
  loading,
  animating,
  complete,
  error,
}

class ProgressRing extends StatefulWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 80.0,
    this.strokeWidth = 8.0,
    this.state = ProgressRingState.animating,
    this.showLabel = true,
    this.label,
    this.sublabel,
    this.color,
    this.backgroundColor,
    this.onComplete,
  }) : assert(progress >= 0.0 && progress <= 1.0);

  final double progress;
  final double size;
  final double strokeWidth;
  final ProgressRingState state;
  final bool showLabel;
  final String? label;
  final String? sublabel;
  final Color? color;
  final Color? backgroundColor;
  final VoidCallback? onComplete;

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _displayedProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: TitanMotion.durationNormal,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: widget.progress,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: TitanMotion.easingStandard,
    ));
    _controller.addListener(_onAnimationUpdate);
    _controller.forward();
  }

  @override
  void didUpdateWidget(ProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation = Tween<double>(
        begin: _displayedProgress,
        end: widget.progress,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: TitanMotion.easingStandard,
      ));
      _controller.reset();
      _controller.forward();
    }
  }

  void _onAnimationUpdate() {
    setState(() {
      _displayedProgress = _animation.value;
    });
    if (_displayedProgress >= 1.0 && widget.onComplete != null) {
      widget.onComplete!();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onAnimationUpdate);
    _controller.dispose();
    super.dispose();
  }

  Color get _progressColor {
    if (widget.color != null) return widget.color!;
    switch (widget.state) {
      case ProgressRingState.loading:
        return TitanColors.text600;
      case ProgressRingState.animating:
        return TitanColors.primary500;
      case ProgressRingState.complete:
        return TitanColors.statusSuccess;
      case ProgressRingState.error:
        return TitanColors.statusError;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      value: '${(_displayedProgress * 100).round()}%',
      hint: 'Progress indicator',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _ProgressRingPainter(
                progress: _displayedProgress,
                color: _progressColor,
                backgroundColor: widget.backgroundColor ?? TitanColors.surface600,
                strokeWidth: widget.strokeWidth,
                state: widget.state,
              ),
              child: Center(
                child: _buildCenterContent(),
              ),
            ),
          ),
          if (widget.showLabel && widget.label != null) ...[
            const SizedBox(height: TitanSpacing.space12),
            Text(
              widget.label!,
              style: const TextStyle(
                fontFamily: TitanTypography.fontFamilyUI,
                fontSize: TitanTypography.fontSize14,
                fontWeight: TitanTypography.weightMedium,
                color: TitanColors.text900,
              ),
            ),
          ],
          if (widget.sublabel != null) ...[
            const SizedBox(height: TitanSpacing.space4),
            Text(
              widget.sublabel!,
              style: const TextStyle(
                fontFamily: TitanTypography.fontFamilyUI,
                fontSize: TitanTypography.fontSize12,
                color: TitanColors.text600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCenterContent() {
    switch (widget.state) {
      case ProgressRingState.loading:
        return SizedBox(
          width: widget.size * 0.3,
          height: widget.size * 0.3,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(_progressColor),
          ),
        );
      case ProgressRingState.complete:
        return Icon(
          Icons.check_rounded,
          size: widget.size * 0.4,
          color: TitanColors.statusSuccess,
        );
      case ProgressRingState.error:
        return Icon(
          Icons.error_outline_rounded,
          size: widget.size * 0.4,
          color: TitanColors.statusError,
        );
      case ProgressRingState.animating:
        return Text(
          '${(_displayedProgress * 100).round()}',
          style: TextStyle(
            fontFamily: TitanTypography.fontFamilyMetric,
            fontSize: widget.size * 0.28,
            fontWeight: TitanTypography.weightBold,
            color: TitanColors.text900,
          ),
        );
    }
  }
}

class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
    required this.state,
  });

  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;
  final ProgressRingState state;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    final startAngle = -math.pi / 2; // Start from top

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.state != state;
  }
}

/// A variant that shows a circular progress indicator for loading states
class TitanLoadingRing extends StatelessWidget {
  const TitanLoadingRing({
    super.key,
    this.size = 24.0,
    this.strokeWidth = 2.0,
    this.color,
  });

  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? TitanColors.primary500,
        ),
      ),
    );
  }
}