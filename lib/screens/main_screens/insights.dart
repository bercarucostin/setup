// lib/features/energy/screens/insights_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watt/features/auth/providers/providers.dart';

import 'package:watt/features/energy/models/energy_feedback.dart';
import 'package:watt/features/energy/providers/energy_providers.dart';

// Widgets:
import 'package:watt/features/energy/widgets/compact_view_tiles.dart';
import 'package:intl/intl.dart';
import 'package:watt/features/energy/widgets/tilesv2.dart';
import 'package:watt/features/firestore/providers/providers.dart';
import 'package:watt/utils/utils.dart';

enum InsightsView { detailed, compact }

enum SleepQuality { poor, okay, great }

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

    final prev = _sleepQuality;

    setState(() => _sleepSubmitting = true);

    try {
      // Persist to user doc (merge: true), same pattern as chronotype.
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user == null) return;

      final today = await _todayByWakeBed(user.uid);
      if (today == null) {
        // silent: wake/bed not configured (or profile missing)
        // (optional fallback if you prefer)
        // final fallbackDate = customDateString(DateTime.now());
        return;
      }

      final localDate = customDateString(today);

      await _mergeSleepCheckInData({
        'sleepQuality': q.name, // "poor" | "okay" | "great"
        'sleepQualityLocalDate': localDate,
        'sleepQualityUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Commit UI state only after persistence succeeded
      if (!mounted) return;
      setState(() {
        _sleepQuality = q;
        _sleepExpanded = false;
      });

      // Refresh insights if they depend on this
      ref.invalidate(energyInsightsProvider);
    } catch (e) {
      if (!mounted) return;

      // revert selection if you had any local optimistic state
      setState(() => _sleepQuality = prev);

      // Keep expanded so user can retry
    } finally {
      if (mounted) setState(() => _sleepSubmitting = false);
    }
  }

  Future<void> _mergeSleepCheckInData(Map<String, dynamic> data) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    await ref
        .read(firestoreRepositoryProvider)
        .saveData(
          collectionPath: 'users',
          docId: user.uid,
          data: data,
          merge: true,
        );
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

    if (user != null) {
      final profileAsync = ref.watch(userProfileStreamProvider(user.uid));

      profileAsync.whenData((profile) {
        final s = profile?['sleepQuality'] as String?;
        final parsed = switch (s) {
          'poor' => SleepQuality.poor,
          'okay' => SleepQuality.okay,
          'great' => SleepQuality.great,
          _ => null,
        };

        // Avoid setState loops: only set when it changes and when local is null
        if (_sleepQuality == null && parsed != null && mounted) {
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
            color: selected ? appBarColor : cs.surfaceVariant.withOpacity(0.2),
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

/// ---- New colorful card (Option C: neutral card, semantic pills) ----
// ---- Sleep card (dark, "LAST NIGHT'S SLEEP" style) ----
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
      case SleepQuality.poor:
        return "Poor";
      case SleepQuality.okay:
        return "Okay";
      case SleepQuality.great:
        return "Great";
    }
  }

  String _emoji(SleepQuality q) {
    switch (q) {
      case SleepQuality.poor:
        return "😴";
      case SleepQuality.okay:
        return "😐";
      case SleepQuality.great:
        return "😊";
    }
  }

  @override
  Widget build(BuildContext context) {
    // Palette tuned to resemble your screenshot
    const bgTop = Color(0xFF151A2D);
    const bgBottom = Color(0xFF0E1223);

    const border = Color(0xFF2D3556);
    const glow = Color(0xFF6E56FF); // subtle purple glow
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
          // soft lift
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
          // purple glow
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
            // subtle inner highlight wash
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

            // bottom "glow line" like the screenshot
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
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                children: [
                  InkWell(
                    onTap: submitting ? null : onToggle,
                    borderRadius: BorderRadius.circular(14),
                    child: Row(
                      children: [
                        const _MoonChip(), // now smaller (see below)
                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "LAST NIGHT'S SLEEP",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14, // smaller
                                  letterSpacing: 0.7,
                                  color: Color(0xFFE8EAF3),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                selected == null
                                    ? "How did you sleep?"
                                    : "You rated: ${_label(selected!)} ${_emoji(selected!)}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12.2, // smaller
                                  color: const Color(
                                    0xFF9AA3BF,
                                  ).withOpacity(0.95),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // ✅ only chevron now
                        AnimatedRotation(
                          turns: expanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20, // smaller
                            color: const Color(0xFF9AA3BF).withOpacity(0.95),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Expand area
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        children: [
                          AbsorbPointer(
                            absorbing: submitting,
                            child: Row(
                              children: [
                                Expanded(
                                  child: _DarkChoicePill(
                                    emoji: "😴",
                                    label: "Poor",
                                    selected: selected == SleepQuality.poor,
                                    onTap: () => onSelected(SleepQuality.poor),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _DarkChoicePill(
                                    emoji: "😐",
                                    label: "Okay",
                                    selected: selected == SleepQuality.okay,
                                    onTap: () => onSelected(SleepQuality.okay),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _DarkChoicePill(
                                    emoji: "😊",
                                    label: "Great",
                                    selected: selected == SleepQuality.great,
                                    onTap: () => onSelected(SleepQuality.great),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (submitting) ...[
                            const SizedBox(height: 12),
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

class _MoonChip extends StatelessWidget {
  const _MoonChip();

  @override
  Widget build(BuildContext context) {
    const glow = Color(0xFF6E56FF);

    return Container(
      height: 40, // smaller
      width: 40, // smaller
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            glow.withOpacity(0.32),
            const Color(0xFF2B2F55).withOpacity(0.68),
          ],
        ),
        border: Border.all(color: glow.withOpacity(0.20)),
        boxShadow: [
          BoxShadow(
            color: glow.withOpacity(0.16),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.nightlight_round,
          size: 18, // smaller
          color: Colors.white.withOpacity(0.88),
        ),
      ),
    );
  }
}

class _DarkChoicePill extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DarkChoicePill({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const glow = Color(0xFF6E56FF);
    const border = Color(0xFF2D3556);

    final bg = selected
        ? glow.withOpacity(0.18)
        : Colors.white.withOpacity(0.04);

    final outline = selected
        ? glow.withOpacity(0.40)
        : border.withOpacity(0.75);

    return SizedBox(
      height: 40,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: outline, width: 1),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: Colors.white.withOpacity(0.88),
                      ),
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white.withOpacity(0.88),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
