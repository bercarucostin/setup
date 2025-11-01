// lib/features/energy/screens/add_events.dart
// Add Events: 2-column animated cards.
// History: timeline-style rows; shows only start → end times; centered delete icon.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:setup/features/energy/models/event.dart';
import 'package:setup/features/energy/providers/events_provider.dart';
import 'package:setup/features/energy/controllers/event_view_model.dart';
import 'package:setup/features/firestore/providers/providers.dart';

// ——— Layout tokens ———
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

  Future<_TimeRange?> _pickTimeRange() async {
    TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 10, minute: 0);

    return showModalBottomSheet<_TimeRange?>(
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
                          'Select Time Range',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          onPressed:
                              () => Navigator.of(
                                ctx,
                              ).pop(_TimeRange(start: start, end: end)),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  SizedBox(
                    height: 260,
                    child: Row(
                      children: [
                        Expanded(
                          child: _CupertinoTimePickerColumn(
                            label: 'Start',
                            initial: start,
                            onChanged: (t) => setState(() => start = t),
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: _CupertinoTimePickerColumn(
                            label: 'End',
                            initial: end,
                            onChanged: (t) => setState(() => end = t),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Duration: ${_durationHours(start, end).toStringAsFixed(2)} h',
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _onSelectEvent(Event ev) async {
    final range = await _pickTimeRange();
    if (range == null) return;

    final dur = _durationHours(range.start, range.end);
    if (dur <= 0) {
      _snack(context, 'End must be after start (use next day if needed).');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(eventListProvider.notifier)
          .addEvent(
            eventName: ev.name,
            startHour: range.start.hour,
            duration: dur,
          );
      if (!mounted) return;
      _snack(
        context,
        '“${ev.name}” added ${_hhmm(range.start)} → ${_hhmm(range.end)}',
      );
      ref.invalidate(eventListProvider);
    } catch (e) {
      _snack(context, 'Failed to add event: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ====== UI ================================================================
  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(firestoreUserProvider);

    return profileAsync.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (e, _) =>
              Scaffold(body: Center(child: Text('Could not load profile: $e'))),
      data: (_) {
        final defaultsAsync = ref.watch(defaultEventListProvider);

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.background,
          appBar: AppBar(
            elevation: 0,
            centerTitle: true,
            title: _HeaderTabs(
              index: _tabIndex,
              onChanged: (i) => setState(() => _tabIndex = i),
            ),
            toolbarHeight: 64,
          ),
          body:
              _tabIndex == 0
                  ? defaultsAsync.when(
                    loading:
                        () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (defaults) {
                      if (defaults.isEmpty) {
                        return const Center(child: Text('No default events.'));
                      }

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
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
                              cardHeight = 220;
                            } else if (cellWidth < 230) {
                              cardHeight = 210;
                            } else {
                              cardHeight = 200;
                            }
                            final aspect = cellWidth / cardHeight;

                            return GridView.builder(
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
                                  onTap:
                                      _saving ? null : () => _onSelectEvent(ev),
                                  controller: _borderAnim,
                                );
                              },
                            );
                          },
                        ),
                      );
                    },
                  )
                  : const _HistoryTabBody(),
        );
      },
    );
  }
}

// ============ Header buttons ===============================================
// ============ Header buttons ===============================================
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

        // 👉 No AnimatedContainer; no color tweening.
        Widget addBtn(bool selected) => InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => onChanged(0),
          splashColor: Colors.transparent, // remove splash
          highlightColor: Colors.transparent, // remove highlight flash
          hoverColor: Colors.transparent,
          child: Container(
            height: buttonHeight,
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient:
                  selected
                      ? const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF34D399)],
                      )
                      : null,
              color: selected ? null : Theme.of(context).colorScheme.surface,
              border:
                  selected
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
                color:
                    selected
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
                      color:
                          selected ? const Color(0xFF6366F1) : Colors.black87,
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
      colors:
          boost
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
                      fg:
                          _isBoost
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFB45309),
                      bg:
                          _isBoost
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
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(
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
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color: Colors.black.withOpacity(0.7),
                            height: 1.3,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: effectBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          effectText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: effectFg,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
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

// Boost / Drain pill
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

// Icon tile
class _IconTile extends StatelessWidget {
  final bool boost;
  final String name;
  final IconSpec? iconSpec; // << pass Event.icon

  const _IconTile({required this.boost, required this.name, this.iconSpec});

  @override
  Widget build(BuildContext context) {
    final IconData iconData =
        iconSpec?.toIconData() ?? _iconForEventName(name); // fallback

    final grad =
        boost
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
            offset: Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(iconData, color: Colors.white, size: 26),
    );
  }
}

