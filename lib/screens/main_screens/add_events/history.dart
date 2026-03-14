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

  String _hhmm(int? hour, int? minute) {
    final hh = hour ?? 0;
    final mm = minute ?? 0;
    return '${(hh % 24).toString().padLeft(2, '0')}:${(mm % 60).toString().padLeft(2, '0')}';
  }

  String _intensityLabel(double? value) {
    final raw = (value ?? 3.0).round();
    final v = raw < 1 ? 1 : (raw > 5 ? 5 : raw);

    if (v <= 2) return 'Light';
    if (v == 3) return 'Moderate';
    return 'Strong';
  }

  Future<void> _deleteEvent(
    WidgetRef ref, {
    required String userId,
    required Event event,
    required int wakeHour,
    required int bedHour,
  }) async {
    final eventId = event.id;
    if (eventId == null) return;

    final logicalDay =
        _logicalCardDayFromCreatedAt(event) ?? dateWokeUp(wakeHour, bedHour);

    final repo = ref.read(eventRepositoryProvider);
    await repo.deleteEvent(
      userId: userId,
      eventId: eventId,
      epochDay: customDateString(logicalDay),
    );

    ref.invalidate(energyInsightsProvider);
    ref.invalidate(todayEventsProvider(userId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(todayEventsProvider(userId));
    final profileAsync = ref.watch(userProfileStreamProvider(userId));

    return profileAsync.when(
      loading: () => const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) =>
          Padding(padding: const EdgeInsets.all(16), child: Text('$e')),
      data: (profile) {
        final wakeHour = profile?['wakeHour'] as int? ?? 0;
        final bedHour = profile?['bedHour'] as int? ?? 0;

        return eventsAsync.when(
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

            final sections = _buildTimelineSections(events, wakeHour);

            return Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),

                      for (final section in sections) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: _TimelineHeaderCard(
                              eventCount: section.totalEvents,
                            ),
                          ),
                        ),

                        const SliverToBoxAdapter(child: SizedBox(height: 8)),

                        for (final daySection in section.actualDaySections) ...[
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _ActualDayHeaderDelegate(
                              day: daySection.actualDay,
                            ),
                          ),

                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  if (index.isOdd) {
                                    return Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: Colors.grey.shade100,
                                      indent: 56,
                                      endIndent: 8,
                                    );
                                  }

                                  final event = daySection.events[index ~/ 2];

                                  return _HistoryRow(
                                    title: event.name,
                                    start: _hhmm(
                                      event.startHour,
                                      event.startMinute,
                                    ),
                                    intensity: _intensityLabel(event.intensity),
                                    isBoost: event.booster,
                                    iconSpec: event.icon,
                                    onDelete: event.id == null
                                        ? null
                                        : () => _deleteEvent(
                                            ref,
                                            userId: userId,
                                            event: event,
                                            wakeHour: wakeHour,
                                            bedHour: bedHour,
                                          ),
                                  );
                                },
                                childCount: daySection.events.isEmpty
                                    ? 0
                                    : daySection.events.length * 2 - 1,
                              ),
                            ),
                          ),
                        ],

                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      ],
                    ],
                  ),
                ),
                Divider(color: Colors.grey.shade300, thickness: 1, height: 1),
              ],
            );
          },
        );
      },
    );
  }
}

class _ActualDaySection {
  final DateTime? actualDay;
  final List<Event> events;

  const _ActualDaySection({required this.actualDay, required this.events});
}

class _TimelineSection {
  final DateTime? logicalDay;
  final List<_ActualDaySection> actualDaySections;

  const _TimelineSection({
    required this.logicalDay,
    required this.actualDaySections,
  });

  int get totalEvents =>
      actualDaySections.fold(0, (sum, s) => sum + s.events.length);
}

