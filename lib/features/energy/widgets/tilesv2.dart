import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watt/features/energy/models/energy_feedback.dart';
import 'package:watt/features/energy/models/energy_point.dart';

// -----------------------------------------------------------------------------
// Existing helpers you already have (kept)
// -----------------------------------------------------------------------------
const _kGreyscaleFilter = ColorFilter.matrix(<double>[
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
]);

bool _shouldGrayOut(EnergyFeedback? fb) =>
    fb != null && fb != EnergyFeedback.match;

Color _onColorFor(Color bg) =>
    bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

// -----------------------------------------------------------------------------
// Density enum (kept)
// -----------------------------------------------------------------------------
enum EnergyTileDensity { comfortable, compact }

// -----------------------------------------------------------------------------
// EnergyTileList (unchanged behavior)
// -----------------------------------------------------------------------------
int _offsetFromStart(int hour, int start) => (hour - start + 24) % 24;

int _findCutIndex(List<EnergyPoint> entries, int nowHour) {
  if (entries.isEmpty) return 0;
  final start = entries.first.hour;
  final nowOff = _offsetFromStart(nowHour, start);

  for (int i = 0; i < entries.length; i++) {
    if (entries[i].hour == nowHour) return i;
  }

  for (int i = 0; i < entries.length; i++) {
    final off = _offsetFromStart(entries[i].hour, start);
    if (off > nowOff) return i;
  }

  return entries.length;
}

class EnergyTileList extends ConsumerWidget {
  final List<EnergyPoint> entries;
  final Map<int, EnergyFeedbackRecord> existingFeedbackMap;

  final Future<void> Function({
    required int hour,
    required EnergyFeedback feedback,
    required double predictedEnergy,
  })
  onSubmitFeedback;

  final EdgeInsetsGeometry? listPadding;
  final bool upcomingOnly;
  final int? fromHourOverride;
  final EnergyTileDensity density;

