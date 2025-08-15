import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setup/features/energy/providers/energy_providers.dart';
import 'package:setup/features/energy/widgets/chart.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
                      padding: const EdgeInsets.only(top: 32.0, bottom: 16.0),
                      child: Column(
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    0,
                                    20,
                                    0,
                                    20,
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [Text('Peak'), Text('Low')],
                                  ),
                                ),
                                Expanded(
                                  child:
                                      points.isEmpty
                                          ? const Center(
                                            child: Text(
                                              'No energy prediction available.',
                                            ),
                                          )
                                          : LineChartSample4(
                                            energyPoints: points,
                                            mainLineColor: Color(0xFF354975),
                                            belowLineColor: Color(
                                              0xFF354975,
                                            ).withOpacity(0.2),
                                            aboveLineColor: Colors.white
                                                .withOpacity(0.7),
                                          ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Text('Morning'),
                                Text('Noon'),
                                Text('Evening'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Add space between chart and feedback sections
                  const SizedBox(height: 24),
                  // Sleep quality feedback section (beautified)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: Color(0xFF354975), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Text(
                            "How well did you sleep last night?",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _sleepButton("Awful"),
                              _sleepButton("Okay"),
                              _sleepButton("Great"),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Add more space before the last section
                  const SizedBox(height: 24),
                  // Energy feedback section (beautified)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: Color(0xFF354975), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Text(
                            "Give your energy feedback (0-100) for a specific hour (0-23):",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _numberField(_hourController, 'Hour', '0-23'),
                              _numberField(
                                _energyController,
                                'Energy',
                                '0-100',
                              ),
                              SizedBox(
                                width: 90,
                                height: 36,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF354975),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                  onPressed: () async {
                                    final hour = int.tryParse(
                                      _hourController.text,
                                    );
                                    final energy = double.tryParse(
                                      _energyController.text,
                                    );
                                    if (hour == null || hour < 0 || hour > 23) {
                                      _showSnack(
                                        'Hour must be between 0 and 23',
                                      );
                                      return;
                                    }
                                    if (energy == null ||
                                        energy < 0 ||
                                        energy > 100) {
                                      _showSnack(
                                        'Energy must be between 0 and 100',
                                      );
                                      return;
                                    }
                                    if (user == null) {
                                      _showSnack('User not authenticated');
                                      return;
                                    }
                                    await notifier.updateModelWeights(
                                      hour: hour,
                                      actualEnergy: energy,
                                    );
                                    notifier.refreshModel();
                                    _showSnack('Energy feedback submitted!');
                                  },
                                  child: const Text(
                                    'Submit',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
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
