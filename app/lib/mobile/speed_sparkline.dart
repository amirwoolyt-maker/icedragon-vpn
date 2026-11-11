import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../ui/format.dart';
import 'mobile_strings.dart';
import 'mobile_theme.dart';

/// Sample of upload and download throughput in bytes per second.
class SpeedSample {
  const SpeedSample(this.downRate, this.upRate);

  final int downRate;
  final int upRate;
}

/// Bounded telemetry history shared across home rebuilds so the sparkline stays
/// smooth while polling updates every two seconds without idle CPU drain.
class SpeedHistory {
  SpeedHistory._();

  static const maxSamples = 32;
  static final List<SpeedSample> _samples = <SpeedSample>[];
  static DateTime? _lastSignature;

  static void record(CoreStatus status) {
    final t = status.traffic;
    if (!status.proxyOn || t == null) {
      if (_samples.isNotEmpty) {
        _samples.clear();
        _lastSignature = null;
      }
      return;
    }
    final marker = status.proxy?.startedAt;
    if (_lastSignature != marker) {
      _samples.clear();
      _lastSignature = marker;
    }
    _samples.add(SpeedSample(t.downRate, t.upRate));
    if (_samples.length > maxSamples) {
      _samples.removeAt(0);
    }
  }

  static List<SpeedSample> get samples => List.unmodifiable(_samples);
}

/// Live connection duration counter formatted as `MM:SS` or `HH:MM:SS`.
/// Uses a 1-second timer only while [startedAt] is active and animations are enabled.
class SessionDurationText extends StatefulWidget {
  const SessionDurationText({
    super.key,
    required this.startedAt,
    required this.style,
  });

  final DateTime? startedAt;
  final TextStyle? style;

  @override
  State<SessionDurationText> createState() => _SessionDurationTextState();
}

class _SessionDurationTextState extends State<SessionDurationText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(SessionDurationText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAt != widget.startedAt) {
      _syncTimer();
    }
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (widget.startedAt != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.startedAt;
    if (start == null) return const SizedBox.shrink();
    var diff = DateTime.now().difference(start);
    if (diff.isNegative) diff = Duration.zero;
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
    final text = hours > 0
        ? '${hours.toString().padLeft(2, '0')}:$minutes:$seconds'
        : '$minutes:$seconds';
    return Text(ltr(text), style: widget.style);
  }
}

/// Sleek glassmorphic speed & session card showing live upload/download sparkline,
/// current throughput rates, total transferred volume, and session timer.
class LiveSpeedCard extends StatelessWidget {
  const LiveSpeedCard({
    super.key,
    required this.traffic,
    required this.samples,
    required this.startedAt,
    required this.dark,
    required this.textColor,
    required this.mutedColor,
    this.compact = false,
  });

  final Traffic traffic;
  final List<SpeedSample> samples;
  final DateTime? startedAt;
  final bool dark;
  final Color textColor;
  final Color mutedColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ms = MobileStrings.of(context);
    final theme = Theme.of(context);
    final totalProxy = traffic.down + traffic.up;
    return GlassCard(
      dark: dark,
      radius: 22,
      padding: EdgeInsets.fromLTRB(
        14,
        compact ? 10 : 12,
        14,
        compact ? 10 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _SpeedMetric(
                icon: Icons.south_rounded,
                color: DarkGlassPalette.mint,
                label: ms.downloadLabel,
                value: formatRate(traffic.downRate),
                textColor: textColor,
                mutedColor: mutedColor,
              ),
              const SizedBox(width: 14),
              _SpeedMetric(
                icon: Icons.north_rounded,
                color: DarkGlassPalette.cyan,
                label: ms.uploadLabel,
                value: formatRate(traffic.upRate),
                textColor: textColor,
                mutedColor: mutedColor,
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    ms.sessionData,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: mutedColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatBytes(totalProxy),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: compact ? 30 : 38,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CustomPaint(
                painter: _SparklinePainter(
                  samples: samples,
                  downColor: DarkGlassPalette.mint,
                  upColor: DarkGlassPalette.cyan,
                  gridColor: mutedColor.withValues(alpha: 0.14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedMetric extends StatelessWidget {
  const _SpeedMetric({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.textColor,
    required this.mutedColor,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final Color textColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: mutedColor),
            ),
            Text(
              value,
              style: theme.textTheme.labelLarge?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.samples,
    required this.downColor,
    required this.upColor,
    required this.gridColor,
  });

  final List<SpeedSample> samples;
  final Color downColor;
  final Color upColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
      gridPaint,
    );
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      gridPaint,
    );

    if (samples.length < 2) return;

    var maxRate = 1024;
    for (final s in samples) {
      maxRate = math.max(maxRate, math.max(s.downRate, s.upRate));
    }
    final ceiling = maxRate.toDouble();

    _drawSeries(
      canvas,
      size,
      [for (final s in samples) s.upRate / ceiling],
      upColor,
      fillAlpha: 0.10,
      strokeWidth: 1.5,
    );
    _drawSeries(
      canvas,
      size,
      [for (final s in samples) s.downRate / ceiling],
      downColor,
      fillAlpha: 0.24,
      strokeWidth: 2.0,
    );
  }

  void _drawSeries(
    Canvas canvas,
    Size size,
    List<double> values,
    Color color, {
    required double fillAlpha,
    required double strokeWidth,
  }) {
    final n = values.length;
    final dx = size.width / (n - 1);
    final padTop = 3.0;
    final usable = math.max(4.0, size.height - padTop - 2);
    final points = <Offset>[
      for (var i = 0; i < n; i++)
        Offset(
          i * dx,
          size.height - 2 - values[i].clamp(0.0, 1.0) * usable,
        ),
    ];

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      line.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    final fill = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: fillAlpha),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fill, fillPaint);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(line, strokePaint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.samples.length != samples.length ||
      (samples.isNotEmpty &&
          old.samples.isNotEmpty &&
          (old.samples.last.downRate != samples.last.downRate ||
              old.samples.last.upRate != samples.last.upRate));
}
