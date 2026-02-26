import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Watt/features/auth/providers/providers.dart';
import 'package:Watt/features/energy/models/event.dart';
import 'package:Watt/features/energy/providers/energy_providers.dart';
import 'package:Watt/features/energy/providers/event_providers.dart';
import 'package:Watt/utils/utils.dart';
import 'package:intl/intl.dart';

class HistoryTabBody extends ConsumerWidget {
  final String userId;
  const HistoryTabBody({super.key, required this.userId});

  String _hhmm(double h) {
    final hh = h.floor();
    final mm = ((h - hh) * 60).round();
    return '${(hh % 24).toString().padLeft(2, '0')}:${(mm % 60).toString().padLeft(2, '0')}';
  }

  String _intensityLabel(double? value) {
    final raw = (value ?? 3.0).round(); // 3 = baseline
    final v = raw < 1 ? 1 : (raw > 5 ? 5 : raw);

    if (v <= 2) return 'Light';
    if (v == 3) return 'Moderate';
    return 'Strong';
  }

  Future<void> _deleteEvent(
    WidgetRef ref, {
    required String userId,
    required String eventId,
  }) async {
    final profile = await ref.read(userProfileStreamProvider(userId).future);
    if (profile == null) return;

    final wakeHour = profile['wakeHour'] as int?;
    final bedHour = profile['bedHour'] as int?;
    if (wakeHour == null || bedHour == null) return;

    final today = dateWokeUp(wakeHour, bedHour);

    final repo = ref.read(eventRepositoryProvider);
    await repo.deleteEvent(
      userId: userId,
      eventId: eventId,
      epochDay: customDateString(today),
    );
    ref.invalidate(energyInsightsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todayEventsProvider(userId));

    return todayAsync.when(
      loading: () => const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) =>
          Padding(padding: const EdgeInsets.all(16), child: Text('$e')),
      data: (events) {
        if (events.isEmpty) {
          return const Center(child: Text('No events added yet.'));
        }

        // Sort by createdAt (newest first), nulls last
        final sorted = [...events]
          ..sort((a, b) {
            final aDate = a.createdAtDate?.toLocal();
            final bDate = b.createdAtDate?.toLocal();

            if (aDate == null && bDate == null) {
              return (a.startHour ?? 0).compareTo(b.startHour ?? 0);
            }
            if (aDate == null) return 1; // nulls last
            if (bDate == null) return -1;

            final byCreated = bDate.compareTo(aDate); // newest first
            if (byCreated != 0) return byCreated;

            // Tie-breaker
            return (a.startHour ?? 0).compareTo(b.startHour ?? 0);
          });

        // Group by createdAt calendar day
        final grouped = <DateTime?, List<Event>>{};
        for (final ev in sorted) {
          final dt = ev.createdAtDate?.toLocal();
          final dayKey = dt == null
              ? null
              : DateTime(dt.year, dt.month, dt.day);
          grouped.putIfAbsent(dayKey, () => []).add(ev);
        }

        // Sort group keys (newest day first, null last)
        final dayKeys = grouped.keys.toList()
          ..sort((a, b) {
            if (a == null && b == null) return 0;
            if (a == null) return 1;
            if (b == null) return -1;
            return b.compareTo(a); // newest day first
          });

        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                itemCount: dayKeys.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final day = dayKeys[i];
                  final dayEvents = grouped[day]!;

                  return _HistoryDayCard(
                    day: day,
                    events: dayEvents,
                    hhmm: _hhmm,
                    intensityLabel: _intensityLabel,
                    onDeleteEvent: (eventId) async {
                      await _deleteEvent(ref, userId: userId, eventId: eventId);
                    },
                  );
                },
              ),
            ),
            Divider(color: Colors.grey.shade300, thickness: 1, height: 1),
          ],
        );
      },
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  final int eventCount;
  final DateTime? displayDate;

  const _HistoryHeader({required this.eventCount, this.displayDate});

  @override
  Widget build(BuildContext context) {
    final muted = Colors.blueGrey.shade600;
    final date = displayDate ?? DateTime.now();
    final dateLabel = DateFormat('EEE, MMM d').format(date); // Mon, Feb 22

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEDE9FE),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: const Center(
              child: Icon(
                Icons.bolt_rounded,
                size: 15,
                color: Color(0xFF6D4BCB),
              ),
            ),
          ),
          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today · $dateLabel',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Events timeline',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event, size: 14, color: Colors.blueGrey.shade500),
                const SizedBox(width: 6),
                Text(
                  '$eventCount',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final String title;
  final String start;
  final String intensity; // Light / Moderate / Strong
  final bool isBoost;
  final IconSpec? iconSpec;
  final VoidCallback? onDelete;

  const _HistoryRow({
    required this.title,
    required this.start,
    required this.intensity,
    required this.isBoost,
    required this.iconSpec,
    required this.onDelete,
  });

  Color get _accent =>
      isBoost ? const Color(0xFF3F51D1) : const Color(0xFFF05A28);

  double _segmentWidth(String label) {
    switch (label.toLowerCase()) {
      case 'light':
        return 24;
      case 'moderate':
        return 38;
      case 'strong':
        return 54;
      default:
        return 38;
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconData = iconSpec?.toIconData() ?? _iconForEventName(title);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          // Tighter time column (was too wide)
          SizedBox(
            width: 56,
            child: Text(
              start,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.blueGrey.shade500,
                letterSpacing: 0.2,
              ),
            ),
          ),

          // Vertical accent bar (closer to time now)
          Container(
            width: 4,
            height: 46,
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),

          const SizedBox(width: 12),

          // Event icon (same icon system)
          SizedBox(
            width: 28,
            child: Center(
              child: Icon(iconData, size: 23, color: Colors.black87),
            ),
          ),

          const SizedBox(width: 10),

          // Title
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF202124),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Intensity line
          _IntensityLabelPill(label: intensity),

          const SizedBox(width: 6),

          // Delete icon (kept on the right)
          SizedBox(
            width: 34,
            height: 34,
            child: IconButton(
              onPressed: onDelete,
              tooltip: 'Delete',
              splashRadius: 18,
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.delete_forever_rounded,
                size: 18,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntensityLabelPill extends StatelessWidget {
  final String label;
  const _IntensityLabelPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = _intensityLabelColors(label);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: colors.fg,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _LabelColors {
  final Color bg;
  final Color fg;
  final Color border;

  const _LabelColors({
    required this.bg,
    required this.fg,
    required this.border,
  });
}

_LabelColors _intensityLabelColors(String label) {
  switch (label.toLowerCase()) {
    case 'light':
      return const _LabelColors(
        bg: Color(0xFFF3F4F6),
        fg: Color(0xFF4B5563),
        border: Color(0xFFE5E7EB),
      );
    case 'moderate':
      return const _LabelColors(
        bg: Color(0xFFEDE9FE),
        fg: Color(0xFF6D28D9),
        border: Color(0xFFDDD6FE),
      );
    case 'strong':
      return const _LabelColors(
        bg: Color(0xFFDDD6FE),
        fg: Color(0xFF5B21B6),
        border: Color(0xFFC4B5FD),
      );
    default:
      return const _LabelColors(
        bg: Color(0xFFF3F4F6),
        fg: Color(0xFF4B5563),
        border: Color(0xFFE5E7EB),
      );
  }
}

// ==================== Misc helpers =========================================
IconData _iconForEventName(String name) {
  final n = name.toLowerCase();

  if (n.contains('alcohol') || n.contains('wine') || n.contains('beer')) {
    return Icons.wine_bar_rounded;
  }
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

class _HistoryDayCard extends StatelessWidget {
  final DateTime? day;
  final List<Event> events;
  final String Function(double) hhmm;
  final String Function(double?) intensityLabel;
  final Future<void> Function(String eventId) onDeleteEvent;

  const _HistoryDayCard({
    required this.day,
    required this.events,
    required this.hhmm,
    required this.intensityLabel,
    required this.onDeleteEvent,
  });

  String _dayTitle(DateTime? d) {
    if (d == null) return 'Unknown date';

    final now = DateTime.now();
    if (DateUtils.isSameDay(d, now)) {
      return 'Today · ${DateFormat('EEE, MMM d').format(d)}';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (DateUtils.isSameDay(d, yesterday)) {
      return 'Yesterday · ${DateFormat('EEE, MMM d').format(d)}';
    }

    return DateFormat('EEE, MMM d').format(d);
  }

  @override
  Widget build(BuildContext context) {
    // Inside each day-card, sort by timeline hour (nice for display)
    final rows = [...events]
      ..sort((a, b) {
        final byHour = (a.startHour ?? 0).compareTo(b.startHour ?? 0);
        if (byHour != 0) return byHour;

        final aDate = a.createdAtDate;
        final bDate = b.createdAtDate;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });

    final muted = Colors.blueGrey.shade600;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 2),
            color: Color(0x08000000),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header (per day)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFEDE9FE),
                    border: Border.all(color: const Color(0xFFDDD6FE)),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.bolt_rounded,
                      size: 15,
                      color: Color(0xFF6D4BCB),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _dayTitle(day),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Events timeline',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event,
                        size: 14,
                        color: Colors.blueGrey.shade500,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${rows.length}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(color: Colors.grey.shade200, height: 1, thickness: 1),

          // Rows
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Column(
              children: [
                for (int i = 0; i < rows.length; i++) ...[
                  _HistoryRow(
                    title: rows[i].name,
                    start: hhmm((rows[i].startHour ?? 0).toDouble()),
                    intensity: intensityLabel(rows[i].intensity),
                    isBoost: rows[i].booster == true,
                    iconSpec: rows[i].icon,
                    onDelete: rows[i].id == null
                        ? null
                        : () => onDeleteEvent(rows[i].id!),
                  ),
                  if (i != rows.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.grey.shade100,
                      indent: 56,
                      endIndent: 8,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
