import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peak_flow/features/energy/models/energy_feedback.dart';
import 'package:peak_flow/features/energy/models/energy_point.dart';


/// Controls tile size & spacing.
enum EnergyTileDensity { comfortable, compact }

const _kGreyscaleFilter = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
]);

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

/// ---------------------------------------------------------------------------
/// EnergyTileList (NEW API: no provider reads inside)
/// ---------------------------------------------------------------------------
class EnergyTileList extends ConsumerWidget {
  final List<EnergyPoint> entries;

  /// Feedback already persisted for today (hour -> record)
  final Map<int, EnergyFeedbackRecord> existingFeedbackMap;

  /// Called when user chooses feedback in sidebar
  final Future<void> Function({
    required int hour,
    required EnergyFeedback feedback,
    required double predictedEnergy,
  }) onSubmitFeedback;

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

        final bool shouldShowFeedbackBar =
            (i < cutIndex) && (savedFeedback == null);

        return _EnergyTileWithFeedbackShell(
          hour: point.hour,
          energy: point.energy,
          density: density,
          existingFeedback: savedFeedback,
          showFeedbackBarInitially: shouldShowFeedbackBar,
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

/// Shell that shows sidebar only when needed (keeps your behavior)
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
  late bool _showSidebar;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _showSidebar =
        widget.showFeedbackBarInitially && widget.existingFeedback == null;
  }

  @override
  void didUpdateWidget(covariant _EnergyTileWithFeedbackShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    final had = oldWidget.existingFeedback != null;
    final has = widget.existingFeedback != null;

    if (had != has) {
      _showSidebar =
          widget.showFeedbackBarInitially && widget.existingFeedback == null;
      if (has) _saving = false;
      setState(() {});
    }
  }

