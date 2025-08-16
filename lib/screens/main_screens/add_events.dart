// lib/features/energy/screens/add_events.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:setup/features/energy/models/event.dart';
import 'package:setup/features/energy/providers/events_provider.dart'; // defaultEventsProvider, eventListProvider, eventRepositoryProvider
import 'package:setup/features/energy/controllers/event_view_model.dart'; // for addEvent on eventListProvider.notifier
import 'package:setup/features/auth/providers/providers.dart'; // firebaseUserProvider
import 'package:setup/features/firestore/providers/providers.dart'; // firestoreUserProvider (gating)

class AddEventsScreen extends ConsumerStatefulWidget {
  const AddEventsScreen({super.key});

  @override
  ConsumerState<AddEventsScreen> createState() => _AddEventsScreenState();
}

class _AddEventsScreenState extends ConsumerState<AddEventsScreen> {
  TimeOfDay? _start;
  TimeOfDay? _end;
  bool _saving = false;

  // Helpers
  int _epochDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch ~/ 86400000;

  double _durationHours(TimeOfDay start, TimeOfDay end) {
    final s = start.hour + start.minute / 60.0;
    final e = end.hour + end.minute / 60.0;
    final d = ((e - s) % 24 + 24) % 24;
    return d;
  }

  String _hhmmFromHourDouble(double h) {
    final hh = h.floor();
    final mm = ((h - hh) * 60).round();
    final h2 = hh % 24;
    final m2 = mm % 60;
    return '${h2.toString().padLeft(2, '0')}:${m2.toString().padLeft(2, '0')}';
  }

  Future<void> _pickStart() async {
    final res = await showTimePicker(
      context: context,
      initialTime: _start ?? const TimeOfDay(hour: 9, minute: 0),
      initialEntryMode: TimePickerEntryMode.inputOnly,
      helpText: 'Select start time',
    );
    if (mounted && res != null) setState(() => _start = res);
  }

  Future<void> _pickEnd() async {
    final res = await showTimePicker(
      context: context,
      initialTime: _end ?? const TimeOfDay(hour: 10, minute: 0),
      initialEntryMode: TimePickerEntryMode.inputOnly,
      helpText: 'Select end time',
    );
    if (mounted && res != null) setState(() => _end = res);
  }

  Future<void> _addEventByName(String eventName) async {
    if (_start == null || _end == null) {
      _snack('Please pick start and end times first.');
      return;
    }
    final startHour = _start!.hour; // 0..23
    final dur = _durationHours(_start!, _end!);
    if (dur <= 0) {
      _snack('End must be after start (use next day if needed).');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(eventListProvider.notifier)
          .addEvent(eventName: eventName, startHour: startHour, duration: dur);
      if (!mounted) return;
      _snack('Event added ✅');
      // optional: refresh today list if yours is one-shot
      ref.invalidate(eventListProvider);
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to add event: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteEvent({required String eventId}) async {
    final user = ref.read(firebaseUserProvider);
    if (user == null) return;
    final day = _epochDay(DateTime.now()).toString();
    await ref
        .read(eventListProvider.notifier)
        .deleteEvent(epochDay: day, eventId: eventId);
    // If eventListProvider is one-shot, force re-fetch. If it's a stream, this is harmless.
    ref.invalidate(eventListProvider);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    // Gate on auth + profile to avoid permission-denied
    final user = ref.watch(firebaseUserProvider);
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to add events.')),
      );
    }
    final profileAsync = ref.watch(firestoreUserProvider);
    return profileAsync.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (e, st) =>
              Scaffold(body: Center(child: Text('Could not load profile: $e'))),
      data: (_) {
        final defaultsAsync = ref.watch(defaultEventListProvider);
        final todayAsync = ref.watch(eventListProvider);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Add Events'),
            actions: [
              IconButton(
                tooltip: 'Refresh defaults',
                onPressed: () => ref.invalidate(defaultEventListProvider),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: Column(
            children: [
              // Time pickers
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _TimeTile(
                        label: 'Start',
                        value: _start?.format(context) ?? '--:--',
                        onTap: _pickStart,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TimeTile(
                        label: 'End',
                        value: _end?.format(context) ?? '--:--',
                        onTap: _pickEnd,
                      ),
                    ),
                  ],
                ),
              ),
              if (_start != null && _end != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Duration: ${_durationHours(_start!, _end!).toStringAsFixed(2)} h',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              const SizedBox(height: 8),
              const Divider(height: 1),

              // Defaults list
              Expanded(
                child: defaultsAsync.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('Error: $e')),
                  data: (defaults) {
                    if (defaults.isEmpty) {
                      return const Center(
                        child: Text('No default events found.'),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: defaults.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final ev = defaults[i];
                        return _EventCard(
                          event: ev,
                          disabled: _saving,
                          onAdd: () => _addEventByName(ev.name),
                        );
                      },
                    );
                  },
                ),
              ),

              // Today's events (bottom)
              const Divider(height: 1),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Today's events",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              todayAsync.when(
                loading:
                    () => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                error:
                    (e, st) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error loading today’s events: $e'),
                    ),
                data: (events) {
                  if (events.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text('No events added yet.'),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final ev = events[i];
                      final start = (ev.startHour ?? 0).toDouble();
                      final dur = (ev.duration ?? 0.0);
                      final end = (start + dur) % 24.0;

                      final timeLabel =
                          '${_hhmmFromHourDouble(start)} → ${_hhmmFromHourDouble(end)}'
                          '  (${dur.toStringAsFixed(2)}h)';

                      return ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.black12),
                        ),
                        title: Text(ev.name),
                        subtitle: Text(timeLabel),
                        trailing: IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline),
                          onPressed:
                              (ev.id == null)
                                  ? null
                                  : () async {
                                    await _deleteEvent(eventId: ev.id!);
                                  },
                        ),
                        tileColor: Colors.white,
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _TimeTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(value, style: const TextStyle(color: Colors.black87)),
            const SizedBox(width: 6),
            const Icon(Icons.access_time, size: 18),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final bool disabled;
  final VoidCallback onAdd;

  const _EventCard({
    required this.event,
    required this.disabled,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final tailEU =
        event.tailEffect >= 0
            ? '+${event.tailEffect.toStringAsFixed(0)}'
            : event.tailEffect.toStringAsFixed(0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        title: Text(
          event.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Main: ${event.initialDuration}h • +${event.initialEffect.toStringAsFixed(0)} EU'
          '  |  Tail: ${event.tailDuration}h • $tailEU EU',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: ElevatedButton.icon(
          onPressed: disabled ? null : onAdd,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(84, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}
