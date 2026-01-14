import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watt/features/auth/providers/providers.dart'; // firebaseAuthProvider
import 'package:watt/features/energy/models/event.dart';
import 'package:watt/features/energy/providers/energy_providers.dart';
import 'package:watt/features/energy/providers/event_providers.dart';
import 'package:watt/screens/main_screens/add_events/history.dart';
import 'package:watt/utils/utils.dart';

const double _rCard = 18;
const double _pad = 10;

class AddEventsScreen extends ConsumerStatefulWidget {
  const AddEventsScreen({super.key});

  @override
  ConsumerState<AddEventsScreen> createState() => _AddEventsScreenState();
}

class _AddEventsScreenState extends ConsumerState<AddEventsScreen>
    with SingleTickerProviderStateMixin {
  int _tabIndex = 0;
  bool _saving = false;

  late final AnimationController _borderAnim = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _borderAnim.dispose();
    super.dispose();
  }

  // ====== Helpers ===========================================================
  double _durationHours(TimeOfDay start, TimeOfDay end) {
    final s = start.hour + start.minute / 60.0;
    final e = end.hour + end.minute / 60.0;
    final d = ((e - s) % 24 + 24) % 24;
    return d;
  }

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<_TimeConfig?> _pickTimeConfig() async {
    final now = DateTime.now();
    TimeOfDay startTime = TimeOfDay(hour: now.hour, minute: 0);
    int intensity = 5; // 1-10 range, default to middle

    return showModalBottomSheet<_TimeConfig?>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _CupertinoSheet(
          child: StatefulBuilder(
            builder: (ctx, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          onPressed: () => Navigator.of(ctx).pop(null),
                          child: const Text('Cancel'),
                        ),
                        const Spacer(),
                        Text(
                          'Select Start Time & Intensity',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          onPressed: () => Navigator.of(ctx).pop(
                            _TimeConfig(
                              startTime: startTime,
                              intensity: intensity,
                            ),
                          ),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  SizedBox(
                    height: 150,
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      initialDateTime: DateTime(
                        2000,
                        1,
                        1,
                        startTime.hour,
                        startTime.minute,
                      ),
                      use24hFormat: true,
                      onDateTimeChanged: (DateTime newDateTime) {
                        setState(() {
                          startTime = TimeOfDay(
                            hour: newDateTime.hour,
                            minute: newDateTime.minute,
                          );
                        });
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  SizedBox(
                    height: 120,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Intensity: $intensity / 10',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          value: intensity.toDouble(),
                          min: 1,
                          max: 10,
                          divisions: 9,
                          label: '$intensity',
                          onChanged: (val) =>
                              setState(() => intensity = val.toInt()),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '1',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                '10',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _onSelectEvent(String uid, Event ev) async {
    final config = await _pickTimeConfig();
    if (config == null) return;

    setState(() => _saving = true);
    try {
      // Fetch user profile to get wake/bed hours for dateWokeUp calculation
      final profile = await ref.read(userProfileStreamProvider(uid).future);
      if (profile == null) {
        _snack(context, 'User profile not found');
        return;
      }

      final wakeHour = profile['wakeHour'] as int?;
      final bedHour = profile['bedHour'] as int?;
      if (wakeHour == null || bedHour == null) {
        _snack(context, 'Wake/bed hours not configured');
        return;
      }

      final today = dateWokeUp(wakeHour, bedHour);
      final repo = ref.read(eventRepositoryProvider);

      await repo.addEventFromTemplate(
        userId: uid,
        today: today,
        template: ev,
        startHour: config.startTime.hour,
        intensity: config.intensity.toDouble(),
      );

      if (!mounted) return;
      _snack(
        context,
        '"${ev.name}" added at ${_hhmm(config.startTime)} (intensity: ${config.intensity}/10)',
      );
      // No invalidate needed: History uses a stream.
      // ✅ force Insights to recompute
      ref.invalidate(energyInsightsProvider);
    } catch (e) {
      _snack(context, 'Failed to add event: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ====== UI ================================================================
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    final defaultEvents = ref.watch(defaultEventsProvider);
    // print(defaultEvents);
    // final icon = Icons.sports; // IconData
    // print('decimal: ${icon.codePoint}');

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0, // ✅ stops the scroll highlight
        backgroundColor: Colors.transparent, // or your bg color
        surfaceTintColor: Colors.transparent, // ✅ stops M3 tint
        shadowColor: Colors.transparent,
        forceMaterialTransparency: true, // ✅ keeps it truly transparent
        centerTitle: true,
        title: _HeaderTabs(
          index: _tabIndex,
          onChanged: (i) => setState(() => _tabIndex = i),
        ),
        toolbarHeight: 64,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: Colors.black, thickness: 1, height: 1),
        ),
      ),
      body: _tabIndex == 0
          ? defaultEvents.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (defaults) {
                if (defaults.isEmpty) {
                  return const Center(
                    child: Text('No default events. We are working on it!'),
                  );
                }

                return Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const columns = 2;
                            const gap = 12.0;
                            final width = constraints.maxWidth;
                            final cellWidth =
                                (width - (columns - 1) * gap) / columns;

                            double cardHeight;
                            if (cellWidth < 170) {
                              cardHeight = 230;
                            } else if (cellWidth < 200) {
                              cardHeight = 200;
                            } else if (cellWidth < 230) {
                              cardHeight = 210;
                            } else {
                              cardHeight = 200;
                            }
                            final aspect = cellWidth / cardHeight;

                            return GridView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 12.0,
                              ),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisSpacing: gap,
                                    crossAxisSpacing: gap,
                                    childAspectRatio: aspect,
                                  ),
                              itemCount: defaults.length,
                              itemBuilder: (_, i) {
                                final ev = defaults[i];
                                return _EventCard(
                                  event: ev,
                                  onTap: _saving
                                      ? null
                                      : () => _onSelectEvent(user.uid, ev),
                                  controller: _borderAnim,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    Divider(
                      color: Colors.grey.shade300,
                      thickness: 1,
                      height: 1,
                    ),
                  ],
                );
              },
            )
          : HistoryTabBody(userId: user.uid),
    );
  }
}

// ============ Header tabs ====================================================
class _HeaderTabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _HeaderTabs({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final addSelected = index == 0;
    final histSelected = index == 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final rowMax = constraints.maxWidth;
        final buttonHeight = rowMax < 420 ? 40.0 : 44.0;
        final padH = rowMax < 420 ? 12.0 : 18.0;
        final iconSize = rowMax < 420 ? 18.0 : 20.0;

        Widget addBtn(bool selected) => InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => onChanged(0),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Container(
            height: buttonHeight,
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: selected
                  ? const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF34D399)],
                    )
                  : null,
              color: selected ? null : Theme.of(context).colorScheme.surface,
              border: selected
                  ? null
                  : Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withOpacity(0.6),
                    ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add,
                  size: iconSize,
                  color: selected ? Colors.white : Colors.black87,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Add Events',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        Widget histBtn(bool selected) => InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => onChanged(1),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Container(
            height: buttonHeight,
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: selected
                    ? const Color(0xFF6366F1)
                    : Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withOpacity(0.6),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: iconSize,
                  color: selected ? const Color(0xFF6366F1) : Colors.black87,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'History',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected
                          ? const Color(0xFF6366F1)
                          : Colors.black87,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        return Row(
          children: [
            Expanded(child: addBtn(addSelected)),
            const SizedBox(width: 8),
            Expanded(child: histBtn(histSelected)),
          ],
        );
      },
    );
  }
}