  Future<void> _handleSidebarTap(EnergyFeedback fb) async {
    if (_saving) return;

    setState(() {
      _saving = true;
      _showSidebar = false;
    });

    try {
      await widget.onSidebarFeedback(fb);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.density == EnergyTileDensity.compact;
    final double sidebarWidth = compact ? 44.0 : 52.0;
    final double sidebarGap = compact ? 8.0 : 10.0;

    if (!_showSidebar) {
      return EnergyTile(
        hour: widget.hour,
        energy: widget.energy,
        density: widget.density,
        submittedFeedback: widget.existingFeedback,
        expandForSidebar: false,
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: EnergyTile(
              hour: widget.hour,
              energy: widget.energy,
              density: widget.density,
              submittedFeedback: null,
              expandForSidebar: true,
            ),
          ),
          SizedBox(width: sidebarGap),
          SizedBox(
            width: sidebarWidth,
            child: AbsorbPointer(
              absorbing: _saving,
              child: Opacity(
                opacity: _saving ? 0.6 : 1.0,
                child:  _FeedbackColumn(
  density: widget.density,
  onSelect: _handleSidebarTap,
),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------- KEEP your existing EnergyTile / _FeedbackColumn etc -----------------
// Everything below can remain exactly as you already have it (EnergyTile, _FeedbackColumn,
// _iconForFeedback, _colorForFeedback, band logic, etc).
//
// Just ensure those classes/functions are still in this file or imported properly.


bool _shouldGrayOut(EnergyFeedback? fb) =>
    fb != null && fb != EnergyFeedback.match;

class EnergyTile extends StatelessWidget {
  final int hour;
  final double energy;
  final EnergyTileDensity density;

  final EnergyFeedback? submittedFeedback;
  final bool expandForSidebar;

  const EnergyTile({
    super.key,
    required this.hour,
    required this.energy,
    required this.density,
    this.submittedFeedback,
    this.expandForSidebar = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final band = _bandFor(energy);

    final tileBg = band.color;
    final onTile = _onColorFor(tileBg);

    const offWhite = Color(0xFFF8F9FB);
    final pillBg = offWhite;
    final pillFg = tileBg;
    final barTrack = offWhite.withOpacity(0.55);
    final barFill = offWhite;

    final compact = density == EnergyTileDensity.compact;

    final tileRadius = compact ? 12.0 : 16.0;
    final tilePad = compact
        ? const EdgeInsets.fromLTRB(10, 6, 10, 6)
        : const EdgeInsets.fromLTRB(14, 12, 14, 12);
    final recPad = compact
        ? const EdgeInsets.fromLTRB(8, 10, 8, 16)
        : const EdgeInsets.fromLTRB(8, 18, 8, 40);
    final recStyle = (compact ? theme.textTheme.bodyMedium : theme.textTheme.bodyLarge)
        ?.copyWith(height: 1.2, fontWeight: FontWeight.w600, color: onTile);

    final barWidth = compact ? 56.0 : 84.0;
    final barHeight = compact ? 6.0 : 10.0;
    final hourIconSize = compact ? 12.0 : 16.0;
    final chipHPad = compact ? 6.0 : 10.0;
    final chipVPad = compact ? 3.0 : 6.0;
    final pillHPad = compact ? 6.0 : 10.0;
    final pillVPad = compact ? 3.0 : 6.0;
    final pillFont = compact ? 11.0 : 14.0;
    final bandSpacing = compact ? 3.0 : 6.0;

    final bottomConfirmPad = compact
        ? const EdgeInsets.only(top: 4, left: 8, right: 8, bottom: 4)
        : const EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 8);

    final mainAxisSize = expandForSidebar ? MainAxisSize.max : MainAxisSize.min;
    final mainAxisAlignment =
        expandForSidebar ? MainAxisAlignment.center : MainAxisAlignment.start;

    final bool isCompleted = submittedFeedback != null;

    Widget core = Material(
      color: tileBg,
      elevation: compact ? 1 : 2,
      shadowColor: Colors.black.withOpacity(0.12),
      borderRadius: BorderRadius.circular(tileRadius),
      child: Container(
        padding: tilePad,
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(tileRadius),
          border: Border.all(color: onTile.withOpacity(0.12)),
        ),
        child: Column(
          mainAxisSize: mainAxisSize,
          mainAxisAlignment: mainAxisAlignment,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HourChip(
                  text: "$hour o'clock",
                  iconSize: hourIconSize,
                  padding: EdgeInsets.symmetric(
                    horizontal: chipHPad,
                    vertical: chipVPad,
                  ),
                  textColor: onTile,
                  iconColor: onTile,
                  borderColor: onTile.withOpacity(0.22),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _BandPill(
                      text: band.label,
                      bgColor: pillBg,
                      textStyle: TextStyle(
                        color: pillFg,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.15,
                        fontSize: pillFont,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: pillHPad,
                        vertical: pillVPad,
                      ),
                    ),
                    SizedBox(height: bandSpacing),
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

            SizedBox(height: expandForSidebar ? 35 : 8),

            Padding(
              padding: recPad,
              child: Text(
                band.recommendation,
                textAlign: TextAlign.center,
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: recStyle,
              ),
            ),

            if (submittedFeedback != null)
              Padding(
                padding: bottomConfirmPad,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        "Your feedback:",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: onTile.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _iconForFeedback(submittedFeedback!),
                      size: compact ? 16 : 18,
                      color: Colors.white,
                    ),
                  ],
                ),
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
                  color: Colors.white.withOpacity(0.12),
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
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: iconSize, color: iconColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
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
        borderRadius: BorderRadius.circular(8),
        color: trackColor,
      ),
      clipBehavior: Clip.hardEdge,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(color: fillColor),
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

class _FeedbackColumn extends StatelessWidget {
  final void Function(EnergyFeedback fb) onSelect;
  final EnergyTileDensity density;

  const _FeedbackColumn({
    required this.onSelect,
    required this.density,
  });

  @override
  Widget build(BuildContext context) {
    final compact = density == EnergyTileDensity.compact;
    final buttonSize = compact ? 32.0 : 36.0;
    final iconSize = compact ? 16.0 : 18.0;
    const gap = 4.0;

    Widget btn(EnergyFeedback fb) => _FeedbackCircleButton(
          size: buttonSize,
          iconSize: iconSize,
          icon: _iconForFeedback(fb),
          iconColor: _colorForFeedback(fb),
          onTap: () => onSelect(fb),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(EnergyFeedback.muchHigher),
        const SizedBox(height: gap),
        btn(EnergyFeedback.higher),
        const SizedBox(height: gap),
        btn(EnergyFeedback.match),
        const SizedBox(height: gap),
        btn(EnergyFeedback.lower),
        const SizedBox(height: gap),
        btn(EnergyFeedback.muchLower),
      ],
    );
  }
}

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

class _FeedbackCircleButton extends StatelessWidget {
  final double size;
  final double iconSize;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _FeedbackCircleButton({
    required this.size,
    required this.iconSize,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = Colors.black.withOpacity(0.08);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Center(child: Icon(icon, size: iconSize, color: iconColor)),
      ),
    );
  }
}

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

_EnergyBand _bandFor(double energy) {
  final e = energy.clamp(0, 100);
  if (e <= 20) {
    return const _EnergyBand(
      label: 'Running on fumes',
      recommendation: 'Gentle tasks only. Protect your focus and recharge briefly.',
      color: Color(0xFFE53935),
    );
  } else if (e <= 40) {
    return const _EnergyBand(
      label: 'Warming up',
      recommendation: 'Do light planning or admin. A short walk can boost you.',
      color: Color(0xFFFFA000),
    );
  } else if (e <= 60) {
    return const _EnergyBand(
      label: 'Cruising',
      recommendation: 'Tackle steady work. Avoid context switching to keep pace.',
      color: Color(0xFFFFC107),
    );
  } else if (e <= 80) {
    return const _EnergyBand(
      label: 'In the zone',
      recommendation: 'Great window for deep work. Silence notifications and dive in.',
      color: Color(0xFF43A047),
    );
  } else {
    return const _EnergyBand(
      label: 'Peak power',
      recommendation: 'This is your prime time — ship the hardest thing now.',
      color: Color(0xFF1B5E20),
    );
  }
}

Color _onColorFor(Color bg) =>
    bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
