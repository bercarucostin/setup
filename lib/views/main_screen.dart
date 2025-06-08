import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../viewmodels/energy_view_model.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _hourController = TextEditingController();
  final TextEditingController _energyController = TextEditingController();
  final String userId =
      'A3UAcoA2qiCxEbBsx0pF'; // Replace with the actual user ID

  @override
  void initState() {
    super.initState();
    // Fetch the EnergyModel when the screen is initialized
    final vm = Provider.of<EnergyViewModel>(context, listen: false);
    vm.fetchEnergyModel(userId).then((_) {
      vm.computeEnergyPrediction(); // Populate the predictedEnergy list
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching EnergyModel: $error')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<EnergyViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Energy Tracker'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: vm.predictedEnergy
                          .map((e) => FlSpot(e.hour.toDouble(), e.energy))
                          .toList(),
                      isCurved: true,
                      barWidth: 3,
                      color: Colors.green,
                    ),
                  ],
                  minY: 0,
                  maxY: 100,
                  titlesData: FlTitlesData(show: true),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _hourController,
              decoration: const InputDecoration(
                labelText: 'Hour (0-23)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _energyController,
              decoration: const InputDecoration(
                labelText: 'Actual energy (0-100, optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final hour = int.tryParse(_hourController.text);
                final energy = double.tryParse(_energyController.text);

                if (hour == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid hour.')),
                  );
                  return;
                }

                // try {
                // Compute energy prediction
                vm.computeEnergyPrediction();

                // If energy is provided, update the model
                if (energy != null) {
                  await vm.updateModel(hour, energy, userId);
                  vm.computeEnergyPrediction(); // Recompute predictions after update
                }
                // } catch (error) {
                // Handle errors during computation or update
                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(content: Text('Error: $error')),
                // );
                // }
              },
              child: const Text("Recompute"),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: vm.predictedEnergy.length,
                itemBuilder: (context, index) {
                  final energyPoint = vm.predictedEnergy[index];
                  return ListTile(
                    title: Text('Hour: ${energyPoint.hour}'),
                    subtitle: Text(
                        'Predicted Energy: ${energyPoint.energy.toStringAsFixed(2)}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
