import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setup/features/auth/providers/providers.dart';

class SleepScheduleScreen extends ConsumerStatefulWidget {
  const SleepScheduleScreen({super.key});

  @override
  ConsumerState<SleepScheduleScreen> createState() =>
      _SleepScheduleScreenState();
}

class _SleepScheduleScreenState extends ConsumerState<SleepScheduleScreen> {
  TimeOfDay? _wakeTime;
  TimeOfDay? _bedTime;
  bool _submitting = false;

  int hour0to23Round(TimeOfDay t) {
    final h = (t.hour + (t.minute >= 30 ? 1 : 0)) % 24;
    return h;
  }

  Future<void> _pickTime({
    required bool isWake,
    required TimeOfDay initialTime,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: isWake ? 'Select Wake Time' : 'Select Bed Time',
    );

    if (picked != null) {
      setState(() {
        if (isWake) {
          _wakeTime = picked;
        } else {
          _bedTime = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_wakeTime == null || _bedTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select both times')));
      return;
    }

    final wakeMinutes = _wakeTime!.hour * 60 + _wakeTime!.minute;
    final bedMinutes = _bedTime!.hour * 60 + _bedTime!.minute;

    if (wakeMinutes >= bedMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bedtime must be after wake time')),
      );
      return;
    }

    setState(() => _submitting = true);

    ref
        .read(profileSetupProvider.notifier)
        .updateSleepTimes(
          _wakeTime!.format(context),
          _bedTime!.format(context),
          hour0to23Round(_wakeTime!),
          hour0to23Round(_bedTime!),
        );

    await ref.read(profileSetupProvider.notifier).submitAndSaveToFirestore(ref);

    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 3 of 3'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => context.go('/chronotype'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Almost done! Let’s set your sleep schedule 👇',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            _buildTimeCard(
              label: 'When do you typically wake up?',
              icon: Icons.wb_sunny_outlined,
              time: _wakeTime,
              onTap:
                  () => _pickTime(
                    isWake: true,
                    initialTime: TimeOfDay(hour: 7, minute: 0),
                  ),
              theme: Theme.of(context),
            ),
            const SizedBox(height: 24),
            _buildTimeCard(
              label: 'When do you typically go to bed?',
              icon: Icons.bedtime_outlined,
              time: _bedTime,
              onTap:
                  () => _pickTime(
                    isWake: false,
                    initialTime: TimeOfDay(hour: 23, minute: 0),
                  ),
              theme: Theme.of(context),
            ),
            const SizedBox(
              height: 100,
            ), // Add spacing to prevent content being hidden by button
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.check, color: Colors.white),
          onPressed: _submitting ? null : _submit,
          label:
              _submitting
                  ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: CircularProgressIndicator(),
                  )
                  : const Text(
                    'Finish Setup',
                    style: TextStyle(color: Colors.white),
                  ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: const Color.fromARGB(255, 80, 91, 146),
            minimumSize: const Size.fromHeight(50),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeCard({
    required String label,
    required IconData icon,
    required TimeOfDay? time,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Row(
            children: [
              Icon(icon, size: 32, color: theme.primaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      time?.format(context) ?? 'Select Time',
                      style: const TextStyle(fontSize: 15, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
