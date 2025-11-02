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
  @override
  Widget build(BuildContext context) {
    final energyAsync = ref.watch(energyModelProvider);
    final pointsAsync = ref.watch(predictedEnergyProvider);
    final user =
        FirebaseAuth.instance.currentUser; // still here if you need it later

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
                  // Header
                  const EnergySectionHeader(
                    title: "Today’s Energy Forecast",
                    subtitle: "What to tackle in each window",
                  ),
                  const SizedBox(height: 12),

                  // Card with scrollable tile list
                  Expanded(
                    child: pointsAsync.when(
                      loading:
                          () =>
                              const Center(child: CircularProgressIndicator()),
                      error: (e, st) => Center(child: Text('Error: $e')),
                      data: (List<EnergyPoint> points) {
                        // debug print
                        for (var p in points) {
                          // ignore: avoid_print
                          print('Point: hour=${p.hour}, energy=${p.energy}');
                        }

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
