import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:setup/auth/application/auth_controller.dart';
import 'package:setup/auth/data/firebase_auth_repository_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with TickerProviderStateMixin {
  final List<bool> _expanded = [false, false, false];
  String? _chronotype;
  String? _wakeTime;
  String? _bedTime;
  String? _goal;

  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    //_loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataLoaded) {
      _dataLoaded = true;
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    final user = ref.read(firebaseUserProvider);
    if (user == null) return;
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
    final data = doc.data();
    if (data != null) {
      setState(() {
        _chronotype = data['chronotype'] as String?;
        _wakeTime = data['wakeTime'] as String?;
        _bedTime = data['bedTime'] as String?;
        _goal = data['goal'] as String?;
      });
    }
  }

  Widget _chronotypeIcon(String type) {
    final Map<String, String> assetPaths = {
      'Morning': 'assets/icons/morning.svg',
      'Midday': 'assets/icons/midday.svg',
      'Evening': 'assets/icons/evening.svg',
    };
    return SvgPicture.asset(assetPaths[type] ?? '', height: 18, width: 18);
  }

  Future<void> _editChronotype() async {
    final options = ['Morning', 'Midday', 'Evening'];

    final selected = await showDialog<String>(
      context: context,
      builder:
          (_) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 40,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Select Your Chronotype',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(options.length * 2 - 1, (i) {
                    if (i.isEven) {
                      final type = options[i ~/ 2];
                      final tile = ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        leading: _chronotypeIcon(type),
                        title: Text(type),
                        onTap: () => Navigator.pop(context, type),
                      );

                      // Apply extra left padding only to Midday
                      return type == 'Midday'
                          ? Padding(
                            padding: const EdgeInsets.only(left: 5),
                            child: tile,
                          )
                          : tile;
                    } else {
                      return const Divider(height: 1, thickness: 1);
                    }
                  }),
                ],
              ),
            ),
          ),
    );

    if (selected != null) {
      final user = ref.read(firebaseUserProvider);
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'chronotype': selected});
        setState(() => _chronotype = selected);
      }
    }
  }

  Future<void> _editSleepSchedule() async {
    final wake = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 7, minute: 0),
      helpText: 'Select Wake Up Time',
      initialEntryMode: TimePickerEntryMode.inputOnly,
    );
    if (wake == null) return;

    final bed = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 23, minute: 0),
      helpText: 'Select Bed Time',
      initialEntryMode: TimePickerEntryMode.inputOnly,
    );
    if (bed == null) return;

    final user = ref.read(firebaseUserProvider);
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'wakeTime': wake.format(context), 'bedTime': bed.format(context)},
      );
      setState(() {
        _wakeTime = wake.format(context);
        _bedTime = bed.format(context);
      });
    }
  }

  Future<void> _editGoal() async {
    final options = [
      'Improve my daily energy levels',
      'Optimize my sleep and recovery',
      'Understand my personal rhythm',
      'Boost productivity during peak hours',
      'Just curious to explore',
    ];

    final selected = await showDialog<String>(
      context: context,
      builder:
          (_) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 40,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Select Your Goal',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(options.length * 2 - 1, (i) {
                    if (i.isEven) {
                      final option = options[i ~/ 2];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        leading: const Icon(
                          Icons.flag_outlined,
                          color: Colors.teal,
                        ),
                        title: Text(
                          option,
                          style: const TextStyle(fontSize: 14),
                        ),
                        onTap: () => Navigator.pop(context, option),
                      );
                    } else {
                      return const Divider(height: 1, thickness: 1);
                    }
                  }),
                ],
              ),
            ),
          ),
    );

    if (selected != null) {
      final user = ref.read(firebaseUserProvider);
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'goal': selected});
        setState(() => _goal = selected);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(firebaseUserProvider);
    final displayName = user?.displayName ?? 'Guest';

    final titles = ['Account Settings', 'Manage Subscription', 'Feedback'];
    final icons = [Icons.person, Icons.subscriptions, Icons.feedback];

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(top: 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 24.0, bottom: 8.0),
                      child: Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    ...List.generate(_expanded.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 8.0,
                        ),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: _expanded[index] ? 0 : 1,
                            end: _expanded[index] ? 1 : 0,
                          ),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          builder: (context, value, child) {
                            return GestureDetector(
                              onTap: () {
                                setState(
                                  () => _expanded[index] = !_expanded[index],
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 12.0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          icons[index],
                                          color: Colors.black54,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          titles[index],
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(
                                          _expanded[index]
                                              ? Icons.expand_less
                                              : Icons.expand_more,
                                          size: 18,
                                          color: Colors.grey,
                                        ),
                                      ],
                                    ),
                                    ClipRect(
                                      child: Align(
                                        heightFactor: value,
                                        alignment: Alignment.topCenter,
                                        child:
                                            _expanded[index]
                                                ? _buildExpandedContent(
                                                  index,
                                                  displayName,
                                                )
                                                : const SizedBox.shrink(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 8.0,
            ),
            child: Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await ref.read(authControllerProvider.notifier).signOut();
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(int index, String displayName) {
    if (index == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          if (_chronotype != null)
            Row(
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Chronotype: $_chronotype',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            _chronotypeIcon(_chronotype!),
                          ],
                        ),
                        TextButton(
                          onPressed: _editChronotype,
                          child: const Text('Edit'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          if (_wakeTime != null && _bedTime != null)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Wake: $_wakeTime → Bed: $_bedTime',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        TextButton(
                          onPressed: _editSleepSchedule,
                          child: const Text('Edit'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          SizedBox(height: 8),
          if (_goal != null)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Goal: $_goal',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        TextButton(
                          onPressed: _editGoal,
                          child: const Text('Edit'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      );
    } else if (index == 1) {
      return Column(
        children: [
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            child: const Text('Manage your subscription'),
          ),
        ],
      );
    } else if (index == 2) {
      return Column(
        children: [
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () {}, child: const Text('Send Feedback')),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
