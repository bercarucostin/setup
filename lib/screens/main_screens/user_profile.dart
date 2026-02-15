import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:watt/features/auth/models/auth_state.dart';
import 'package:watt/features/auth/providers/auth_controller_provider.dart';
import 'package:watt/features/auth/providers/providers.dart'; // firebaseAuthProvider, userProfileStreamProvider
import 'package:watt/features/energy/providers/energy_providers.dart';
import 'package:watt/features/firestore/providers/providers.dart'; // firestoreRepositoryProvider
import 'package:watt/screens/profile_configuration/typewriter_time_picker_dialog.dart';

class ProfileTabBody extends ConsumerStatefulWidget {
  const ProfileTabBody({super.key});

  @override
  ConsumerState<ProfileTabBody> createState() => _ProfileTabBodyState();
}

class _ProfileTabBodyState extends ConsumerState<ProfileTabBody> {
  // Replace with your real FAQ page:
  static const String _faqUrl = 'https://www.trywatt.app/#faq';

  final List<bool> _expanded = [
    false, // Notifications
    false, // Privacy
  ];

  bool? _emailNotifOverride;
  bool? _pushNotifOverride;

  static const bool _showNotificationsSection = false;

  int _hour0to23Round(TimeOfDay t) => (t.hour + (t.minute >= 30 ? 1 : 0)) % 24;

