import 'dart:ui' show FontFeature, ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:setup/features/energy/models/energy_point.dart';
import 'package:setup/features/energy/models/energy_feedback.dart'
    as feedback_model;
import 'package:setup/features/energy/models/energy_feedback.dart'
    show EnergyFeedbackRecord;
import 'package:setup/features/auth/providers/providers.dart';
import 'package:setup/features/energy/providers/energy_provider.dart';
import 'package:setup/features/energy/repository/energy_repository.dart';

/// Controls tile size & spacing.
enum EnergyTileDensity { comfortable, compact }

String _feedbackDebugDescription(feedback_model.EnergyFeedback fb) {
  switch (fb) {
    case feedback_model.EnergyFeedback.muchHigher:
      return "My energy was far higher";
    case feedback_model.EnergyFeedback.higher:
      return "My energy was slightly higher";
    case feedback_model.EnergyFeedback.match:
      return "Suggested energy was perfect";
    case feedback_model.EnergyFeedback.lower:
      return "My energy was slightly lower";
    case feedback_model.EnergyFeedback.muchLower:
      return "My energy was far lower";
  }
}

/// ---------------------------------------------------------------------------
/// EnergyTileList (ConsumerWidget so we can watch providers)
/// ---------------------------------------------------------------------------
class EnergyTileList extends ConsumerWidget {
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
    this.density = EnergyTileDensity.compact,
    this.listPadding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowHour = fromHourOverride ?? DateTime.now().hour;

    // 1. read today's saved feedback map from provider
    final todayFeedbackAsync = ref.watch(todayFeedbackMapProvider);
    // We'll unwrap it inside the builder below so UI still renders if loading.

    // 2. sort and filter entries like before
    final sorted = [...entries]..sort((a, b) => a.hour.compareTo(b.hour));
    final visibleList =
        upcomingOnly
            ? sorted.where((e) => e.hour > nowHour - 2).toList()
            : sorted;

    final padding = listPadding ?? const EdgeInsets.fromLTRB(12, 12, 12, 72);

    if (visibleList.isEmpty) {
      return const _EmptyState(
        message: "Good night! Check back tomorrow for your energy prediction!",
      );
    }

    final itemGap = density == EnergyTileDensity.compact ? 6.0 : 10.0;

    // We'll also need the repo + userId for saving feedback
    final energyRepo = ref.read(energyRepositoryProvider);

    final userAsync = ref.watch(signedInUserProvider);
    final String? userId = userAsync.maybeWhen(
      data: (u) => u?.uid,
      orElse: () => null,
    );

