import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_flow/features/energy/models/event.dart';
import 'package:peak_flow/features/energy/providers/energy_providers.dart';
import 'package:peak_flow/features/energy/providers/event_providers.dart';

class HistoryTabBody extends ConsumerWidget {
  final String userId;
  const HistoryTabBody({super.key, required this.userId});

  String _hhmm(double h) {
    final hh = h.floor();
    final mm = ((h - hh) * 60).round();
    return '${(hh % 24).toString().padLeft(2, '0')}:${(mm % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _deleteEvent(
    WidgetRef ref, {
    required String userId,
    required String eventId,
  }) async {
    final repo = ref.read(eventRepositoryProvider);
    await repo.deleteEvent(
      userId: userId,
      eventId: eventId,
      epochDay: repo.todayEpochDayForDeletes(),
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

        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: events.length,
                separatorBuilder: (_, __) => const SizedBox(height: 18),
                itemBuilder: (context, i) {
                  final ev = events[i];
                  final start = (ev.startHour ?? 0).toDouble();
                  final dur = (ev.duration ?? 0.0);
                  final end = (start + dur) % 24.0;

                  return _HistoryRow(
                    title: ev.name,
                    start: _hhmm(start),
                    end: _hhmm(end),
                    isBoost: ev.booster == true,
                    onDelete: ev.id == null
                        ? null
                        : () => _deleteEvent(
                            ref,
                            userId: userId,
                            eventId: ev.id!,
                          ),
                    isLast: i == events.length - 1,
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
          SizedBox(
            width: leftW,
            child: SizedBox(
              height: rowMinHeight,
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.topCenter,
                clipBehavior: Clip.none,
                children: [
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
                  Positioned(
                    left: 0,
                    top: 0,
                    child: _IconTile(boost: isBoost, name: title),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: isBoost
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: isBoost
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
                          ],
                        ),
                      ],
                    ),
                  ),
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

class _IconTile extends StatelessWidget {
  final bool boost;
  final String name;
  final IconSpec? iconSpec;

  // ignore: unused_element_parameter
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
