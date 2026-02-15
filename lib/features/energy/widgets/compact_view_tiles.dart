// lib/features/energy/widgets/compact_insights.dart
//
// Compact insights grid with stronger pulse on the current hour,
// tightened vertical spacing between rows.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:Watt/features/energy/models/energy_point.dart';

class CompactInsightsGrid extends StatefulWidget {
  final List<EnergyPoint> points;
  final int columns;
  final EdgeInsetsGeometry padding;

  const CompactInsightsGrid({
    super.key,
    required this.points,
    this.columns = 4,
    // slightly tighter bottom padding, too
    this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 18),
  });

  @override
  State<CompactInsightsGrid> createState() => _CompactInsightsGridState();
}

class _CompactInsightsGridState extends State<CompactInsightsGrid> {
  late Timer _timer;
  int _currentHour = DateTime.now().hour;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      final h = DateTime.now().hour;
      if (h != _currentHour) setState(() => _currentHour = h);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = widget.points;

    return LayoutBuilder(
      builder: (context, constraints) {
        final gridWidth = constraints.maxWidth;
        const gap = 14.0; // a touch tighter horizontally
        final cellW =
            (gridWidth - (widget.columns - 1) * gap - _padH(widget.padding)) /
            widget.columns;

        // keep circle comfortable but cap a bit smaller to save height
        final double circleSize = cellW.clamp(40.0, 54.0).toDouble();

        // —— tightened vertical metrics
        const labelHeight = 30.0; // was 34
        const topGap = 4.0; // was 6
        const betweenLabelGap = 4.0; // was 6
        const underlineH = 2.0; // was 3

        final double mainAxisExtent =
            circleSize +
            topGap +
            labelHeight +
            betweenLabelGap +
            underlineH +
            4;

        return GridView.builder(
          padding: widget.padding,
          itemCount: sorted.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.columns,
            crossAxisSpacing: gap,
            mainAxisSpacing: 8, // was 18 → much tighter rows
            mainAxisExtent: mainAxisExtent,
          ),
          itemBuilder: (context, i) {
            final p = sorted[i];
            final band = _compactBandFor(p.energy);
            final staggerMs = 40 * (i % widget.columns);

            return _CompactCell(
              key: ValueKey('cell-${p.hour}-${band.label}'),
              hour: p.hour,
              label: band.label,
              circleColor: band.color,
              underlineColor: band.color,
              circleSize: circleSize,
              staggerMs: staggerMs,
              isCurrentHour: p.hour == _currentHour,
            );
          },
        );
      },
    );
  }

  double _padH(EdgeInsetsGeometry g) =>
      (g.resolve(TextDirection.ltr).left + g.resolve(TextDirection.ltr).right);
}

class _CompactCell extends StatefulWidget {
  final int hour;
  final String label;
  final Color circleColor;
  final double circleSize;
  final Color underlineColor;
  final int staggerMs;
  final bool isCurrentHour;

  const _CompactCell({
    super.key,
    required this.hour,
    required this.label,
    required this.circleColor,
    required this.circleSize,
    required this.underlineColor,
    this.staggerMs = 0,
    required this.isCurrentHour,
  });

  @override
  State<_CompactCell> createState() => _CompactCellState();
}

class _CompactCellState extends State<_CompactCell>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      lowerBound: 0.76,
      upperBound: 1.24,
    );
    if (widget.isCurrentHour) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _CompactCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentHour && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isCurrentHour && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onCircle = _onColorFor(widget.circleColor);

    final circleDur = Duration(milliseconds: 160 + widget.staggerMs);
    final barDur = Duration(milliseconds: 220 + widget.staggerMs);

    final ringBase = widget.circleColor.withOpacity(0.42);

    return ScaleTransition(
      scale: widget.isCurrentHour
          ? _pulse.drive(Tween(begin: 0.94, end: 1.0))
          : const AlwaysStoppedAnimation(1.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Circle
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.94, end: 1.0),
            duration: circleDur,
            curve: Curves.easeOutCubic,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final t =
                    ((_pulse.value - _pulse.lowerBound) /
                            (_pulse.upperBound - _pulse.lowerBound))
                        .clamp(0.0, 1.0);
                final ringWidth = widget.isCurrentHour ? (1.5 + 6.0 * t) : 0.0;
                final ringBlur = widget.isCurrentHour ? (8.0 + 16.0 * t) : 0.0;
                final spread = widget.isCurrentHour ? (2.0 + 3.0 * t) : 0.0;

                return Container(
                  width: widget.circleSize,
                  height: widget.circleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.circleColor,
                    border: ringWidth > 0
                        ? Border.all(color: ringBase, width: ringWidth)
                        : null,
                    boxShadow: [
                      if (widget.isCurrentHour)
                        BoxShadow(
                          color: ringBase,
                          blurRadius: ringBlur,
                          spreadRadius: spread,
                        ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Transform.scale(
                    scale: widget.isCurrentHour ? (0.98 + 0.06 * t) : 1.0,
                    child: Text(
                      '${widget.hour}',
                      style: TextStyle(
                        color: onCircle,
                        fontSize:
                            widget.circleSize *
                            (widget.isCurrentHour ? 0.42 : 0.34),
                        fontWeight: widget.isCurrentHour
                            ? FontWeight.w900
                            : FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 4), // was 6
          // Label (no icon, tighter width & line height)
          SizedBox(
            width: widget.circleSize + 12, // was +20
            child: Text(
              widget.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: widget.isCurrentHour
                    ? FontWeight.w700
                    : FontWeight.w600,
                fontSize: 11.0, // was 11.5
                letterSpacing: 0.15,
                height: 1.25, // was 1.3
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.85),
              ),
            ),
          ),

          const SizedBox(height: 4), // was 6
          // Underline
          TweenAnimationBuilder<double>(
            key: ValueKey('bar-${widget.hour}-${widget.label}'),
            tween: Tween(begin: 0.0, end: 22.0),
            duration: barDur,
            curve: Curves.easeOutCubic,
            builder: (context, w, _) {
              return SizedBox(
                width: w,
                height: 2, // was 3
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.underlineColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CompactEnergyBand {
  final String label;
  final Color color;
  const _CompactEnergyBand(this.label, this.color);
}

_CompactEnergyBand _compactBandFor(double energy) {
  final e = energy.clamp(0, 100);
  if (e <= 20) {
    return const _CompactEnergyBand('Running on fumes', Color(0xFFE53935));
  } else if (e <= 40) {
    return const _CompactEnergyBand('Warming up', Color(0xFFFFA000));
  } else if (e <= 60) {
    return const _CompactEnergyBand('Steady', Color(0xFFFFC107));
  } else if (e <= 80) {
    return const _CompactEnergyBand('Peak energy', Color(0xFF43A047));
  } else {
    return const _CompactEnergyBand('Strong', Color(0xFF1B5E20));
  }
}

Color _onColorFor(Color bg) {
  // Always use white for better consistency and contrast in this design.
  return Colors.white;
}
