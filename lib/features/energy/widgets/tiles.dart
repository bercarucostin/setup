import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watt/features/energy/models/energy_feedback.dart';
import 'package:watt/features/energy/models/energy_point.dart';

/// Controls tile size & spacing.
enum EnergyTileDensity { comfortable, compact }

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
                child: _FeedbackColumn(
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
    final band = _bandFor(energy, hour);

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
    final recStyle =
        (compact ? theme.textTheme.bodyMedium : theme.textTheme.bodyLarge)
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
    final mainAxisAlignment = expandForSidebar
        ? MainAxisAlignment.center
        : MainAxisAlignment.start;

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
                  text: "$hour:00",
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
                maxLines: compact ? 3 : 4,
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

  const _FeedbackColumn({required this.onSelect, required this.density});

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
        child: Center(
          child: Icon(icon, size: iconSize, color: iconColor),
        ),
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

Color _onColorFor(Color bg) =>
    bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
