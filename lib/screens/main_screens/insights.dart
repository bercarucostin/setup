import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:setup/features/energy/models/energy_point.dart';
import 'package:setup/features/energy/providers/energy_provider.dart';
import 'package:setup/features/energy/widgets/tiles.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  bool _didRefreshFeedback = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // We only want to force-refresh today's feedback map once
    // when this screen becomes active the first time.
    if (!_didRefreshFeedback) {
      _didRefreshFeedback = true;
      // This is now safe to call here (not safe in initState()).
      ref.invalidate(todayFeedbackMapProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Trigger (re)fetch of energy model and predicted energy
    final energyAsync = ref.watch(energyModelProvider);
    final pointsAsync = ref.watch(predictedEnergyProvider);

    // ALSO trigger (re)fetch of today's feedback map so tiles can use it.
    // Now that we're in build(), this is legal and will run after invalidate().
    ref.watch(todayFeedbackMapProvider);

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: energyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error loading data: $e')),
        data: (_) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const EnergySectionHeader(
                    title: "Today’s Energy Forecast",
                    subtitle: "What to tackle in each window",
                  ),
                  const SizedBox(height: 12),

                  // Main card with scrollable tile list
                  Expanded(
                    child: pointsAsync.when(
                      loading:
                          () =>
                              const Center(child: CircularProgressIndicator()),
                      error: (e, st) => Center(child: Text('Error: $e')),
                      data: (List<EnergyPoint> points) {
                        final theme = Theme.of(context);

                        return Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.outline.withOpacity(
                                0.08,
                              ),
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
                            child: EnergyTileList(
                              entries: points,
                              density: EnergyTileDensity.compact,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class EnergySectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const EnergySectionHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w400,
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
                ),
              ),
            ),
        ],
      ),
    );
  }
}
