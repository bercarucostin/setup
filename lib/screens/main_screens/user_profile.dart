import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:setup/features/auth/providers/providers.dart'; // firebaseUserProvider, authControllerProvider, profileSetupProvider, authStateChangesProvider
import 'package:setup/features/energy/providers/energy_provider.dart';
import 'package:setup/features/firestore/providers/providers.dart'; // firestoreRepositoryProvider

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with TickerProviderStateMixin {
  final List<bool> _expanded = [false, false, false];

  // Round to the nearest hour; minutes >= 30 round up. Returns 0..23.
  int _hour0to23Round(TimeOfDay t) => (t.hour + (t.minute >= 30 ? 1 : 0)) % 24;

  // Parse "HH:mm" or "h:mm AM/PM" into TimeOfDay, with sensible defaults.
  TimeOfDay _parseTimeOfDay(String? s, {int defH = 7, int defM = 0}) {
    if (s == null || s.trim().isEmpty) {
      return TimeOfDay(hour: defH, minute: defM);
    }
    final normalized =
        s.replaceAll('\u00A0', ' ').replaceAll('\u202F', ' ').trim();

    // 24h: HH:mm
    final m24 = RegExp(r'^(\d{1,2})\s*:\s*(\d{1,2})$').firstMatch(normalized);
    if (m24 != null) {
      final h = int.tryParse(m24.group(1) ?? '') ?? defH;
      final m = int.tryParse(m24.group(2) ?? '') ?? defM;
      return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
    }

    // 12h: h:mm AM/PM
    final m12 = RegExp(
      r'^(\d{1,2})\s*:\s*(\d{1,2})\s*([AaPp][Mm])$',
    ).firstMatch(normalized);
    if (m12 != null) {
      var h = int.tryParse(m12.group(1) ?? '') ?? defH;
      final m = int.tryParse(m12.group(2) ?? '') ?? defM;
      final ap = (m12.group(3) ?? '').toLowerCase();
      if (ap == 'pm' && h != 12) h += 12;
      if (ap == 'am' && h == 12) h = 0;
      return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
    }

    return TimeOfDay(hour: defH, minute: defM);
  }

  Widget _chronotypeIcon(String type) {
    final Map<String, String> assetPaths = {
      'Morning': 'assets/icons/morning.svg',
      'Midday': 'assets/icons/midday.svg',
      'Evening': 'assets/icons/evening.svg',
    };
    final path = assetPaths[type];
    return path == null
        ? const SizedBox.shrink()
        : SvgPicture.asset(path, height: 18, width: 18);
  }

  Future<void> _editChronotype(String? current) async {
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
                        title: Text(
                          type,
                          style: TextStyle(
                            fontWeight:
                                type == current ? FontWeight.bold : null,
                          ),
                        ),
                        onTap: () => Navigator.pop(context, type),
                      );
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

    if (!mounted || selected == null) return;

    // Keep local provider state in sync
    ref.read(profileSetupProvider.notifier).updateChronotype(selected);

    // Partial save to Firestore, then refresh the profile doc provider
    final user = ref.read(firebaseUserProvider);
    if (user != null) {
      await ref
          .read(firestoreRepositoryProvider)
          .saveData(
            collectionPath: 'users',
            docId: user.uid,
            data: {'chronotype': selected},
            merge: true,
          );
      Future.microtask(() async {
        await ref.read(energyRepositoryProvider).deleteEnergyModel(user.uid);
        // If you have an energyModelProvider, refresh it so it refetches default
        // ref.invalidate(energyModelProvider);
      });
    }
  }

  Future<void> _editSleepSchedule(Map<String, dynamic>? profile) async {
    final wake = await showTimePicker(
      context: context,
      initialTime: _parseTimeOfDay(
        profile?['wakeTime'] as String?,
        defH: 7,
        defM: 0,
      ),
      helpText: 'Select Wake Up Time',
      initialEntryMode: TimePickerEntryMode.inputOnly,
    );
    if (wake == null) return;

    final bed = await showTimePicker(
      context: context,
      initialTime: _parseTimeOfDay(
        profile?['bedTime'] as String?,
        defH: 23,
        defM: 0,
      ),
      helpText: 'Select Bed Time',
      initialEntryMode: TimePickerEntryMode.inputOnly,
    );
    if (bed == null) return;

    final wakeStr = wake.format(context);
    final bedStr = bed.format(context);
    final wakeH = _hour0to23Round(wake);
    final bedH = _hour0to23Round(bed);

    // Update local provider state (keeps other flows consistent)
    ref
        .read(profileSetupProvider.notifier)
        .updateSleepTimes(wakeStr, bedStr, wakeH, bedH);

    // Partial save: only the 4 fields we changed
    final user = ref.read(firebaseUserProvider);
    if (user != null) {
      await ref
          .read(firestoreRepositoryProvider)
          .saveData(
            collectionPath: 'users',
            docId: user.uid,
            data: {
              'wakeTime': wakeStr,
              'bedTime': bedStr,
              'wakeHour': wakeH,
              'bedHour': bedH,
            },
            merge: true,
          );
      // ref.invalidate(userProfileDocProvider);
    }
  }

  Future<void> _editGoal(String? current) async {
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
                          style: TextStyle(
                            fontWeight:
                                option == current ? FontWeight.bold : null,
                          ),
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

    if (!mounted || selected == null) return;

    ref.read(profileSetupProvider.notifier).updateGoal(selected);

    final user = ref.read(firebaseUserProvider);
    if (user != null) {
      await ref
          .read(firestoreRepositoryProvider)
          .saveData(
            collectionPath: 'users',
            docId: user.uid,
            data: {'goal': selected},
            merge: true,
          );
      // ref.invalidate(userProfileDocProvider);
    }
  }

  Widget _accountInfoTile({required String displayName, String? email}) {
    String _initials(String name) {
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty) return '?';
      final first = parts.first.isNotEmpty ? parts.first[0] : '';
      final last =
          parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
      return (first + last).toUpperCase();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey.shade200,
            child: Text(
              _initials(displayName),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (email != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authStateChangesProvider);
    final profileAsync = ref.watch(userProfileDocProvider);

    final titles = ['Account Settings', 'Manage Subscription', 'Feedback'];
    final icons = [Icons.person, Icons.subscriptions, Icons.feedback];

    return Scaffold(
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (snap) {
          final Map<String, dynamic>? profile =
              (snap != null && snap.exists) ? snap.data() : null;
          final chronotype = profile?['chronotype'] as String?;
          final wakeTime = profile?['wakeTime'] as String?;
          final bedTime = profile?['bedTime'] as String?;
          final goal = profile?['goal'] as String?;
          final displayName = userAsync.value?.displayName ?? 'Guest';

          return Column(
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
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w400,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                            vertical: 8.0,
                          ),
                          child: _accountInfoTile(
                            displayName: displayName,
                            email: userAsync.value?.email,
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
                                      () =>
                                          _expanded[index] = !_expanded[index],
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                                      profile: profile,
                                                      chronotype: chronotype,
                                                      wakeTime: wakeTime,
                                                      bedTime: bedTime,
                                                      goal: goal,
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
                        await ref
                            .read(authControllerProvider.notifier)
                            .signOut();
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
          );
        },
      ),
    );
  }

  Widget _buildExpandedContent(
    int index, {
    required Map<String, dynamic>? profile,
    required String? chronotype,
    required String? wakeTime,
    required String? bedTime,
    required String? goal,
  }) {
    if (index == 0) {
      // Account Settings
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          if (chronotype != null)
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
                              'Chronotype: $chronotype',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            _chronotypeIcon(chronotype),
                          ],
                        ),
                        TextButton(
                          onPressed: () => _editChronotype(chronotype),
                          child: const Text('Edit'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          if (wakeTime != null && bedTime != null)
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
                            'Wake: $wakeTime → Bed: $bedTime',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _editSleepSchedule(profile),
                          child: const Text('Edit'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          if (goal != null)
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
                            'Goal: $goal',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _editGoal(goal),
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
      // Manage Subscription
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
      // Feedback
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