  String _toHHmm(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

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
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => Theme(
        // ✅ ensures text uses the same default font as your onboarding screen
        data: Theme.of(context).copyWith(
          dialogTheme: const DialogThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor:
                Colors.transparent, // ✅ removes M3 tint (pink/purple)
          ),
        ),
        child: Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor:
              Colors.transparent, // ✅ kills the “pink/purple” tint
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
                // ✅ match onboarding vibe (don’t force Montserrat)
                const Text(
                  'Select Your Chronotype',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F1F2D),
                  ),
                ),
                const SizedBox(height: 12),

                _ChronotypeTimeCard(
                  label: 'Morning',
                  valueText: current == 'Morning'
                      ? 'Selected'
                      : 'Tap to select',
                  icon: _chronotypeIcon('Morning'),
                  onTap: current == 'Morning'
                      ? null
                      : () => Navigator.pop(context, 'Morning'),
                ),
                const SizedBox(height: 16),

                _ChronotypeTimeCard(
                  label: 'Midday',
                  valueText: current == 'Midday' ? 'Selected' : 'Tap to select',
                  icon: _chronotypeIcon('Midday'),
                  onTap: current == 'Midday'
                      ? null
                      : () => Navigator.pop(context, 'Midday'),
                ),
                const SizedBox(height: 16),

                _ChronotypeTimeCard(
                  label: 'Evening',
                  valueText: current == 'Evening'
                      ? 'Selected'
                      : 'Tap to select',
                  icon: _chronotypeIcon('Evening'),
                  onTap: current == 'Evening'
                      ? null
                      : () => Navigator.pop(context, 'Evening'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!mounted || selected == null) return;

    // Extra safety: if somehow the same value comes back, do nothing.
    if (selected == current) return;

    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user != null) {
      await ref.read(energyRepositoryProvider).deleteEnergyModel(user.uid);
    }

    await _mergeUserData({'chronotype': selected});
  }

  Future<void> _editSleepSchedule({String? wakeTime, String? bedTime}) async {
    final initialWake = _parseHHmm(wakeTime, defH: 7, defM: 0);
    final initialBed = _parseHHmm(bedTime, defH: 23, defM: 0);

    final wake = await showTypewriterTimePickerDialog(
      context,
      title: 'Wake time',
      initial: initialWake,
      hintText: 'Tap and type or use arrow keys',
    );
    if (wake == null) return;

    final bed = await showTypewriterTimePickerDialog(
      // ignore: use_build_context_synchronously
      context,
      title: 'Bed time',
      initial: initialBed,
      hintText: 'Tap and type or use arrow keys',
    );
    if (bed == null) return;

    // ✅ ADD VALIDATION HERE (after both picks)
    final wakeMinutes = wake.hour * 60 + wake.minute;
    final bedMinutes = bed.hour * 60 + bed.minute;
    if (wakeMinutes >= bedMinutes) {
      // silent failure (or show a dialog if you prefer)
      return;
    }

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

    ref.invalidate(energyInsightsProvider);
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
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => Theme(
        data: Theme.of(context).copyWith(
          dialogTheme: const DialogThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent, // ✅ avoids pink/purple tint
          ),
        ),
        child: Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 40,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Your Goal',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F1F2D),
                  ),
                ),
                const SizedBox(height: 12),

                ...options.map((opt) {
                  final isCurrent = opt == current;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GoalTimeCard(
                      label: opt,
                      valueText: isCurrent ? 'Selected' : 'Tap to select',
                      isSelected: isCurrent,
                      onTap: isCurrent
                          ? null
                          : () => Navigator.pop(context, opt),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );

    if (!mounted || selected == null) return;
    if (selected == current) return;

    await _mergeUserData({'goal': selected});
  }

  Future<void> _openFaq() async {
    final uri = Uri.parse(_faqUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open FAQ.')));
    }
  }

  // ---------------------------------------------------------------------------
  // Stylish feedback popup (no controller -> no dispose crash)
  // ---------------------------------------------------------------------------

  Future<void> _openFeedbackDialog() async {
    final formKey = GlobalKey<FormState>();
    String text = '';

    final submitted = await showDialog<String?>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    height: 34,
                    width: 34,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Icon(
                      Icons.feedback_outlined,
                      size: 18,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Send feedback',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context, null),
                    icon: const Icon(Icons.close_rounded),
                    splashRadius: 18,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'What should we improve?',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ),
              const SizedBox(height: 10),
              Form(
                key: formKey,
                child: TextFormField(
                  autofocus: true,
                  minLines: 5,
                  maxLines: 9,
                  maxLength: 800,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText:
                        'Tell us what you liked, what felt off, or what you want next…',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                  ),
                  onChanged: (v) => text = v,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Please write a few words.';
                    if (t.length < 10) return 'Can you add a bit more detail?';
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, null),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          FocusScope.of(context).unfocus();
                          return;
                        }
                        Navigator.pop(context, text.trim());
                      },
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Submit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (submitted == null) return;

    debugPrint('FEEDBACK_SUBMITTED: $submitted');

    try {
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user == null) return;

      await ref
          .read(firestoreRepositoryProvider)
          .submitFeedback(
            message: submitted,
            uid: user.uid,
            email: user.email,
            displayName: user.displayName,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks! Your feedback was received.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send feedback: $e')));
    }
  }

  Future<String?> _askPasswordDialog() async {
    final formKey = GlobalKey<FormState>();
    String text = '';

    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Confirm your password'),
        content: Form(
          key: formKey,
          child: TextFormField(
            autofocus: true,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
            onChanged: (v) => text = v,
            validator: (v) {
              if ((v ?? '').trim().isEmpty) return 'Password is required.';
              return null;
            },
            onFieldSubmitted: (_) {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.pop(context, text.trim());
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.pop(context, text.trim());
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Delete Account
  // ---------------------------------------------------------------------------

  Future<void> _handleDeleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete my account'),
        content: const Text(
          'This action is permanent. Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not signed in.')));
      return;
    }

    final providerIds = user.providerData.map((p) => p.providerId).toSet();
    String? password;

    if (providerIds.contains('password')) {
      final submittedPassword = await _askPasswordDialog();
      if (submittedPassword == null) return; // cancelled
      password = submittedPassword;
    }

    await ref
        .read(authControllerProvider.notifier)
        .deleteAccount(password: password);

    if (!context.mounted) return;

    final authState = ref.read(authControllerProvider);
    if (authState is AuthError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authState.message)));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Account deleted.')));
    }
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------

  Widget _profileHeader({required String displayName, String? email}) {
    String initials(String name) {
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty) return '?';
      final first = parts.first.isNotEmpty ? parts.first[0] : '';
      final last = parts.length > 1 && parts.last.isNotEmpty
          ? parts.last[0]
          : '';
      final s = (first + last).toUpperCase();
      return s.isEmpty ? '?' : s;
    }

    return Row(
      children: [
        CircleAvatar(
          radius: 24,
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
                  fontSize: 18,
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
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openChangePasswordFlow() async {
    final formKey = GlobalKey<FormState>();

    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final currentFocus = FocusNode();
    final newFocus = FocusNode();
    final confirmFocus = FocusNode();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    void safePop(BuildContext ctx, bool value) {
      // Unfocus first so the IME / focus system settles before the route is removed.
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.pop(ctx, value);
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) => Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 34,
                          width: 34,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Change password',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => safePop(ctx, false),
                          icon: const Icon(Icons.close_rounded),
                          splashRadius: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: currentCtrl,
                      focusNode: currentFocus,
                      obscureText: obscureCurrent,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => newFocus.requestFocus(),
                      decoration: InputDecoration(
                        labelText: 'Current password',
                        suffixIcon: IconButton(
                          onPressed: () {
                            if (!ctx.mounted) return;
                            setLocal(() => obscureCurrent = !obscureCurrent);
                          },
                          icon: Icon(
                            obscureCurrent
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: newCtrl,
                      focusNode: newFocus,
                      obscureText: obscureNew,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => confirmFocus.requestFocus(),
                      decoration: InputDecoration(
                        labelText: 'New password',
                        suffixIcon: IconButton(
                          onPressed: () {
                            if (!ctx.mounted) return;
                            setLocal(() => obscureNew = !obscureNew);
                          },
                          icon: Icon(
                            obscureNew
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'Required';
                        if (t.length < 8) return 'Minimum 8 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: confirmCtrl,
                      focusNode: confirmFocus,
                      obscureText: obscureConfirm,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!(formKey.currentState?.validate() ?? false))
                          return;
                        safePop(ctx, true);
                      },
                      decoration: InputDecoration(
                        labelText: 'Confirm new password',
                        suffixIcon: IconButton(
                          onPressed: () {
                            if (!ctx.mounted) return;
                            setLocal(() => obscureConfirm = !obscureConfirm);
                          },
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'Required';
                        if (t != newCtrl.text.trim())
                          return 'Passwords do not match';
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => safePop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              if (!(formKey.currentState?.validate() ?? false))
                                return;
                              safePop(ctx, true);
                            },
                            child: const Text('Update'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    // ✅ Dispose on next frame (prevents focus lifecycle race during pop animation)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      currentCtrl.dispose();
      newCtrl.dispose();
      confirmCtrl.dispose();

      currentFocus.dispose();
      newFocus.dispose();
      confirmFocus.dispose();
    });

    if (result != true) return;

    final currentPassword = currentCtrl.text.trim();
    final newPassword = newCtrl.text.trim();

    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password updated.')));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Could not change password.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not change password: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    if (user == null) return const Center(child: Text('Not signed in'));

    final profileAsync = ref.watch(userProfileStreamProvider(user.uid));

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (profile) {
        final chronotype = (profile?['chronotype'] as String?) ?? 'Midday';
        final wakeTime = (profile?['wakeTime'] as String?) ?? '07:00';
        final bedTime = (profile?['bedTime'] as String?) ?? '23:00';
        final goal = profile?['goal'] as String?;

        final emailNotifFromDb = profile?['emailNotifications'] as bool?;
        final pushNotifFromDb = profile?['pushNotifications'] as bool?;

        final emailNotif = _emailNotifOverride ?? emailNotifFromDb ?? true;
        final pushNotif = _pushNotifOverride ?? pushNotifFromDb ?? false;

        final displayName = user.displayName ?? 'Guest';

        final providerIds = user.providerData.map((p) => p.providerId).toSet();
        final hasPasswordProvider = providerIds.contains('password');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // header + sign out + divider
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
            const Divider(color: Colors.black, thickness: 1, height: 1),

            Expanded(
              child: SingleChildScrollView(
                primary: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 12.0,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                          child: _profileHeader(
                            displayName: displayName,
                            email: user.email,
                          ),
                        ),
                        _divider(),

                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                          child: Text(
                            'ACCOUNT',
                            style: TextStyle(
                              fontSize: 13,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w600,
                              color: Colors.black45,
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                          child: _SettingsRow(
                            title: 'Chronotype',
                            value: chronotype,
                            onTap: () => _editChronotype(chronotype),
                            leadingWidget: _chronotypeIcon(chronotype),
                            accentColor: Colors.teal,
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: _SettingsRow(
                            title: 'Sleep schedule',
                            value: '$wakeTime  →  $bedTime',
                            onTap: () => _editSleepSchedule(
                              wakeTime: wakeTime,
                              bedTime: bedTime,
                            ),
                            icon: Icons.bedtime_outlined,
                            accentColor: Colors.deepPurple,
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: _SettingsRow(
                            title: 'Goal',
                            value: goal ?? 'Not set',
                            onTap: () => _editGoal(goal),
                            icon: Icons.flag_outlined,
                            accentColor: Colors.orange,
                          ),
                        ),

                        if (_showNotificationsSection) ...[
                          _divider(indent: 16),

                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                            child: Text(
                              'NOTIFICATIONS',
                              style: TextStyle(
                                fontSize: 13,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w600,
                                color: Colors.black45,
                              ),
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                            child: _SimpleCard(
                              gap: 12,
                              children: [
                                _SimpleSwitchRow(
                                  title: 'Email notifications',
                                  value: emailNotif,
                                  onChanged: (v) async {
                                    setState(() => _emailNotifOverride = v);
                                    await _mergeUserData({
                                      'emailNotifications': v,
                                    });
                                  },
                                ),
                                _SimpleSwitchRow(
                                  title: 'Push notifications',
                                  value: pushNotif,
                                  onChanged: (v) async {
                                    setState(() => _pushNotifOverride = v);
                                    await _mergeUserData({
                                      'pushNotifications': v,
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (hasPasswordProvider) ...[
                          _divider(indent: 16),

                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                            child: Text(
                              'SECURITY',
                              style: TextStyle(
                                fontSize: 13,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w600,
                                color: Colors.black45,
                              ),
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                            child: _SimpleActionRow(
                              title: 'Change password',
                              onTap: _openChangePasswordFlow,
                              icon: Icons.lock_outline_rounded,
                              accentColor: Colors.black87,
                            ),
                          ),
                        ],

                        _divider(indent: 16),

                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                          child: Text(
                            'SUPPORT',
                            style: TextStyle(
                              fontSize: 13,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w600,
                              color: Colors.black45,
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                          child: _SimpleActionRow(
                            title: 'Send feedback',
                            onTap: _openFeedbackDialog,
                            icon: Icons.feedback_outlined,
                            accentColor: Colors.teal,
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: _SimpleActionRow(
                            title: 'FAQ',
                            onTap: _openFaq,
                            icon: Icons.help_outline_rounded,
                            accentColor: Colors.indigo,
                          ),
                        ),

                        _divider(),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () async {
                                await _handleDeleteAccount(context, ref);
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text(
                                'Delete my account',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _divider({double indent = 0}) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade200,
      indent: indent,
    );
  }
}

// -----------------------------------------------------------------------------
// Small building blocks (SIMPLE, CLEAN)
// -----------------------------------------------------------------------------

class _SettingsRow extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback? onTap;

  /// Optional: if you pass a widget (like your chronotype svg), it will be used
  /// inside the icon chip. Otherwise we use [icon].
  final Widget? leadingWidget;

  /// Optional fallback icon if [leadingWidget] is null.
  final IconData? icon;

  /// Accent used for rail + chip.
  final Color accentColor;

  const _SettingsRow({
    required this.title,
    required this.value,
    required this.onTap,
    this.leadingWidget,
    this.icon,
    this.accentColor = Colors.teal,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final a = accentColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            // super subtle boundary so it feels "tappable" but still clean
            border: Border.all(color: Colors.grey.shade200),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey.shade50],
            ),
          ),
          child: Row(
            children: [
              // Accent rail
              Container(
                width: 5,
                height: 56,
                decoration: BoxDecoration(
                  color: a.withOpacity(enabled ? 0.85 : 0.25),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(14),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Icon chip
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: a.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: a.withOpacity(0.18)),
                ),
                child: Center(
                  child:
                      leadingWidget ??
                      Icon(
                        icon ?? Icons.tune_rounded,
                        size: 18,
                        color: a.withOpacity(enabled ? 0.95 : 0.5),
                      ),
                ),
              ),
              const SizedBox(width: 12),

              // Texts
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: enabled ? Colors.black87 : Colors.black38,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              // Right side "Edit" pill + chevron
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandableRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  const _ExpandableRow({
    required this.icon,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(icon, color: Colors.black54),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 10),
            // ✅ NO left padding here
            child,
          ],
        ],
      ),
    );
  }
}

class _SimpleCard extends StatelessWidget {
  final List<Widget> children;
  final double gap;

  const _SimpleCard({required this.children, this.gap = 10});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < children.length; i++) ...[
          children[i],
          if (i != children.length - 1) SizedBox(height: gap),
        ],
      ],
    );
  }
}

class _SimpleSwitchRow extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SimpleSwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _SimpleActionRow extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final IconData icon;
  final Color? accentColor;

  const _SimpleActionRow({
    required this.title,
    required this.onTap,
    required this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final a = accentColor ?? Colors.teal;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            // subtle, clean surface
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey.shade50],
            ),
          ),
          child: Row(
            children: [
              // Accent rail
              Container(
                width: 5,
                height: 54,
                decoration: BoxDecoration(
                  color: a.withOpacity(0.9),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(14),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Icon chip
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: a.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: a.withOpacity(0.18)),
                ),
                child: Icon(icon, size: 18, color: a.withOpacity(0.95)),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),

              // "Pill" chevron
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimpleMutedRow extends StatelessWidget {
  final String text;
  const _SimpleMutedRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14.5,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Header sign out button (unchanged)
// -----------------------------------------------------------------------------

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

class _ChronotypeTimeCard extends StatelessWidget {
  final Widget icon;
  final String label;
  final String valueText;
  final VoidCallback? onTap;

  const _ChronotypeTimeCard({
    required this.icon,
    required this.label,
    required this.valueText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = valueText == 'Selected';

    final borderColor = selected
        ? const Color(0xFF4A4B7E)
        : Colors.grey.shade300;
    const iconColor = Color(0xFF4A4B7E);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              blurRadius: 8,
              spreadRadius: 0,
              offset: Offset(0, 4),
              color: Colors.black12,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          children: [
            // Same sizing behavior as TimeCard (28px slot)
            SizedBox(
              height: 28,
              width: 28,
              child: FittedBox(
                fit: BoxFit.contain,
                child: IconTheme(
                  data: const IconThemeData(color: iconColor),
                  child: icon,
                ),
              ),
            ),
            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ exact label style from your onboarding TimeCard
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F1F2D),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // ✅ exact value style from your onboarding TimeCard
                  Text(
                    valueText,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF4A4B7E),
                    ),
                  ),
                ],
              ),
            ),

            selected
                ? const Icon(Icons.check_rounded, color: iconColor)
                : const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _GoalTimeCard extends StatelessWidget {
  final String label;
  final String valueText;
  final bool isSelected;
  final VoidCallback? onTap;

  const _GoalTimeCard({
    required this.label,
    required this.valueText,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? const Color(0xFF4A4B7E)
        : Colors.grey.shade300;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, // ✅ same as time card
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              blurRadius: 8,
              spreadRadius: 0,
              offset: Offset(0, 4),
              color: Colors.black12,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            // Icon bubble similar “time card” feel (but neutral)
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF4A4B7E).withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4A4B7E).withOpacity(0.18),
                ),
              ),
              child: Icon(
                isSelected ? Icons.check_rounded : Icons.flag_outlined,
                size: 18,
                color: const Color(0xFF4A4B7E),
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F1F2D),
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    valueText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4A4B7E), // ✅ same accent as time card
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}
