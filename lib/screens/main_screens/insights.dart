// lib/features/energy/screens/insights_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watt/features/auth/providers/providers.dart';

import 'package:watt/features/energy/models/energy_feedback.dart';
import 'package:watt/features/energy/models/sleep_quality.dart';
import 'package:watt/features/energy/providers/energy_providers.dart';

import 'package:watt/features/energy/widgets/compact_view_tiles.dart';
import 'package:watt/features/energy/widgets/tilesv2.dart';
import 'package:watt/features/firestore/providers/providers.dart';
import 'package:watt/utils/utils.dart';

enum InsightsView { detailed, compact }

/// 5-step sleep quality scale (history-friendly; stored as strings)

final sleepQualityDayProvider = StreamProvider.family
    .autoDispose<Map<String, dynamic>?, ({String uid, String epochDay})>((
      ref,
      args,
    ) {
      final repo = ref.read(firestoreRepositoryProvider);
      return repo.watchDocument(
        collectionPath: 'users/${args.uid}/sleepQualityDays',
        docId: args.epochDay,
      );
    });

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  InsightsView _view = InsightsView.detailed;

  // --- add state ---
  SleepQuality? _sleepQuality;
  bool _sleepExpanded = false;
  bool _sleepSubmitting = false;

  Future<void> _handleSleepSelected(SleepQuality q) async {
    if (_sleepSubmitting) return;

    setState(() {
      _sleepSubmitting = true;

      _sleepExpanded = false;

      _sleepQuality = q;
    });

    try {
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user == null) return;

      final today = await _todayByWakeBed(user.uid);
      if (today == null) return;

      final epochDay = customDateString(today); // yyyy-MM-dd

      await ref
          .read(firestoreRepositoryProvider)
          .saveDataInSubcollection(
            parentCollectionPath: 'users',
            parentDocId: user.uid,
            subcollectionPath: 'sleepQualityDays',
            subDocId: epochDay, // 1 doc per day
            merge: true,
            data: {
              'epochDay': epochDay,
              'sleepQuality': sleepQualityToString(q),
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );

      ref.invalidate(energyInsightsProvider);
    } catch (e) {
      // If you want: reopen on failure
      if (mounted) {
        setState(() {
          _sleepExpanded = true; // let them retry
          // optional: also revert _sleepQuality if you want pessimistic UI
        });
      }
    } finally {
      if (mounted) setState(() => _sleepSubmitting = false);
    }
  }

  Future<DateTime?> _todayByWakeBed(String uid) async {
    final profile = await ref.read(userProfileStreamProvider(uid).future);
    if (profile == null) return null;

    final wakeHour = profile['wakeHour'] as int?;
    final bedHour = profile['bedHour'] as int?;
    if (wakeHour == null || bedHour == null) return null;

    return dateWokeUp(wakeHour, bedHour);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final insightsAsync = ref.watch(energyInsightsProvider);
    final controller = ref.read(energyInsightsProvider.notifier);
    final user = ref.watch(firebaseAuthProvider).currentUser;

    DateTime? today;
    String? epochDay;

    if (user != null) {
      // you already have _todayByWakeBed
      // but it's async — so we use profile stream synchronously to get wake/bed
      final profileAsync = ref.watch(userProfileStreamProvider(user.uid));
      profileAsync.whenData((profile) {
        final wakeHour = profile?['wakeHour'] as int?;
        final bedHour = profile?['bedHour'] as int?;
        if (wakeHour != null && bedHour != null) {
          today = dateWokeUp(wakeHour, bedHour);
          epochDay = customDateString(today!);
        }
      });
    }
    if (user != null && epochDay != null) {
      final dayAsync = ref.watch(
        sleepQualityDayProvider((uid: user.uid, epochDay: epochDay!)),
      );

      dayAsync.whenData((day) {
        final raw = day?['sleepQuality'] as String?;
        final parsed = raw == null ? null : stringToSleepQuality(raw);

        if (mounted && parsed != null && _sleepQuality != parsed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _sleepQuality = parsed);
          });
        }
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row (title + toggle)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: _HeaderTitle(
                      title: "Today’s Energy Forecast",
                      subtitle: "What to tackle in each window",
                    ),
                  ),
                  _IconToggle(
                    view: _view,
                    onChanged: (v) => setState(() => _view = v),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // --- add the card here ---
              _SleepQualityCard(
                selected: _sleepQuality,
                submitting: _sleepSubmitting,
                expanded: _sleepExpanded,
                onToggle: () =>
                    setState(() => _sleepExpanded = !_sleepExpanded),
                onSelected: _handleSleepSelected,
              ),
              const SizedBox(height: 12),

              Expanded(
                child: insightsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (data) {
                    final points = data.points;

                    if (points.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            "No energy forecast available yet.",
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          switchInCurve: Curves.easeInOutCubic,
                          switchOutCurve: Curves.easeInOutCubic,
                          child: _view == InsightsView.detailed
                              ? EnergyTileList(
                                  key: const ValueKey('detailed'),
                                  entries: data.points,
                                  existingFeedbackMap: data.todayFeedback,
                                  density: EnergyTileDensity.compact,
                                  onSubmitFeedback:
                                      ({
                                        required int hour,
                                        required EnergyFeedback feedback,
                                        required double predictedEnergy,
                                      }) async {
                                        await controller.submitFeedback(
                                          hour: hour,
                                          feedback: feedback,
                                          predictedEnergy: predictedEnergy,
                                        );
                                      },
                                )
                              : CompactInsightsGrid(
                                  key: const ValueKey('compact'),
                                  points: data.points,
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// --- Title & Subtitle with proper layout ---
class _HeaderTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _HeaderTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w400,
                  fontSize: 12.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// --- Compact Inline Icon Toggle ---
class _IconToggle extends StatelessWidget {
  final InsightsView view;
  final ValueChanged<InsightsView> onChanged;
  const _IconToggle({required this.view, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const appBarColor = Color(0xFF354975);
    final cs = Theme.of(context).colorScheme;

    Widget circleButton({
      required IconData icon,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 28,
          width: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? appBarColor
                : cs.surfaceContainerHighest.withOpacity(0.2),
            border: selected
                ? null
                : Border.all(
                    color: cs.outlineVariant.withOpacity(0.4),
                    width: 1.0,
                  ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: appBarColor.withOpacity(0.4),
                      blurRadius: 5,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 15,
            color: selected ? Colors.white : cs.onSurface.withOpacity(0.8),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        circleButton(
          icon: Icons.view_list_rounded,
          selected: view == InsightsView.detailed,
          onTap: () => onChanged(InsightsView.detailed),
        ),
        const SizedBox(width: 6),
        circleButton(
          icon: Icons.grid_view_rounded,
          selected: view == InsightsView.compact,
          onTap: () => onChanged(InsightsView.compact),
        ),
      ],
    );
  }
}

class _SleepQualityCard extends StatelessWidget {
  final SleepQuality? selected;
  final bool submitting;
  final bool expanded;
  final VoidCallback onToggle;
  final Future<void> Function(SleepQuality) onSelected;

  const _SleepQualityCard({
    required this.selected,
    required this.submitting,
    required this.expanded,
    required this.onToggle,
    required this.onSelected,
  });

  String _label(SleepQuality q) {
    switch (q) {
      case SleepQuality.veryPoor:
        return "Very poor";
      case SleepQuality.poor:
        return "Poor";
      case SleepQuality.okay:
        return "Okay";
      case SleepQuality.good:
        return "Good";
      case SleepQuality.great:
        return "Great";
    }
  }

  String _emoji(SleepQuality q) {
    switch (q) {
      case SleepQuality.veryPoor:
        return "🥱";
      case SleepQuality.poor:
        return "😴";
      case SleepQuality.okay:
        return "😐";
      case SleepQuality.good:
        return "🙂";
      case SleepQuality.great:
        return "😊";
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgTop = Color(0xFF151A2D);
    const bgBottom = Color(0xFF0E1223);

    const border = Color(0xFF2D3556);
    const glow = Color(0xFF6E56FF);

    const textMain = Color(0xFFE8EAF3);
    const textMuted = Color(0xFF9AA3BF);

    final subtitle = selected == null
        ? "How did you sleep?"
        : "You rated: ${_label(selected!)} ${_emoji(selected!)}";

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border.withOpacity(0.85), width: 1),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bgTop, bgBottom],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: glow.withOpacity(0.22),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Inner wash
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.06),
                        Colors.transparent,
                        glow.withOpacity(0.05),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom glow line
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: IgnorePointer(
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        glow.withOpacity(0.55),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                children: [
                  // Header row
                  InkWell(
                    onTap: submitting ? null : onToggle,
                    borderRadius: BorderRadius.circular(14),
                    child: Row(
                      children: [
                        const _MoonChipSmall(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "LAST NIGHT'S SLEEP",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  letterSpacing: 0.7,
                                  color: textMain,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12.0,
                                  color: textMuted.withOpacity(0.95),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          turns: expanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: textMuted.withOpacity(0.95),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Dropdown
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        children: [
                          AbsorbPointer(
                            absorbing: submitting,
                            child: _DarkDropdownMenu(
                              selected: selected,
                              onPick: (q) async {
                                await onSelected(q);
                              },
                              label: _label,
                              emoji: _emoji,
                            ),
                          ),
                          if (submitting) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 3,
                                backgroundColor: Colors.white.withOpacity(0.08),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  glow.withOpacity(0.55),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    crossFadeState: expanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 180),
                    sizeCurve: Curves.easeOutCubic,
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

class _MoonChipSmall extends StatelessWidget {
  const _MoonChipSmall();

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFF2D3556);
    const glow = Color(0xFF6E56FF);
    const textMain = Color(0xFFE8EAF3);

    return Container(
      height: 30,
      width: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border.withOpacity(0.85), width: 1),
        color: Colors.white.withOpacity(0.04),
        boxShadow: [
          BoxShadow(
            color: glow.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.nightlight_round,
        size: 16,
        color: textMain.withOpacity(0.9),
      ),
    );
  }
}

/// Compact dropdown menu surface with 5 items (no big pills)
class _DarkDropdownMenu extends StatelessWidget {
  final SleepQuality? selected;
  final Future<void> Function(SleepQuality) onPick;
  final String Function(SleepQuality) label;
  final String Function(SleepQuality) emoji;

  const _DarkDropdownMenu({
    required this.selected,
    required this.onPick,
    required this.label,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFF2D3556);
    const glow = Color(0xFF6E56FF);
    const textMain = Color(0xFFE8EAF3);
    const textMuted = Color(0xFF9AA3BF);

    final items = SleepQuality.values;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border.withOpacity(0.85), width: 1),
        color: Colors.white.withOpacity(0.035),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _DarkDropdownItem(
              emoji: emoji(items[i]),
              text: label(items[i]),
              selected: selected == items[i],
              onTap: () => onPick(items[i]),
            ),
            if (i != items.length - 1)
              Divider(height: 1, thickness: 1, color: border.withOpacity(0.55)),
          ],
        ],
      ),
    );
  }
}

class _DarkDropdownItem extends StatelessWidget {
  final String emoji;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _DarkDropdownItem({
    required this.emoji,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const glow = Color(0xFF6E56FF);
    const textMain = Color(0xFFE8EAF3);
    const textMuted = Color(0xFF9AA3BF);

    final bg = selected ? glow.withOpacity(0.14) : Colors.transparent;
    final fg = selected
        ? textMain.withOpacity(0.95)
        : textMuted.withOpacity(0.95);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: fg,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: textMain.withOpacity(0.92),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