List<_TimelineSection> _buildTimelineSections(
  List<Event> events,
  int wakeHour,
) {
  final grouped = <DateTime?, List<Event>>{};

  for (final ev in events) {
    final logicalDay = _logicalCardDayFromCreatedAt(ev);
    grouped.putIfAbsent(logicalDay, () => []).add(ev);
  }

  final logicalDays = grouped.keys.toList()
    ..sort((a, b) {
      if (a == null && b == null) return 0;
      if (a == null) return 1;
      if (b == null) return -1;
      return b.compareTo(a);
    });

  final result = <_TimelineSection>[];

  for (final logicalDay in logicalDays) {
    final rows = [...grouped[logicalDay]!]
      ..sort((a, b) {
        final byTimeline = _timelineSortValueForEvent(
          a,
          wakeHour,
        ).compareTo(_timelineSortValueForEvent(b, wakeHour));

        if (byTimeline != 0) return byTimeline;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    final actualSections = <_ActualDaySection>[];
    DateTime? currentDay;
    List<Event> bucket = [];

    for (final ev in rows) {
      final actualDay = _actualDisplayDayForEvent(
        logicalDay: logicalDay,
        event: ev,
        wakeHour: wakeHour,
      );

      if (!_sameCalendarDay(currentDay, actualDay)) {
        if (bucket.isNotEmpty) {
          actualSections.add(
            _ActualDaySection(
              actualDay: currentDay,
              events: List.unmodifiable(bucket),
            ),
          );
        }
        currentDay = actualDay;
        bucket = [ev];
      } else {
        bucket.add(ev);
      }
    }

    if (bucket.isNotEmpty) {
      actualSections.add(
        _ActualDaySection(
          actualDay: currentDay,
          events: List.unmodifiable(bucket),
        ),
      );
    }

    result.add(
      _TimelineSection(
        logicalDay: logicalDay,
        actualDaySections: actualSections,
      ),
    );
  }

  return result;
}

DateTime? _stripDay(DateTime? dt) {
  if (dt == null) return null;
  return DateTime(dt.year, dt.month, dt.day);
}

DateTime? _logicalCardDayFromCreatedAt(Event event) {
  return _stripDay(event.createdAtDate?.toLocal());
}

int _eventTotalMinutes(Event event) {
  final hour = event.startHour ?? 0;
  final minute = event.startMinute ?? 0;
  return hour * 60 + minute;
}

int _wakeTotalMinutes(int wakeHour) => wakeHour * 60;

int _timelineSortValueForEvent(Event event, int wakeHour) {
  final total = _eventTotalMinutes(event);
  final wakeTotal = _wakeTotalMinutes(wakeHour);
  return total < wakeTotal ? total + 1440 : total;
}

DateTime? _actualDisplayDayForEvent({
  required DateTime? logicalDay,
  required Event event,
  required int wakeHour,
}) {
  if (logicalDay == null) return null;

  final total = _eventTotalMinutes(event);
  final wakeTotal = _wakeTotalMinutes(wakeHour);

  if (total < wakeTotal) {
    return logicalDay.add(const Duration(days: 1));
  }
  return logicalDay;
}

bool _sameCalendarDay(DateTime? a, DateTime? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class _TimelineHeaderCard extends StatelessWidget {
  final int eventCount;

  const _TimelineHeaderCard({required this.eventCount});

  @override
  Widget build(BuildContext context) {
    final muted = Colors.blueGrey.shade600;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        color: Colors.white,
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
            child: Text(
              'Events timeline',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: muted,
              ),
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

class _ActualDayHeaderDelegate extends SliverPersistentHeaderDelegate {
  final DateTime? day;

  const _ActualDayHeaderDelegate({required this.day});

  @override
  double get minExtent => 42;

  @override
  double get maxExtent => 42;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final muted = Colors.blueGrey.shade600;
    final dateLabel = day == null
        ? 'Unknown date'
        : DateFormat('EEE, MMM d').format(day!);

    return SizedBox.expand(
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 2, 22, 2),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
              ),
              boxShadow: overlapsContent
                  ? const [
                      BoxShadow(
                        blurRadius: 8,
                        offset: Offset(0, 2),
                        color: Color(0x06000000),
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFEDE9FE),
                    border: Border.all(color: const Color(0xFFDDD6FE)),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.calendar_today_rounded,
                      size: 11,
                      color: Color(0xFF6D4BCB),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                      color: muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ActualDayHeaderDelegate oldDelegate) {
    return oldDelegate.day != day;
  }
}

class _HistoryRow extends StatelessWidget {
  final String title;
  final String start;
  final String intensity;
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

  @override
  Widget build(BuildContext context) {
    final iconData = iconSpec?.toIconData() ?? _iconForEventName(title);

    return SizedBox(
      height: 64,
      child: Row(
        children: [
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
          Container(
            width: 4,
            height: 46,
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 28,
            child: Center(
              child: Icon(iconData, size: 23, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 10),
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
          _IntensityLabelPill(label: intensity),
          const SizedBox(width: 6),
          SizedBox(
            width: 34,
            height: 34,
            child: IconButton(
              onPressed: onDelete,
              tooltip: 'Delete',
              splashRadius: 18,
              padding: EdgeInsets.zero,
              icon: const Icon(
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
  if (n.contains('nap') || n.contains('sleep')) {
    return Icons.bedtime_rounded;
  }
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
