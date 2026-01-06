import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:peak_flow/features/auth/providers/auth_controller_provider.dart';
import 'package:peak_flow/features/auth/providers/providers.dart'; // firebaseAuthProvider, userProfileStreamProvider
import 'package:peak_flow/features/firestore/providers/providers.dart'; // firestoreRepositoryProvider

class ProfileTabBody extends ConsumerStatefulWidget {
  const ProfileTabBody({super.key});

  @override
  ConsumerState<ProfileTabBody> createState() => _ProfileTabBodyState();
}

class _ProfileTabBodyState extends ConsumerState<ProfileTabBody> {
  final List<bool> _expanded = [false, false, false];

  // Round to nearest hour; minutes >= 30 round up. Returns 0..23.
  int _hour0to23Round(TimeOfDay t) => (t.hour + (t.minute >= 30 ? 1 : 0)) % 24;

  // Canonical storage format: "HH:mm"
  String _toHHmm(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  // Simple parser for canonical "HH:mm" only (falls back to defaults)
  TimeOfDay _parseHHmm(String? s, {required int defH, required int defM}) {
    if (s == null || s.trim().isEmpty) {
      return TimeOfDay(hour: defH, minute: defM);
    }
    final parts = s.trim().split(':');
    if (parts.length != 2) return TimeOfDay(hour: defH, minute: defM);

    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return TimeOfDay(hour: defH, minute: defM);

    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  Future<void> _mergeUserData(Map<String, dynamic> data) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    await ref
        .read(firestoreRepositoryProvider)
        .saveData(
          collectionPath: 'users',
          docId: user.uid,
          data: data,
          merge: true,
        );
  }

  // ---------------------------------------------------------------------------
  // Assets / icons
  // ---------------------------------------------------------------------------

  Widget _chronotypeIcon(String type) {
    const assetPaths = {
      'Morning': 'assets/icons/morning.svg',
      'Midday': 'assets/icons/midday.svg',
      'Evening': 'assets/icons/evening.svg',
    };
    final path = assetPaths[type];
    return path == null
        ? const SizedBox.shrink()
        : SvgPicture.asset(path, height: 18, width: 18);
  }

  // ---------------------------------------------------------------------------
  // Edit Actions
  // ---------------------------------------------------------------------------

  Future<void> _editChronotype(String? current) async {
    const options = ['Morning', 'Midday', 'Evening'];

    final selected = await showDialog<String>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
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
                if (!i.isEven) return const Divider(height: 1, thickness: 1);

                final type = options[i ~/ 2];
                final tile = ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: _chronotypeIcon(type),
                  title: Text(
                    type,
                    style: TextStyle(
                      fontWeight: type == current ? FontWeight.bold : null,
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
              }),
            ],
          ),
        ),
      ),
    );

    if (!mounted || selected == null) return;
    await _mergeUserData({'chronotype': selected});
  }

  Future<void> _editSleepSchedule({String? wakeTime, String? bedTime}) async {
    final wake = await showTimePicker(
      context: context,
      initialTime: _parseHHmm(wakeTime, defH: 7, defM: 0),
      helpText: 'Select Wake Up Time',
      initialEntryMode: TimePickerEntryMode.inputOnly,
    );
    if (wake == null) return;

    final bed = await showTimePicker(
      context: context,
      initialTime: _parseHHmm(bedTime, defH: 23, defM: 0),
      helpText: 'Select Bed Time',
      initialEntryMode: TimePickerEntryMode.inputOnly,
    );
    if (bed == null) return;

    // Save canonical "HH:mm" regardless of locale
    final wakeStr = _toHHmm(wake);
    final bedStr = _toHHmm(bed);

    final wakeH = _hour0to23Round(wake);
    final bedH = _hour0to23Round(bed);

    await _mergeUserData({
      'wakeTime': wakeStr,
      'bedTime': bedStr,
      'wakeHour': wakeH,
      'bedHour': bedH,
    });
  }

  Future<void> _editGoal(String? current) async {
    const options = [
      'Improve my daily energy levels',
      'Optimize my sleep and recovery',
      'Understand my personal rhythm',
      'Boost productivity during peak hours',
      'Just curious to explore',
    ];

    final selected = await showDialog<String>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
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
                if (!i.isEven) return const Divider(height: 1, thickness: 1);

                final option = options[i ~/ 2];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: const Icon(Icons.flag_outlined, color: Colors.teal),
                  title: Text(
                    option,
                    style: TextStyle(
                      fontWeight: option == current ? FontWeight.bold : null,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, option),
                );
              }),
            ],
          ),
        ),
      ),
    );

    if (!mounted || selected == null) return;
    await _mergeUserData({'goal': selected});
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------

  Widget _accountInfoTile({required String displayName, String? email}) {
    String initials(String name) {
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty) return '?';
      final first = parts.first.isNotEmpty ? parts.first[0] : '';
      final last = parts.length > 1 && parts.last.isNotEmpty
          ? parts.last[0]
          : '';
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
              initials(displayName),
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

  // ---------------------------------------------------------------------------
  // Build (NO Scaffold)
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    if (user == null) return const Center(child: Text('Not signed in'));

    final profileAsync = ref.watch(userProfileStreamProvider(user.uid));

    const titles = ['Account Settings', 'Manage Subscription', 'Feedback'];
    const icons = [Icons.person, Icons.subscriptions, Icons.feedback];

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (profile) {
        final chronotype = profile?['chronotype'] as String?;
        final wakeTime = profile?['wakeTime'] as String?;
        final bedTime = profile?['bedTime'] as String?;
        final goal = profile?['goal'] as String?;
        final displayName = user.displayName ?? 'Guest';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 24.0,
                right: 16.0,
                top: 32.0,
                bottom: 8.0,
              ),
              child: Row(
                children: [
                  const Expanded(
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
                  _HeaderSignOutButton(
                    onSignOut: () async {
                      await ref.read(authControllerProvider.notifier).signOut();
                    },
                  ),
                ],
              ),
            ),
            Divider(color: Colors.black, thickness: 1, height: 1),

            Expanded(
              child: SingleChildScrollView(
                primary: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 8.0,
                      ),
                      child: _accountInfoTile(
                        displayName: displayName,
                        email: user.email,
                      ),
                    ),

                    ...List.generate(titles.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 8.0,
                        ),
                        child: GestureDetector(
                          onTap: () => setState(
                            () => _expanded[index] = !_expanded[index],
                          ),
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
                                      style: const TextStyle(fontSize: 16),
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
                                AnimatedCrossFade(
                                  duration: const Duration(milliseconds: 250),
                                  sizeCurve: Curves.easeInOut,
                                  crossFadeState: _expanded[index]
                                      ? CrossFadeState.showSecond
                                      : CrossFadeState.showFirst,
                                  firstChild: const SizedBox.shrink(),
                                  secondChild: _buildExpandedContent(
                                    index,
                                    chronotype: chronotype,
                                    wakeTime: wakeTime,
                                    bedTime: bedTime,
                                    goal: goal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            Divider(color: Colors.grey.shade300, thickness: 1, height: 1),
          ],
        );
      },
    );
  }

  Widget _buildExpandedContent(
    int index, {
    required String? chronotype,
    required String? wakeTime,
    required String? bedTime,
    required String? goal,
  }) {
    if (index == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          if (chronotype != null)
            Container(
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

          if (wakeTime != null && bedTime != null)
            Container(
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
                    onPressed: () => _editSleepSchedule(
                      wakeTime: wakeTime,
                      bedTime: bedTime,
                    ),
                    child: const Text('Edit'),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          if (goal != null)
            Container(
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
        ],
      );
    }

    if (index == 1) {
      return Column(
        children: [
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            child: const Text('Manage your subscription'),
          ),
        ],
      );
    }

    if (index == 2) {
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

class _HeaderSignOutButton extends StatefulWidget {
  final Future<void> Function() onSignOut;
  const _HeaderSignOutButton({required this.onSignOut});

  @override
  State<_HeaderSignOutButton> createState() => _HeaderSignOutButtonState();
}

class _HeaderSignOutButtonState extends State<_HeaderSignOutButton> {
  bool _loading = false;

  Future<void> _handle() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onSignOut();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Sign out',
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _handle,
        icon: _loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.logout_rounded, size: 18),
        label: const Text('Sign out'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
