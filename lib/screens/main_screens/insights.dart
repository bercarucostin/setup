import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:setup/features/auth/providers/providers.dart';
import 'package:setup/features/energy/models/energy_point.dart';
import 'package:setup/features/energy/providers/providers.dart';
import 'package:setup/features/energy/widgets/chart.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  final TextEditingController _hourController = TextEditingController();
  final TextEditingController _energyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final asyncUser = ref.read(authStateChangesProvider);
      final user = asyncUser.value;
      if (user == null) return;

      await user.getIdToken(true);
      await user.reload();

      final vm = ref.read(energyViewModelProvider.notifier);
      await vm.fetchEnergyModel(user.uid, 'Morning');
      vm.computeEnergyPrediction();
    });
  }

  @override
  Widget build(BuildContext context) {
    final energyViewModel = ref.watch(energyViewModelProvider);
    final user = ref.read(authStateChangesProvider).value;

    return Scaffold(
      body: Center(
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
                              padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [Text('Peak'), Text('Low')],
                              ),
                            ),
                            Expanded(
                              child: LineChartSample4(
                                energyPoints: [
                                  EnergyPoint(0, 2), // x=0h, energy=2
                                  EnergyPoint(6, 4), // x=6h, energy=4
                                  EnergyPoint(12, 3), // x=12h, energy=3
                                  EnergyPoint(18, 5), // x=18h, energy=5
                                ], //energyViewModel.predictedEnergy,
                                mainLineColor: Color(0xFF354975),
                                belowLineColor: Color(
                                  0xFF354975,
                                ).withOpacity(0.2),
                                aboveLineColor: Colors.white.withOpacity(0.7),
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
                          _sleepButton("Bad"),
                          _sleepButton("Normal"),
                          _sleepButton("Good"),
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
                          SizedBox(
                            width: 80,
                            height: 36,
                            child: TextField(
                              controller: _hourController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 14),
                              decoration: const InputDecoration(
                                labelText: "Hour",
                                hintText: "0-23",
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 8,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            height: 36,
                            child: TextField(
                              controller: _energyController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 14),
                              decoration: const InputDecoration(
                                labelText: "Energy",
                                hintText: "0-100",
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 8,
                                ),
                              ),
                            ),
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
                                final hour = int.tryParse(_hourController.text);
                                final energy = double.tryParse(
                                  _energyController.text,
                                );
                                if (hour == null || hour < 0 || hour > 23) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Hour must be between 0 and 23",
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                if (energy == null ||
                                    energy < 0 ||
                                    energy > 100) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Energy must be between 0 and 100",
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                if (user == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("User not found"),
                                    ),
                                  );
                                  return;
                                }
                                final vm = ref.read(
                                  energyViewModelProvider.notifier,
                                );
                                await vm.updateModel(hour, energy, user.uid);
                                vm.computeEnergyPrediction();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Energy feedback submitted!"),
                                  ),
                                );
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
      ),
    );
  }

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
        onPressed: () {},
        child: Text(label),
      ),
    );
  }
}
