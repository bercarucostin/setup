import 'dart:ui' show FontFeature, ImageFilter;
import 'package:flutter/material.dart';
import 'package:setup/features/energy/models/energy_point.dart';

/// Controls tile size & spacing.
enum EnergyTileDensity { comfortable, compact }

class EnergyTileList extends StatelessWidget {
  final List<EnergyPoint> entries;
  final void Function(EnergyPoint entry)? onConfirm;
  final void Function(EnergyPoint entry)? onReject;

  final EdgeInsetsGeometry? listPadding;

  /// If true, only show tiles with hour > current device hour.
  final bool upcomingOnly;

  /// Override the starting hour (for testing or different logic).
  /// If null, uses DateTime.now().hour
  final int? fromHourOverride;

  /// Controls tile size & spacing. Default is compact for small tiles.
  final EnergyTileDensity density;

  const EnergyTileList({
    super.key,
    required this.entries,
    this.onConfirm,
    this.onReject,
    this.upcomingOnly = false,
    this.fromHourOverride,
    this.density = EnergyTileDensity.compact, // 👈 default to compact
    this.listPadding,
  });

  @override
  Widget build(BuildContext context) {
    final nowHour = fromHourOverride ?? DateTime.now().hour;

    final sorted = [...entries]..sort((a, b) => a.hour.compareTo(b.hour));
    final list =
        upcomingOnly
            ? sorted.where((e) => e.hour > nowHour - 2).toList()
            : sorted;

    final padding = listPadding ?? const EdgeInsets.fromLTRB(12, 12, 12, 72); //

    if (list.isEmpty) {
      return const _EmptyState(
        message: "Good night! Check back tomorrow for your energy prediction!",
      );
    }

    final itemGap = density == EnergyTileDensity.compact ? 6.0 : 10.0;

    return ListView.separated(
      padding: padding,
      itemCount: list.length,
      separatorBuilder: (_, __) => SizedBox(height: itemGap),
      itemBuilder: (context, i) {
        final e = list[i];
        return EnergyTile(
          hour: e.hour,
          energy: e.energy,
          density: density,
          onConfirm: onConfirm == null ? null : () => onConfirm!(e),
          onReject: onReject == null ? null : () => onReject!(e),
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
            height: 1.4, // nicer line spacing
          ),
        ),
      ),
    );
  }
}

class EnergyTile extends StatelessWidget {
  final int hour; // 7 -> "7 o'clock"
  final double energy; // 0..100
  final EnergyTileDensity density;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;