  const EnergyTileList({
    super.key,
    required this.entries,
    required this.existingFeedbackMap,
    required this.onSubmitFeedback,
    this.upcomingOnly = false,
    this.fromHourOverride,
    this.density = EnergyTileDensity.compact,
    this.listPadding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowHour = fromHourOverride ?? DateTime.now().hour;

    final source = entries;
    final visibleList = upcomingOnly
        ? source.where((e) => e.hour > nowHour - 2).toList()
        : source;

    final cutIndex = _findCutIndex(visibleList, nowHour);
    final padding = listPadding ?? const EdgeInsets.fromLTRB(12, 12, 12, 72);
    final itemGap = density == EnergyTileDensity.compact ? 6.0 : 10.0;

    if (visibleList.isEmpty) {
      return const _EmptyState(
        message: "Good night! Check back tomorrow for your energy prediction!",
      );
    }

    return ListView.separated(
      padding: padding,
      itemCount: visibleList.length,
      separatorBuilder: (_, __) => SizedBox(height: itemGap),
      itemBuilder: (context, i) {
        final point = visibleList[i];

        final existingRecord = existingFeedbackMap[point.hour];
        final savedFeedback = existingRecord?.feedback;

        final bool shouldShowFeedback =
            (i < cutIndex) && (savedFeedback == null);

        return _EnergyTileWithFeedbackShell(
          hour: point.hour,
          energy: point.energy,
          density: density,
          existingFeedback: savedFeedback,
          showFeedbackBarInitially: shouldShowFeedback,
          onSidebarFeedback: (fb) => onSubmitFeedback(
            hour: point.hour,
            feedback: fb,
            predictedEnergy: point.energy,
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// NEW: Swipe-to-reveal shell (no resizing)
// -----------------------------------------------------------------------------
class _EnergyTileWithFeedbackShell extends StatefulWidget {
  final int hour;
  final double energy;
  final EnergyTileDensity density;

  final bool showFeedbackBarInitially;
  final Future<void> Function(EnergyFeedback fb) onSidebarFeedback;

  final EnergyFeedback? existingFeedback;

  const _EnergyTileWithFeedbackShell({
    required this.hour,
    required this.energy,
    required this.density,
    required this.showFeedbackBarInitially,
    required this.onSidebarFeedback,
    required this.existingFeedback,
  });

  @override
  State<_EnergyTileWithFeedbackShell> createState() =>
      _EnergyTileWithFeedbackShellState();
}

class _EnergyTileWithFeedbackShellState
    extends State<_EnergyTileWithFeedbackShell> {
  bool _saving = false;

  bool get _canRate =>
      widget.showFeedbackBarInitially && widget.existingFeedback == null;

  Future<void> _handleSelect(EnergyFeedback fb) async {
    if (_saving) return;

    setState(() => _saving = true);
    try {
      await widget.onSidebarFeedback(fb);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If already rated or not eligible, render normal tile (same size as others).
    if (!_canRate) {
      return EnergyTile(
        hour: widget.hour,
        energy: widget.energy,
        density: widget.density,
        submittedFeedback: widget.existingFeedback,
        showSwipeHint: false,
      );
    }

    // Swipe-enabled tile (drawer behind, tile slides left).
    return _SwipeRevealFeedbackTile(
      density: widget.density,
      isBusy: _saving,
      onSelect: _handleSelect,
      child: EnergyTile(
        hour: widget.hour,
        energy: widget.energy,
        density: widget.density,
        submittedFeedback: null,
        showSwipeHint: true,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Swipe reveal implementation (no external packages)
// -----------------------------------------------------------------------------
class _SwipeRevealFeedbackTile extends StatefulWidget {
  final Widget child;
  final EnergyTileDensity density;
  final bool isBusy;
  final void Function(EnergyFeedback fb) onSelect;

  const _SwipeRevealFeedbackTile({
    required this.child,
    required this.density,
    required this.isBusy,
    required this.onSelect,
  });

  @override
  State<_SwipeRevealFeedbackTile> createState() =>
      _SwipeRevealFeedbackTileState();
}

class _SwipeRevealFeedbackTileState extends State<_SwipeRevealFeedbackTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // 0 = closed, 1 = fully open
  double get _t => _ctrl.value;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _drawerWidth(EnergyTileDensity density) =>
      density == EnergyTileDensity.compact ? 158.0 : 186.0;

  void _animateTo(double target) {
    _ctrl.animateTo(target.clamp(0.0, 1.0), curve: Curves.easeOutCubic);
  }

  void _close() => _animateTo(0);
  void _open() => _animateTo(1);

  @override
  Widget build(BuildContext context) {
    final drawerW = _drawerWidth(widget.density);

    // The tile radius should match EnergyTile's radius so the stack clips cleanly.
    final tileRadius = widget.density == EnergyTileDensity.compact
        ? 12.0
        : 16.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(tileRadius),
      child: LayoutBuilder(
        builder: (context, c) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_t > 0.01) _close();
            },
            onHorizontalDragUpdate: widget.isBusy
                ? null
                : (d) {
                    // drag left opens (negative dx)
                    final delta = -d.delta.dx / drawerW;
                    _ctrl.value = (_ctrl.value + delta).clamp(0.0, 1.0);
                  },
            onHorizontalDragEnd: widget.isBusy
                ? null
                : (d) {
                    final v = d.primaryVelocity ?? 0;

                    // Quick fling logic:
                    if (v < -500) {
                      _open();
                      return;
                    }
                    if (v > 500) {
                      _close();
                      return;
                    }

                    // Settle based on threshold:
                    if (_t >= 0.35) {
                      _open();
                    } else {
                      _close();
                    }
                  },
            child: RepaintBoundary(
              child: Stack(
                children: [
                  // Drawer behind, aligned to the right.
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: drawerW,
                        child: _FeedbackDrawer(
                          density: widget.density,
                          onSelect: (fb) {
                            _close();
                            widget.onSelect(fb);
                          },
                        ),
                      ),
                    ),
                  ),

                  // Foreground tile slides left, revealing drawer.
                  AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(-drawerW * _t, 0),
                        child: child,
                      );
                    },
                    child: widget.child,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FeedbackDrawer extends StatelessWidget {
  final EnergyTileDensity density;
  final void Function(EnergyFeedback fb) onSelect;

  const _FeedbackDrawer({
    super.key,
    required this.density,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const items = <EnergyFeedback>[
      EnergyFeedback.muchHigher,
      EnergyFeedback.higher,
      EnergyFeedback.match,
      EnergyFeedback.lower,
      EnergyFeedback.muchLower,
    ];

    final compact = density == EnergyTileDensity.compact;
    final radius = compact ? 12.0 : 16.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.black.withOpacity(0.08), width: 1),
        ),
        child: Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              Expanded(
                child: _FeedbackRowNeutral(
                  fb: items[i],
                  density: density,
                  onTap: () => onSelect(items[i]),
                  isFirst: i == 0,
                  isLast: i == items.length - 1,
                ),
              ),
              if (i != items.length - 1)
                Divider(height: 1, thickness: 1, color: Colors.black12),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeedbackRowNeutral extends StatelessWidget {
  final EnergyFeedback fb;
  final EnergyTileDensity density;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  const _FeedbackRowNeutral({
    required this.fb,
    required this.density,
    required this.onTap,
    required this.isFirst,
    required this.isLast,
  });

  String _label(EnergyFeedback fb) {
    switch (fb) {
      case EnergyFeedback.muchHigher:
        return "Way higher";
      case EnergyFeedback.higher:
        return "Higher";
      case EnergyFeedback.match:
        return "Spot on";
      case EnergyFeedback.lower:
        return "Lower";
      case EnergyFeedback.muchLower:
        return "Way lower";
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = density == EnergyTileDensity.compact;
    final accent = _colorForFeedback(fb);

    final textStyle = TextStyle(
      color: Colors.black.withOpacity(0.88),
      fontWeight: FontWeight.w800,
      fontSize: compact ? 12 : 13, // smaller
      height: 1.0,
    );

    final iconSize = compact ? 20.0 : 22.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 6 : 8,
          ),
          child: Row(
            children: [
              // Thin accent bar (premium look, subtle)
              Container(
                width: 4,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              SizedBox(width: compact ? 10 : 12),

              // Icon in a soft-tinted chip (no harsh block colors)
              Container(
                width: compact ? 30 : 34,
                height: compact ? 30 : 34,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    _iconForFeedback(fb),
                    color: accent.withOpacity(0.95),
                    size: iconSize,
                  ),
                ),
              ),

              SizedBox(width: compact ? 10 : 12),

              // Label (black)
              Expanded(
                child: Text(
                  _label(fb),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// EnergyTile (DESIGN UPGRADE): gradient + dot pattern, same texts/layout
// -----------------------------------------------------------------------------
class EnergyTile extends StatelessWidget {
  final int hour;
  final double energy;
  final EnergyTileDensity density;

  final EnergyFeedback? submittedFeedback;

  /// Show the "Swipe to rate..." hint when feedback is needed.
  final bool showSwipeHint;

  const EnergyTile({
    super.key,
    required this.hour,
    required this.energy,
    required this.density,
    this.submittedFeedback,
    this.showSwipeHint = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final band = _bandFor(energy, hour);

    final base = band.color;
    final onTile = _onColorFor(base);

    const offWhite = Color(0xFFF8F9FB);
    final pillBg = offWhite.withOpacity(0.92);
    final pillFg = base;
    final barTrack = offWhite.withOpacity(0.45);
    final barFill = offWhite;

    final compact = density == EnergyTileDensity.compact;

    final tileRadius = compact ? 12.0 : 16.0;
    final tilePad = compact
        ? const EdgeInsets.fromLTRB(10, 8, 10, 8)
        : const EdgeInsets.fromLTRB(14, 12, 14, 12);
    final recPad = compact
        ? const EdgeInsets.fromLTRB(10, 10, 10, 18)
        : const EdgeInsets.fromLTRB(10, 18, 10, 44);

    final recStyle =
        (compact ? theme.textTheme.bodyMedium : theme.textTheme.bodyLarge)
            ?.copyWith(height: 1.2, fontWeight: FontWeight.w700, color: onTile);

    final barWidth = compact ? 64.0 : 92.0;
    final barHeight = compact ? 6.0 : 10.0;
    final hourIconSize = compact ? 12.0 : 16.0;
    final chipHPad = compact ? 8.0 : 10.0;
    final chipVPad = compact ? 4.0 : 6.0;
    final pillHPad = compact ? 10.0 : 12.0;
    final pillVPad = compact ? 4.0 : 6.0;
    final pillFont = compact ? 12.0 : 14.0;

    final bool isCompleted = submittedFeedback != null;

    Widget core = Material(
      color: Colors.transparent,
      child: Container(
        padding: tilePad,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tileRadius),
          gradient: _tileGradient(base),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Stack(
          children: [
            // Content
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HourChip(
                      text: "$hour:00",
                      iconSize: hourIconSize,
                      padding: EdgeInsets.symmetric(
                        horizontal: chipHPad,
                        vertical: chipVPad,
                      ),
                      textColor: onTile,
                      iconColor: onTile,
                      borderColor: Colors.white.withOpacity(0.22),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _BandPill(
                          text: band.label,
                          bgColor: pillBg,
                          textStyle: TextStyle(
                            color: pillFg,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                            fontSize: pillFont,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: pillHPad,
                            vertical: pillVPad,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _MiniEnergyBar(
                          value: (energy.clamp(0, 100)) / 100.0,
                          width: barWidth,
                          height: barHeight,
                          trackColor: barTrack,
                          fillColor: barFill,
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Recommendation text (kept)
                Padding(
                  padding: recPad,
                  child: Text(
                    band.recommendation,
                    textAlign: TextAlign.center,
                    maxLines: compact ? 3 : 4,
                    overflow: TextOverflow.ellipsis,
                    style: recStyle,
                  ),
                ),

                // Divider line like your screenshot
                Container(
                  height: 1,
                  margin: const EdgeInsets.only(top: 2),
                  color: Colors.white.withOpacity(0.16),
                ),

                // Bottom row: swipe hint OR confirmation
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 2),
                  child: Row(
                    children: [
                      if (isCompleted)
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Your feedback:",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withOpacity(0.90),
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _iconForFeedback(submittedFeedback!),
                                size: compact ? 18 : 20,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        )
                      else if (showSwipeHint)
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.chevron_left_rounded,
                                color: Colors.white.withOpacity(0.65),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Swipe to rate this prediction",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withOpacity(0.70),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        const Spacer(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (isCompleted && _shouldGrayOut(submittedFeedback)) {
      core = ColorFiltered(
        colorFilter: _kGreyscaleFilter,
        child: Stack(
          children: [
            core,
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(tileRadius),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return core;
  }
}

// -----------------------------------------------------------------------------
// Your existing chips/pills/bars (kept, no behavior change)
// -----------------------------------------------------------------------------
class _HourChip extends StatelessWidget {
  final String text;
  final double iconSize;
  final EdgeInsets padding;
  final Color textColor;
  final Color iconColor;
  final Color borderColor;

  const _HourChip({
    required this.text,
    required this.iconSize,
    required this.padding,
    required this.textColor,
    required this.iconColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
        color: Colors.white.withOpacity(0.06),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: iconSize, color: textColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniEnergyBar extends StatelessWidget {
  final double value;
  final double width;
  final double height;
  final Color trackColor;
  final Color fillColor;

  const _MiniEnergyBar({
    required this.value,
    required this.width,
    required this.height,
    required this.trackColor,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: trackColor,
      ),
      clipBehavior: Clip.hardEdge,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

class _BandPill extends StatelessWidget {
  final String text;
  final Color bgColor;
  final TextStyle textStyle;
  final EdgeInsets padding;

  const _BandPill({
    required this.text,
    required this.bgColor,
    required this.textStyle,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: textStyle),
    );
  }
}

// -----------------------------------------------------------------------------
// Feedback icon/color (your existing mapping kept)
// -----------------------------------------------------------------------------
IconData _iconForFeedback(EnergyFeedback fb) {
  switch (fb) {
    case EnergyFeedback.muchHigher:
      return Icons.keyboard_double_arrow_up_rounded;
    case EnergyFeedback.higher:
      return Icons.keyboard_arrow_up_rounded;
    case EnergyFeedback.match:
      return Icons.check_rounded;
    case EnergyFeedback.lower:
      return Icons.keyboard_arrow_down_rounded;
    case EnergyFeedback.muchLower:
      return Icons.keyboard_double_arrow_down_rounded;
  }
}

Color _colorForFeedback(EnergyFeedback fb) {
  switch (fb) {
    case EnergyFeedback.muchHigher:
      return const Color(0xFFE53935);
    case EnergyFeedback.higher:
      return const Color(0xFFFFA000);
    case EnergyFeedback.match:
      return const Color(0xFF43A047);
    case EnergyFeedback.lower:
      return const Color(0xFFFFA000);
    case EnergyFeedback.muchLower:
      return const Color(0xFFE53935);
  }
}

// -----------------------------------------------------------------------------
// Gradient helpers (for tile + drawer)
// -----------------------------------------------------------------------------
Color _shiftLightness(Color c, double delta) {
  final hsl = HSLColor.fromColor(c);
  final l = (hsl.lightness + delta).clamp(0.0, 1.0);
  return hsl.withLightness(l).toColor();
}

LinearGradient _tileGradient(Color base) {
  // Slightly more “alive” like your screenshots:
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_shiftLightness(base, 0.16), base, _shiftLightness(base, -0.12)],
    stops: const [0.0, 0.55, 1.0],
  );
}

// -----------------------------------------------------------------------------
// Keep ALL your band logic as-is below this point.
// (Your _EnergyBand, _bandFor, pro tips map, etc. remain unchanged.)
// -----------------------------------------------------------------------------

/// --- Energy band logic ----
class _EnergyBand {
  final String label;
  final String recommendation;
  final Color color;
  const _EnergyBand({
    required this.label,
    required this.recommendation,
    required this.color,
  });
}

// Optional: keep your existing _EnergyBand class as-is.

enum _EnergyZone { runningOnFumes, warmingUp, cruising, inTheZone, peakPower }

enum _TimeBlock {
  wake7to8,
  wake9to10,
  wake11to12,
  wake13to14,
  wake15to16,
  wake17to18,
  wake19to20,
  wake21to22,
  sleep23to2,
  sleep3to6,
  other,
}

_EnergyZone _zoneFor(double energy) {
  final e = energy.clamp(0, 100);
  if (e <= 20) return _EnergyZone.runningOnFumes;
  if (e <= 40) return _EnergyZone.warmingUp;
  if (e <= 60) return _EnergyZone.cruising;
  if (e <= 80) return _EnergyZone.inTheZone;
  return _EnergyZone.peakPower;
}

_TimeBlock _timeBlockForHour(int hour0to23) {
  final h = hour0to23 % 24;

  // Resting windows
  if (h == 23 || h == 0 || h == 1 || h == 2) return _TimeBlock.sleep23to2;
  if (h >= 3 && h <= 6) return _TimeBlock.sleep3to6;

  // Waking windows (2-hour blocks)
  if (h == 7 || h == 8) return _TimeBlock.wake7to8;
  if (h == 9 || h == 10) return _TimeBlock.wake9to10;
  if (h == 11 || h == 12) return _TimeBlock.wake11to12;
  if (h == 13 || h == 14) return _TimeBlock.wake13to14;
  if (h == 15 || h == 16) return _TimeBlock.wake15to16;
  if (h == 17 || h == 18) return _TimeBlock.wake17to18;
  if (h == 19 || h == 20) return _TimeBlock.wake19to20;
  if (h == 21 || h == 22) return _TimeBlock.wake21to22;

  return _TimeBlock.other;
}

const Map<_TimeBlock, Map<_EnergyZone, String>> _proTipsByBlock = {
  _TimeBlock.wake7to8: {
    _EnergyZone.peakPower:
        'Use this quiet time to get a 60-minute head start on your most important task.',
    _EnergyZone.inTheZone:
        'Channel this clarity into mapping out your top 3 priorities for the day.',
    _EnergyZone.cruising:
        'Ease into the day. Tidy your workspace and review your calendar.',
    _EnergyZone.warmingUp:
        'Boost your energy with 10 minutes of light stretching or a morning walk.',
    _EnergyZone.runningOnFumes:
        "Don't force it. Start with a full glass of water and try to get 10 minutes of sunlight.",
  },

  _TimeBlock.wake9to10: {
    _EnergyZone.peakPower:
        'This is your prime time. Tackle your single most complex problem right now.',
    _EnergyZone.inTheZone:
        'Silence all notifications. Set a 90-minute timer and dive into your main project.',
    _EnergyZone.cruising:
        'Knock out your first 2-3 "must-do" tasks to build momentum.',
    _EnergyZone.warmingUp:
        'Start with a 10-minute task (like answering one email). Completing it will build energy.',
    _EnergyZone.runningOnFumes:
        'Your energy is low. Instead of doing work, just plan your work. Make a clear list.',
  },

  _TimeBlock.wake11to12: {
    _EnergyZone.peakPower:
        'Channel this energy into your most demanding creative or analytical challenge.',
    _EnergyZone.inTheZone:
        "You're in flow. Postpone any new meetings or calls to protect this state.",
    _EnergyZone.cruising:
        'Good time for a productive check-in meeting or to answer important team emails.',
    _EnergyZone.warmingUp:
        'Build momentum with a productive, low-stress task. Try a 20-minute learning exercise or watch a tutorial.',
    _EnergyZone.runningOnFumes:
        'Step away from your desk. A 5-minute walk and some fresh air can reset your focus.',
  },

  _TimeBlock.wake13to14: {
    _EnergyZone.peakPower:
        "You're full of energy. Use this surge to handle a difficult review or data analysis.",
    _EnergyZone.inTheZone:
        'Eat a light, protein-focused lunch to sustain this focus into the afternoon.',
    _EnergyZone.cruising:
        'Use this time to clear your inbox or manage your calendar for the week.',
    _EnergyZone.warmingUp:
        'A 15-minute walk after you eat is the best way to boost your afternoon energy.',
    _EnergyZone.runningOnFumes:
        'You must take a real break. No "lunch at the desk." Get away from your screen.',
  },

  _TimeBlock.wake15to16: {
    _EnergyZone.peakPower:
        'Channel this sharp afternoon focus into a complex task or a brainstorming session.',
    _EnergyZone.inTheZone:
        'Push to finish one significant part of your project before the day ends.',
    _EnergyZone.cruising:
        'This is a great window for the team project or getting feedback from a colleague.',
    _EnergyZone.warmingUp:
        'Build energy for the final stretch. Switch to simple data entry or file organization.',
    _EnergyZone.runningOnFumes:
        'Your blood sugar may be low. Grab a healthy snack (like nuts or fruit) to avoid a crash.',
  },

  _TimeBlock.wake17to18: {
    _EnergyZone.peakPower:
        "You've got a final burst. Use it to finish one last hard task for a big win.",
    _EnergyZone.inTheZone:
        'Wrap up your main task and write clear "handoff" notes for yourself for tomorrow.',
    _EnergyZone.cruising:
        'Use this steady energy to plan your top 3 tasks for tomorrow. End the day with a clear plan.',
    _EnergyZone.warmingUp:
        "Clean your inbox. A clean slate will boost tomorrow's energy.",
    _EnergyZone.runningOnFumes:
        'Pushing further will lead to mistakes. Call it a day and sign off 15 minutes early.',
  },

  _TimeBlock.wake19to20: {
    _EnergyZone.peakPower:
        "You've got extra energy. Channel it into a hobby, learning, or a creative side project.",
    _EnergyZone.inTheZone:
        'This is a great time for exercise, cooking an engaging new recipe, or focused "play" time.',
    _EnergyZone.cruising:
        'Use this positive, stable energy to connect meaningfully with family or friends.',
    _EnergyZone.warmingUp:
        'A 20-minute walk can help your mind transition from "work" to "home" mode.',
    _EnergyZone.runningOnFumes:
        "You're drained. Your only job is to recharge. Listen to music or an easy-going podcast.",
  },

  _TimeBlock.wake21to22: {
    _EnergyZone.peakPower:
        'Your mind is active. Use it for journaling, reading a book, or brainstorming new ideas.',
    _EnergyZone.inTheZone:
        'Engage in a focused hobby that you enjoy, like reading, drawing, or playing an instrument.',
    _EnergyZone.cruising:
        'Tidy up common areas for 15 minutes or prep your coffee/lunch for tomorrow.',
    _EnergyZone.warmingUp:
        "Start your wind-down routine. A warm shower or bath can help signal to your body it's time to rest.",
    _EnergyZone.runningOnFumes:
        'Your energy is gone. Get off your phone and switch to a physical book or audiobook to rest your eyes.',
  },

  _TimeBlock.sleep23to2: {
    _EnergyZone.peakPower:
        'Your mind is active, but your body needs sleep. Read a physical book (no screens) to wind down.',
    _EnergyZone.inTheZone:
        'You should be winding down. Put your phone in another room now to prepare for deep sleep.',
    _EnergyZone.cruising:
        'This is the perfect time to go to bed. Turn off the lights and aim for 7-8 hours of sleep.',
    _EnergyZone.warmingUp:
        'Your energy is naturally low. Turn down the lights and listen to some calming music or a sleep story.',
    _EnergyZone.runningOnFumes:
        "Your body is telling you it's time to rest. Get into bed immediately.",
  },

  _TimeBlock.sleep3to6: {
    _EnergyZone.peakPower:
        'Awake? Your mind is racing, but your body needs rest. Try a 10-minute guided meditation or body scan.',
    _EnergyZone.inTheZone:
        "Stop checking your phone. Avoid bright lights. Try to relax and drift back to sleep.",
    _EnergyZone.cruising:
        "It's normal to stir. Try changing positions and focus on your breathing.",
    _EnergyZone.warmingUp:
        "It's not time to wake up yet. Try to relax and get this last, valuable bit of rest.",
    _EnergyZone.runningOnFumes:
        "You're awake and exhausted. Put the phone down now. Close your eyes and focus on the simple feeling of resting in bed.",
  },
};

String _fallbackTip(_EnergyZone z) {
  switch (z) {
    case _EnergyZone.runningOnFumes:
      return 'Keep it minimal and recover briefly.';
    case _EnergyZone.warmingUp:
      return 'Do something light to build momentum.';
    case _EnergyZone.cruising:
      return 'Steady work is best; avoid unnecessary context switching.';
    case _EnergyZone.inTheZone:
      return 'Protect focus and go deep—mute notifications.';
    case _EnergyZone.peakPower:
      return 'Use this window for your hardest, highest-impact work.';
  }
}

_EnergyBand _bandFor(double energy, int hour) {
  final zone = _zoneFor(energy);
  final block = _timeBlockForHour(hour);
  final tip = _proTipsByBlock[block]?[zone] ?? _fallbackTip(zone);

  // Keep labels = energy zones, and keep your existing colors.
  switch (zone) {
    case _EnergyZone.runningOnFumes:
      return _EnergyBand(
        label: 'Running on fumes',
        recommendation: tip,
        color: const Color(0xFFE53935),
      );
    case _EnergyZone.warmingUp:
      return _EnergyBand(
        label: 'Warming up',
        recommendation: tip,
        color: const Color(0xFFFFA000),
      );
    case _EnergyZone.cruising:
      return _EnergyBand(
        label: 'Cruising',
        recommendation: tip,
        color: const Color(0xFFFFC107),
      );
    case _EnergyZone.inTheZone:
      return _EnergyBand(
        label: 'In the zone',
        recommendation: tip,
        color: const Color(0xFF43A047),
      );
    case _EnergyZone.peakPower:
      return _EnergyBand(
        label: 'Peak power',
        recommendation: tip,
        color: const Color(0xFF1B5E20),
      );
  }
}
