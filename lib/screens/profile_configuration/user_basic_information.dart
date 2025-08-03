import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setup/features/auth/controllers/profile_setup_notifier.dart';
import 'package:setup/features/auth/models/auth_state.dart';
import 'package:setup/features/auth/controllers/auth_controller.dart';
import 'package:intl/intl.dart';
import 'package:setup/features/auth/providers/providers.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  DateTime? _selectedBirthday;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final birthday = _selectedBirthday;

    if (name.isEmpty || birthday == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }

    final birthdayStr = DateFormat('yyyy-MM-dd').format(birthday);
    ref
        .read(profileSetupProvider.notifier)
        .updateNameAndBirthday(name, birthdayStr);
    context.go('/chronotype');
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Select your birthday',
    );

    if (picked != null) {
      setState(() => _selectedBirthday = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    if (state is! IncompleteProfile) {
      return const Scaffold(
        body: Center(child: Text("You're not supposed to be here.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 1 of 3'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: const [
                  Icon(
                    Icons.account_circle,
                    size: 72,
                    color: const Color.fromARGB(255, 80, 91, 146),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Complete Your Profile',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'This helps us personalize your experience.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _pickBirthday,
                    child: AbsorbPointer(
                      child: TextField(
                        controller: TextEditingController(
                          text:
                              _selectedBirthday == null
                                  ? ''
                                  : DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(_selectedBirthday!),
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Birthday',
                          hintText: 'Tap to select',
                          prefixIcon: Icon(Icons.cake_outlined),
                          suffixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'What do you hope to achieve?',
                      prefixIcon: Icon(Icons.bolt_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Energy',
                        child: Text('Improve my daily energy levels'),
                      ),
                      DropdownMenuItem(
                        value: 'Sleep',
                        child: Text('Optimize my sleep and recovery'),
                      ),
                      DropdownMenuItem(
                        value: 'Rhythm',
                        child: Text('Understand my personal rhythm'),
                      ),
                      DropdownMenuItem(
                        value: 'Productivity',
                        child: Text('Boost productivity during peak hours'),
                      ),
                      DropdownMenuItem(
                        value: 'Curious',
                        child: Text('Just curious to explore'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(profileSetupProvider.notifier)
                            .updateGoal(value);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'We care about your privacy. Your birthday won’t be public.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: const Color.fromARGB(255, 80, 91, 146),
            minimumSize: const Size.fromHeight(50),
            textStyle: const TextStyle(fontSize: 16),
          ),
          child: const Text('Continue', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