  const EnergyTile({
    super.key,
    required this.hour,
    required this.energy,
    required this.density,
    this.onConfirm,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final band = _bandFor(energy);

    // Inverted color scheme
    final tileBg = band.color; // tile background = band color
    final onTile = _onColorFor(tileBg); // readable text/icon on tile

    // Soft off-white for pill + bar
    const offWhite = Color(0xFFF8F9FB);
    final pillBg = offWhite;
    final pillFg = tileBg;
    final barTrack = offWhite.withOpacity(0.55);
    final barFill = offWhite;

    final compact = density == EnergyTileDensity.compact;

    // Density-based metrics
    final tileRadius = compact ? 12.0 : 16.0;
    final tilePad =
        compact
            ? const EdgeInsets.fromLTRB(10, 6, 10, 6)
            : const EdgeInsets.fromLTRB(14, 12, 14, 12);
    final recPad =
        compact
            ? const EdgeInsets.fromLTRB(8, 10, 8, 16)
            : const EdgeInsets.fromLTRB(8, 18, 8, 40);
    final recStyle = (compact
            ? theme.textTheme.bodyMedium
            : theme.textTheme.bodyLarge)
        ?.copyWith(height: 1.2, fontWeight: FontWeight.w600, color: onTile);

    final barWidth = compact ? 56.0 : 84.0;
    final barHeight = compact ? 6.0 : 10.0;
    final hourIconSize = compact ? 12.0 : 16.0;
    final chipHPad = compact ? 6.0 : 10.0;
    final chipVPad = compact ? 3.0 : 6.0;
    final pillHPad = compact ? 6.0 : 10.0;
    final pillVPad = compact ? 3.0 : 6.0;
    final pillFont = compact ? 11.0 : 14.0;
    final feedbackPad = compact ? 6.0 : 10.0;
    final bandSpacing = compact ? 3.0 : 6.0;

    return Material(
      color: tileBg,
      elevation: compact ? 1 : 2, // lighter lift in compact
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
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: hour (left) | classification pill + bar (right, stacked)
            Row(
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
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                      // subtle shadow to float on colored tile
                      shadow: BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: compact ? 6 : 10,
                        offset: const Offset(0, 2),
                      ),
                    ),
                    SizedBox(height: bandSpacing),
                    _MiniEnergyBar(
                      value: (energy.clamp(0, 100)) / 100.0,
                      width: barWidth,
                      height: barHeight,
                      trackColor: barTrack,
                      fillColor: barFill,
                      // subtle shadow for the bar
                      shadow: BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: compact ? 5 : 8,
                        offset: const Offset(0, 2),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Center recommendation (auto from band)
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

            // Bottom-right icon-only feedback
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _FeedbackIconButton(
                  icon: Icons.thumb_up_alt_rounded,
                  onTap: onConfirm,
                  iconSize: compact ? 16 : 20,
                  padAll: feedbackPad,
                  bgColor: onTile.withOpacity(0.20),
                  iconColor: onTile,
                ),
                const SizedBox(width: 6),
                _FeedbackIconButton(
                  icon: Icons.thumb_down_alt_rounded,
                  onTap: onReject,
                  iconSize: compact ? 16 : 20,
                  padAll: feedbackPad,
                  bgColor: onTile.withOpacity(0.12),
                  iconColor: onTile,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// --- UI bits ----

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
  final double value; // 0..1
  final double width;
  final double height;
  final Color trackColor;
  final Color fillColor;
  final BoxShadow? shadow;

  const _MiniEnergyBar({
    required this.value,
    required this.width,
    required this.height,
    required this.trackColor,
    required this.fillColor,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: trackColor,
        boxShadow: shadow == null ? null : [shadow!],
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
  final BoxShadow? shadow;

  const _BandPill({
    required this.text,
    required this.bgColor,
    required this.textStyle,
    required this.padding,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        boxShadow: shadow == null ? null : [shadow!],
      ),
      child: Text(text, style: textStyle),
    );
  }
}

class _FeedbackIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double iconSize;
  final double padAll;
  final Color bgColor;
  final Color iconColor;

  const _FeedbackIconButton({
    required this.icon,
    this.onTap,
    this.iconSize = 20,
    this.padAll = 10,
    required this.bgColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: EdgeInsets.all(padAll),
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

_EnergyBand _bandFor(double energy) {
  final e = energy.clamp(0, 100);
  if (e <= 20) {
    return const _EnergyBand(
      label: 'Running on fumes',
      recommendation:
          'Gentle tasks only. Protect your focus and recharge briefly.',
      color: Color(0xFFE53935), // red
    );
  } else if (e <= 40) {
    return const _EnergyBand(
      label: 'Warming up',
      recommendation: 'Do light planning or admin. A short walk can boost you.',
      color: Color(0xFFFFA000), // amber
    );
  } else if (e <= 60) {
    return const _EnergyBand(
      label: 'Cruising',
      recommendation:
          'Tackle steady work. Avoid context switching to keep pace.',
      color: Color(0xFFFFC107), // yellow
    );
  } else if (e <= 80) {
    return const _EnergyBand(
      label: 'In the zone',
      recommendation:
          'Great window for deep work. Silence notifications and dive in.',
      color: Color(0xFF43A047), // green
    );
  } else {
    return const _EnergyBand(
      label: 'Peak power',
      recommendation: 'This is your prime time — ship the hardest thing now.',
      color: Color(0xFF1B5E20), // dark green
    );
  }
}

/// Pick readable text color for a given background.
Color _onColorFor(Color bg) {
  // Light backgrounds -> dark text, dark backgrounds -> light text
  return bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
}

class NoGlowBehavior extends ScrollBehavior {
  const NoGlowBehavior();
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

class ListBottomFade extends StatelessWidget {
  final double height;
  const ListBottomFade({super.key, this.height = 64});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: height + MediaQuery.of(context).padding.bottom,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [bg.withOpacity(0.0), bg],
            ),
          ),
        ),
      ),
    );
  }
}

class EndCapPill extends StatelessWidget {
  final String text;
  const EndCapPill({super.key, this.text = "That’s all for today"});

  @override
  Widget build(BuildContext context) {
    final onBg = Theme.of(context).colorScheme.onSurface.withOpacity(0.8);
    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, size: 16, color: onBg),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(color: onBg, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BottomBlurScrim extends StatelessWidget {
  final double height;
  const BottomBlurScrim({super.key, this.height = 72});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 0, sigmaY: 10),
            child: Container(
              height: height + MediaQuery.of(context).padding.bottom,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [bg.withOpacity(0.0), bg.withOpacity(0.85), bg],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
