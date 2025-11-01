import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setup/features/energy/models/energy_point.dart';
import 'package:setup/features/energy/providers/energy_provider.dart';
import 'package:setup/features/energy/widgets/chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:setup/features/energy/widgets/tiles.dart';

/// A screen that displays the user’s energy prediction and feedback
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  final _hourController = TextEditingController();
  final _energyController = TextEditingController();

  @override
  void dispose() {
    _hourController.dispose();
    _energyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final energyAsync = ref.watch(energyModelProvider);
    final notifier = ref.read(energyModelProvider.notifier);
    final points = ref.watch(predictedEnergyProvider);
    final user = FirebaseAuth.instance.currentUser;

    // Helper for sleep feedback buttons
    Widget _sleepButton(String label) {
      return SizedBox(
        width: 100,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Color(0xFF354975),
            side: const BorderSide(color: Color(0xFF354975), width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          onPressed: () async {
            final Map<String, dynamic> sleepMap = {
              'Awful': 3,
              'Okay': 6,
              'Great': 9,
            };
            final hoursSlept = sleepMap[label];
            if (user == null) {
              _showSnack('User not authenticated');
              return;
            }
            await notifier.updateHoursSlept(hoursSlept: hoursSlept);
            notifier.refreshModel();
            _showSnack('Energy feedback submitted!');
          },
          child: Text(label),
        ),
      );
    }

    return Scaffold(
      body: energyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error loading data: $e')),
        data: (_) {
          return Center(
            child: SizedBox(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width - 20,
              child: Column(
                children: [
                  // Chart section - more space
                  Flexible(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 0.0, bottom: 0.0),
                      child: Column(
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: points.when(
                                    loading:
                                        () => const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                    error:
                                        (e, st) =>
                                            Center(child: Text('Error: $e')),
                                    data: (_) {
                                      return SafeArea(
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            12,
                                            12,
                                            0,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              const EnergySectionHeader(
                                                title:
                                                    "Today’s Energy Forecast",
                                                subtitle:
                                                    "What to tackle in each window",
                                              ),
                                              const SizedBox(height: 8),
                                              // The list is scrollable; Expanded gives it the remaining height.
                                              Expanded(
                                                child: points.when(
                                                  loading:
                                                      () => const Center(
                                                        child:
                                                            CircularProgressIndicator(),
                                                      ),
                                                  error:
                                                      (e, st) => Center(
                                                        child: Text(
                                                          'Error: $e',
                                                        ),
                                                      ),
                                                  data: (points) {
                                                    final theme = Theme.of(
                                                      context,
                                                    );

                                                    for (var p in points) {
                                                      print(
                                                        'Point: hour=${p.hour}, energy=${p.energy}',
                                                      );
                                                    }
                                                    return Container(
                                                      // A minimal card shell so the list has a clear, polished boundary
                                                      decoration: BoxDecoration(
                                                        color:
                                                            theme
                                                                .colorScheme
                                                                .surface, // slightly different than scaffold white
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              16,
                                                            ),
                                                        border: Border.all(
                                                          color: theme
                                                              .colorScheme
                                                              .outline
                                                              .withOpacity(
                                                                0.08,
                                                              ),
                                                        ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                  0.04,
                                                                ),
                                                            blurRadius: 16,
                                                            offset:
                                                                const Offset(
                                                                  0,
                                                                  8,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      clipBehavior:
                                                          Clip.antiAlias, // make list content respect rounded corners
                                                      child: Padding(
                                                        // tiny bottom breathing room so last tile doesn't touch the edge
                                                        padding:
                                                            const EdgeInsets.only(
                                                              bottom: 8,
                                                            ),
                                                        child: EnergyTileList(
                                                          entries: points,
                                                          density:
                                                              EnergyTileDensity
                                                                  .compact,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    String hint,
  ) {
    return SizedBox(
      width: 80,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 8,
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
