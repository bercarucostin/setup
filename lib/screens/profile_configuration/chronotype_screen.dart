import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:setup/features/auth/controllers/profile_setup_notifier.dart';
import 'package:setup/features/auth/providers/providers.dart';

class ChronotypeScreen extends ConsumerStatefulWidget {
  const ChronotypeScreen({super.key});

  @override
  ConsumerState<ChronotypeScreen> createState() => _ChronotypeScreenState();
}

class _ChronotypeScreenState extends ConsumerState<ChronotypeScreen> {
  String? selectedType;

  void _submit() {
    if (selectedType != null) {
      ref.read(profileSetupProvider.notifier).updateChronotype(selectedType!);
      context.go('/sleep-schedule');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            context.go('/complete-profile');
          },
        ),
        title: const Text('Step 2 of 3'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'When do you usually feel most awake and productive?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildCardOption('Morning', 'assets/icons/morning.svg'),
                  _buildCardOption('Midday', 'assets/icons/midday.svg'),
                  _buildCardOption('Evening', 'assets/icons/evening.svg'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: selectedType == null ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: const Color.fromARGB(255, 80, 91, 146),
                minimumSize: const Size.fromHeight(50),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardOption(String label, String assetPath) {
    final isSelected = selectedType == label;

    return GestureDetector(
      onTap: () => setState(() => selectedType = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color:
              isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
          border: Border.all(
            color:
                isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(assetPath, height: 60),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