// ========================= History Tab =====================================

class _HistoryTabBody extends ConsumerWidget {
  const _HistoryTabBody({super.key});

  String _hhmm(double h) {
    final hh = h.floor();
    final mm = ((h - hh) * 60).round();
    return '${(hh % 24).toString().padLeft(2, '0')}:${(mm % 60).toString().padLeft(2, '0')}';
  }

  int _epochDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch ~/ 86400000;

  Future<void> _deleteEvent(WidgetRef ref, {required String eventId}) async {
    final day = _epochDay(DateTime.now()).toString();
    await ref
        .read(eventListProvider.notifier)
        .deleteEvent(epochDay: day, eventId: eventId);
    ref.invalidate(eventListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(eventListProvider);

    return todayAsync.when(
      loading:
          () => const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      error:
          (e, _) =>
              Padding(padding: const EdgeInsets.all(16), child: Text('$e')),
      data: (events) {
        if (events.isEmpty) {
          return const Center(child: Text('No events added yet.'));
        }

        // —— Sort by start time asc (then by name for stability) ——
        final sorted = [...events];
        sorted.sort((a, b) {
          final sa = (a.startHour ?? 0).toDouble();
          final sb = (b.startHour ?? 0).toDouble();
          final cmp = sa.compareTo(sb);
          if (cmp != 0) return cmp;
          return a.name.compareTo(b.name);
        });

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: sorted.length,
          separatorBuilder: (_, __) => const SizedBox(height: 18),
          itemBuilder: (context, i) {
            final ev = sorted[i];
            final start = (ev.startHour ?? 0).toDouble();
            final dur = (ev.duration ?? 0.0);
            final end = (start + dur) % 24.0;

            return _HistoryRow(
              title: ev.name,
              start: _hhmm(start),
              end: _hhmm(end),
              isBoost: ev.booster == true,
              onDelete:
                  ev.id == null
                      ? null
                      : () async => _deleteEvent(ref, eventId: ev.id!),
              isLast: i == sorted.length - 1,
            );
          },
        );
      },
    );
  }
}

// One row in the timeline
class _HistoryRow extends StatelessWidget {
  final String title;
  final String start;
  final String end;
  final bool isBoost;
  final VoidCallback? onDelete;
  final bool isLast;

  const _HistoryRow({
    required this.title,
    required this.start,
    required this.end,
    required this.isBoost,
    required this.onDelete,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    const double leftW = 76.0;
    const double rowMinHeight = 96.0;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: rowMinHeight),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // LEFT TIMELINE + ICON  ----------------------------------------------
          SizedBox(
            width: leftW,
            child: SizedBox(
              height: rowMinHeight,
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.topCenter,
                clipBehavior: Clip.none, // 👈 allow the small badge to overflow
                children: [
                  // vertical line
                  Positioned.fill(
                    top: 6,
                    bottom: isLast ? 28 : 0,
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
                  // main icon tile
                  Positioned(
                    left: 0,
                    top: 0,
                    child: _IconTile(boost: isBoost, name: title),
                  ),
                  // tiny corner badge (nudged inside; no clipping)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color:
                            isBoost
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        isBoost ? Icons.trending_up : Icons.trending_down,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Right card
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.black.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  // Title + times
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color:
                                isBoost
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule, size: 16),
                            const SizedBox(width: 6),
                            _Chip(text: start),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(
                                Icons.arrow_right_alt_rounded,
                                size: 18,
                              ),
                            ),
                            _Chip(text: end),
                            // (no duration pill, per your note)
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Centered delete button
                  SizedBox(
                    height: 44,
                    width: 44,
                    child: Center(
                      child: IconButton(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete',
                        splashRadius: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Tiny rounded chip used for time stamps
class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ==================== Misc helpers =========================================
IconData _iconForEventName(String name) {
  final n = name.toLowerCase();
  if (n.contains('coffee') || n.contains('cafe'))
    return Icons.local_cafe_rounded;
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
  if (n.contains('meditation') || n.contains('mind'))
    return Icons.self_improvement_rounded;
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
            onDateTimeChanged:
                (dt) => onChanged(TimeOfDay(hour: dt.hour, minute: dt.minute)),
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

class _TimeRange {
  final TimeOfDay start;
  final TimeOfDay end;
  const _TimeRange({required this.start, required this.end});
}