    return todayFeedbackAsync.when(
      loading: () {
        // We STILL render list with no pre-filled feedback while loading,
        // so UI doesn't block.
        final emptyMap = <int, EnergyFeedbackRecord>{};
        return _buildListView(
          visibleList: visibleList,
          nowHour: nowHour,
          density: density,
          padding: padding,
          itemGap: itemGap,
          userId: userId,
          energyRepo: energyRepo,
          existingFeedbackMap: emptyMap,
        );
      },
      error: (err, stack) {
        // On error we just behave like no feedback saved.
        final emptyMap = <int, EnergyFeedbackRecord>{};
        return _buildListView(
          visibleList: visibleList,
          nowHour: nowHour,
          density: density,
          padding: padding,
          itemGap: itemGap,
          userId: userId,
          energyRepo: energyRepo,
          existingFeedbackMap: emptyMap,
        );
      },
      data: (feedbackMap) {
        return _buildListView(
          visibleList: visibleList,
          nowHour: nowHour,
          density: density,
          padding: padding,
          itemGap: itemGap,
          userId: userId,
          energyRepo: energyRepo,
          existingFeedbackMap: feedbackMap,
        );
      },
    );
  }

  Widget _buildListView({
    required List<EnergyPoint> visibleList,
    required int nowHour,
    required EnergyTileDensity density,
    required EdgeInsetsGeometry padding,
    required double itemGap,
    required String? userId,
    required EnergyRepository energyRepo,
    required Map<int, EnergyFeedbackRecord> existingFeedbackMap,
  }) {
    return ListView.separated(
      padding: padding,
      itemCount: visibleList.length,
      separatorBuilder: (_, __) => SizedBox(height: itemGap),
      itemBuilder: (context, i) {
        final point = visibleList[i];

        // did we already submit feedback for this hour today?
        final existingRecord = existingFeedbackMap[point.hour];
        final feedbackAlreadyGiven = existingRecord?.feedback;

        // we only want the sidebar if:
        // - this hour is "past or now"
        // - and we DO NOT already have feedback
        final bool shouldShowFeedbackBar =
            (point.hour <= nowHour) && (feedbackAlreadyGiven == null);

        return _EnergyTileWithFeedbackShell(
          hour: point.hour,
          energy: point.energy,
          density: density,

          // NEW: pass pre-existing feedback from Firestore if any
          existingFeedback: feedbackAlreadyGiven,

          showFeedbackBarInitially: shouldShowFeedbackBar,
          onConfirm: null,
          onReject: null,

          onSidebarFeedback: (fb) async {
            final readable = _feedbackDebugDescription(fb);
            debugPrint(
              "Feedback for hour ${point.hour}: $readable ($fb) / energy=${point.energy}",
            );

            if (userId == null) {
              debugPrint('Skipping saveUserEnergyFeedback: no signed-in user.');
              return;
            }

            final record = EnergyFeedbackRecord(
              hour: point.hour,
              feedback: fb,
              predictedEnergy: point.energy,
            );

            await energyRepo.saveUserEnergyFeedback(
              userId: userId,
              record: record,
            );
          },
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

/// ---------------------------------------------------------------------------
/// _EnergyTileWithFeedbackShell
/// ---------------------------------------------------------------------------
///
/// Now takes `existingFeedback`.
/// - If we already have feedback for that hour from Firestore:
///    - we start with _selectedFeedback = that value
///    - we hide the sidebar straight away
///
class _EnergyTileWithFeedbackShell extends StatefulWidget {
  final int hour;
  final double energy;
  final EnergyTileDensity density;

  final bool showFeedbackBarInitially;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;

  final Future<void> Function(feedback_model.EnergyFeedback fb)?
  onSidebarFeedback;

  /// NEW: feedback that was already saved in Firestore for this hour
  final feedback_model.EnergyFeedback? existingFeedback;

  const _EnergyTileWithFeedbackShell({
    required this.hour,
    required this.energy,
    required this.density,
    required this.showFeedbackBarInitially,
    required this.onConfirm,
    required this.onReject,
    this.onSidebarFeedback,
    this.existingFeedback,
  });

  @override
  State<_EnergyTileWithFeedbackShell> createState() =>
      _EnergyTileWithFeedbackShellState();
}

class _EnergyTileWithFeedbackShellState
    extends State<_EnergyTileWithFeedbackShell> {
  feedback_model.EnergyFeedback? _selectedFeedback;
  late bool _showSidebar;

  @override
  void initState() {
    super.initState();

    // If we already had feedback from Firestore, preload it.
    _selectedFeedback = widget.existingFeedback;

    // Show sidebar only if allowed AND we don't already have feedback.
    _showSidebar =
        widget.showFeedbackBarInitially && widget.existingFeedback == null;
  }

  Future<void> _handleSidebarTap(feedback_model.EnergyFeedback fb) async {
    // optimistic UI
    setState(() {
      _selectedFeedback = fb;
      _showSidebar = false;
    });

    // persist through callback (which hits Firestore in parent list)
    if (widget.onSidebarFeedback != null) {
      await widget.onSidebarFeedback!(fb);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.density == EnergyTileDensity.compact;
    final double sidebarWidth = compact ? 44.0 : 52.0;
    final double sidebarGap = compact ? 8.0 : 10.0;

    // If sidebar is hidden right now (either future hour, or after submit,
    // or because we loaded previous feedback), just render the tile.
    if (!_showSidebar) {
      return EnergyTile(
        hour: widget.hour,
        energy: widget.energy,
        density: widget.density,
        onConfirm: widget.onConfirm,
        onReject: widget.onReject,
        submittedFeedback: _selectedFeedback,
        expandForSidebar: false,
      );
    }

    // Sidebar visible (no previous feedback yet, and it's a past/now hour)
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: EnergyTile(
              hour: widget.hour,
              energy: widget.energy,
              density: widget.density,
              onConfirm: widget.onConfirm,
              onReject: widget.onReject,
              submittedFeedback: null,
              expandForSidebar: true,
            ),
          ),
          SizedBox(width: sidebarGap),
          SizedBox(
            width: sidebarWidth,
            child: _FeedbackColumn(
              density: widget.density,
              selected: null,
              onSelect: _handleSidebarTap,
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// EnergyTile
/// ---------------------------------------------------------------------------
class EnergyTile extends StatelessWidget {
  final int hour; // "7 o'clock"
  final double energy; // 0..100
  final EnergyTileDensity density;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;

  final feedback_model.EnergyFeedback? submittedFeedback;
  final bool expandForSidebar;

  const EnergyTile({
    super.key,
    required this.hour,
    required this.energy,
    required this.density,
    this.onConfirm,
    this.onReject,
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
    final bandSpacing = compact ? 3.0 : 6.0;

    final bottomConfirmPad =
        compact
            ? const EdgeInsets.only(top: 4, left: 8, right: 8, bottom: 4)
            : const EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 8);

    // When sidebar is visible, fill height but center contents vertically
    final mainAxisSize = expandForSidebar ? MainAxisSize.max : MainAxisSize.min;
    final mainAxisAlignment =
        expandForSidebar ? MainAxisAlignment.center : MainAxisAlignment.start;

    return Material(
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
            // header section
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

            SizedBox(height: expandForSidebar ? 35 : 8),
            // recommendation text
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

            // feedback confirmation row (if feedback exists, either freshly tapped or loaded from Firestore)
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
                        softWrap: true,
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
  }
}

/// --- UI atoms (unchanged) ----

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

/// Sidebar with feedback buttons (unchanged except for using feedback_model)
class _FeedbackColumn extends StatelessWidget {
  final feedback_model.EnergyFeedback? selected;
  final void Function(feedback_model.EnergyFeedback fb) onSelect;
  final EnergyTileDensity density;

  const _FeedbackColumn({
    required this.selected,
    required this.onSelect,
    required this.density,
  });

  @override
  Widget build(BuildContext context) {
    final compact = density == EnergyTileDensity.compact;
    final buttonSize = compact ? 32.0 : 36.0;
    final iconSize = compact ? 16.0 : 18.0;
    final gap = 4.0;

    Widget makeBtn(feedback_model.EnergyFeedback fb) {
      return _FeedbackCircleButton(
        size: buttonSize,
        iconSize: iconSize,
        icon: _iconForFeedback(fb),
        iconColor: _colorForFeedback(fb),
        isSelected: false,
        onTap: () => onSelect(fb),
      );
    }

    if (selected != null) {
      final fb = selected!;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FeedbackCircleButton(
            size: buttonSize,
            iconSize: iconSize,
            icon: _iconForFeedback(fb),
            iconColor: _colorForFeedback(fb),
            isSelected: true,
            onTap: () {},
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        makeBtn(feedback_model.EnergyFeedback.muchHigher),
        SizedBox(height: gap),
        makeBtn(feedback_model.EnergyFeedback.higher),
        SizedBox(height: gap),
        makeBtn(feedback_model.EnergyFeedback.match),
        SizedBox(height: gap),
        makeBtn(feedback_model.EnergyFeedback.lower),
        SizedBox(height: gap),
        makeBtn(feedback_model.EnergyFeedback.muchLower),
      ],
    );
  }
}

IconData _iconForFeedback(feedback_model.EnergyFeedback fb) {
  switch (fb) {
    case feedback_model.EnergyFeedback.muchHigher:
      return Icons.keyboard_double_arrow_up_rounded;
    case feedback_model.EnergyFeedback.higher:
      return Icons.keyboard_arrow_up_rounded;
    case feedback_model.EnergyFeedback.match:
      return Icons.check_rounded;
    case feedback_model.EnergyFeedback.lower:
      return Icons.keyboard_arrow_down_rounded;
    case feedback_model.EnergyFeedback.muchLower:
      return Icons.keyboard_double_arrow_down_rounded;
  }
}

Color _colorForFeedback(feedback_model.EnergyFeedback fb) {
  switch (fb) {
    case feedback_model.EnergyFeedback.muchHigher:
      return const Color(0xFFE53935); // red
    case feedback_model.EnergyFeedback.higher:
      return const Color(0xFFFFA000); // amber
    case feedback_model.EnergyFeedback.match:
      return const Color(0xFF43A047); // green
    case feedback_model.EnergyFeedback.lower:
      return const Color(0xFFFFA000); // amber
    case feedback_model.EnergyFeedback.muchLower:
      return const Color(0xFFE53935); // red
  }
}

class _FeedbackCircleButton extends StatelessWidget {
  final double size;
  final double iconSize;
  final IconData icon;
  final Color iconColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _FeedbackCircleButton({
    required this.size,
    required this.iconSize,
    required this.icon,
    required this.iconColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isSelected
            ? Colors.black.withOpacity(0.2)
            : Colors.black.withOpacity(0.08);

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
  return bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
}

Color _adjustForContrast(Color iconColor, Color tileBg) {
  // Compute brightness difference
  final iconLum = iconColor.computeLuminance();
  final bgLum = tileBg.computeLuminance();
  final diff = (iconLum - bgLum).abs();

  // If too similar, use a neutral color for contrast
  if (diff < 0.25) {
    return bgLum > 0.5 ? Colors.black87 : Colors.white;
  }
  return iconColor;
}

/// --- extras from before ----
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
