// lib/features/energy/screens/insights_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watt/features/energy/models/energy_feedback.dart';
import 'package:watt/features/energy/providers/energy_providers.dart';

// Widgets:
import 'package:watt/features/energy/widgets/compact_view_tiles.dart';
import 'package:watt/features/energy/widgets/tiles.dart';
import 'package:watt/features/energy/widgets/tilesv2.dart';

enum InsightsView { detailed, compact }

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  InsightsView _view = InsightsView.detailed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final insightsAsync = ref.watch(energyInsightsProvider);
    final controller = ref.read(energyInsightsProvider.notifier);

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