// ========================= Card (Add tab) ===================================
class _EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;
  final AnimationController controller;

  const _EventCard({required this.event, required this.controller, this.onTap});

  bool get _isBoost => event.booster == true;

  SweepGradient _borderGradient(bool boost, double angle) {
    return SweepGradient(
      startAngle: 0,
      endAngle: 6.28318,
      colors: boost
          ? const [
              Color(0xFF6366F1),
              Color(0xFF60A5FA),
              Color(0xFF34D399),
              Color(0xFF6366F1),
            ]
          : const [
              Color(0xFFFB923C),
              Color(0xFFF97316),
              Color(0xFFF43F5E),
              Color(0xFFFB923C),
            ],
      transform: GradientRotation(angle),
    );
  }

  Color _surface(BuildContext context) {
    final base = Theme.of(context).colorScheme.surface;
    return Color.alphaBlend(const Color(0x0A000000), base);
  }

  (String, Color, Color) _effectPill(num value) {
    final isPos = value >= 0;
    final txt =
        '${isPos ? '+' : '−'}${value.abs().toStringAsFixed(0)} Energy Units';
    final fg = isPos ? const Color(0xFF2563EB) : const Color(0xFFB45309);
    final bg = isPos ? const Color(0xFFE0EAFF) : const Color(0xFFFFEDD5);
    return (txt, fg, bg);
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final (effectText, effectFg, effectBg) = _effectPill(event.initialEffect);

    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final angle = controller.value * 6.28318;
        final gradient = _borderGradient(_isBoost, angle);

        return Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(_rCard),
          ),
          child: Container(
            margin: const EdgeInsets.all(1.2),
            decoration: BoxDecoration(
              color: _surface(context),
              borderRadius: BorderRadius.circular(_rCard - 1),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(_rCard - 1),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(_pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BoostDrainPill(
                      boost: _isBoost,
                      fg: _isBoost
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFB45309),
                      bg: _isBoost
                          ? const Color(0xFFE8F0FF)
                          : const Color(0xFFFFF3E6),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _IconTile(
                          boost: _isBoost,
                          name: event.name,
                          iconSpec: event.icon,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            event.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          event.description,
                          softWrap: true,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.black.withOpacity(0.7),
                                height: 1.3,
                                fontSize: 11.5,
                              ),
                        ),
                      ),
                    ),
                    // const SizedBox(height: 8),
                    // Align(
                    //   alignment: Alignment.bottomLeft,
                    //   child: Container(
                    //     padding: const EdgeInsets.symmetric(
                    //       horizontal: 10,
                    //       vertical: 6,
                    //     ),
                    //     decoration: BoxDecoration(
                    //       color: effectBg,
                    //       borderRadius: BorderRadius.circular(999),
                    //     ),
                    //     child: Text(
                    //       effectText,
                    //       maxLines: 1,
                    //       overflow: TextOverflow.ellipsis,
                    //       style: TextStyle(
                    //         color: effectFg,
                    //         fontWeight: FontWeight.w700,
                    //         fontSize: 12,
                    //       ),
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BoostDrainPill extends StatelessWidget {
  final bool boost;
  final Color fg;
  final Color bg;
  const _BoostDrainPill({
    required this.boost,
    required this.fg,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final icon = boost ? Icons.bolt_rounded : Icons.opacity_rounded;
    final text = boost ? 'Boost' : 'Drain';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final bool boost;
  final String name;
  final IconSpec? iconSpec;

  const _IconTile({required this.boost, required this.name, this.iconSpec});

  @override
  Widget build(BuildContext context) {
    final IconData iconData = iconSpec?.toIconData() ?? _iconForEventName(name);

    final grad = boost
        ? const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFF97316), Color(0xFFF43F5E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: grad,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(iconData, color: Colors.white, size: 26),
    );
  }
}

// ==================== Misc helpers =========================================
IconData _iconForEventName(String name) {
  final n = name.toLowerCase();
  if (n.contains('coffee') || n.contains('cafe')) {
    return Icons.local_cafe_rounded;
  }
  if (n.contains('meal') ||
      n.contains('lunch') ||
      n.contains('breakfast') ||
      n.contains('dinner')) {
    return Icons.restaurant_rounded;
  }
  if (n.contains('nap') || n.contains('sleep')) return Icons.bedtime_rounded;
  if (n.contains('gym') ||
      n.contains('workout') ||
      n.contains('sport') ||
      n.contains('work out')) {
    return Icons.fitness_center_rounded;
  }
  if (n.contains('walk')) return Icons.directions_walk_rounded;
  if (n.contains('focus') || n.contains('work')) return Icons.task_rounded;
  if (n.contains('meditation') || n.contains('mind')) {
    return Icons.self_improvement_rounded;
  }
  return Icons.blur_circular_rounded;
}

// ================= Bottom Sheet bits =======================================
class _CupertinoTimePickerColumn extends StatelessWidget {
  final String label;
  final TimeOfDay initial;
  final ValueChanged<TimeOfDay> onChanged;
  const _CupertinoTimePickerColumn({
    required this.label,
    required this.initial,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final init = DateTime(
      now.year,
      now.month,
      now.day,
      initial.hour,
      initial.minute,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        Expanded(
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            initialDateTime: init,
            use24hFormat: true,
            onDateTimeChanged: (dt) =>
                onChanged(TimeOfDay(hour: dt.hour, minute: dt.minute)),
          ),
        ),
      ],
    );
  }
}

class _CupertinoSheet extends StatelessWidget {
  final Widget child;
  const _CupertinoSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _TimeConfig {
  final TimeOfDay startTime;
  final int intensity; // 1-10
  const _TimeConfig({required this.startTime, required this.intensity});
}
