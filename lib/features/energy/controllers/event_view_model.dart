// lib/features/energy/energy_view_model.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setup/features/auth/providers/providers.dart';
import 'package:setup/features/firestore/providers/providers.dart';
import 'package:setup/features/energy/models/event.dart';
import 'package:setup/features/energy/repository/event_repository.dart';

/// Provides the Firestore-backed EnergyRepository
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final firestoreRepo = ref.read(firestoreRepositoryProvider);
  return EventRepository(firestoreRepo);
});

class EventNotifier extends AsyncNotifier<List<Event>> {
  @override
  Future<List<Event>> build() async {
    final user = await ref.watch(signedInUserProvider.future);
    // Fetch authenticated user info
    final repo = ref.read(eventRepositoryProvider);

    // Load user-specific events
    return repo.fetchUserEventsForToday(user.uid);
  }

  /// Explicit refresh of the Events
  Future<void> refreshEvents() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  /// Persist new event to Firestore
  Future<void> addEvent({
    required String eventName,
    required int startHour,
    required double duration,
  }) async {
    final user = await ref.watch(signedInUserProvider.future);
    if (user == null) {
      throw StateError('No user logged in.');
    }
    if (startHour < 0 || startHour >= 24) {
      throw RangeError('Start hour must be between 0 and 23');
    }
    if (duration <= 0) {
      throw RangeError('Duration must be greater than 0');
    }
    final repo = ref.read(eventRepositoryProvider);
    final template = await repo.fetchDefaultEvent(eventName);
    if (template == null) {
      throw StateError('Default event not found: $eventName');
    }
    template.startHour = startHour;
    template.duration = duration;
    await repo.saveEvent(user.uid, template);
    refreshEvents();
  }

  Future<void> deleteEvent({
    required String epochDay,
    required String eventId,
  }) async {
    final user = await ref.watch(signedInUserProvider.future);
    if (user == null) {
      throw StateError('No user logged in.');
    }
    final repo = ref.read(eventRepositoryProvider);
    await repo.deleteEvent(user.uid, eventId, epochDay);
    refreshEvents();
  }

  int hour0to23(TimeOfDay t) => t.hour;

  /// Duration in hours from [start] → [end], wrapping across midnight if needed.
  double durationHours(TimeOfDay start, TimeOfDay end) {
    final s = start.hour + start.minute / 60.0;
    final e = end.hour + end.minute / 60.0;
    final d = ((e - s) % 24 + 24) % 24;
    return d == 0 ? 24.0 : d; // treat equal times as 24h block (optional)
  }

  /// Convenience: add event from two TimeOfDays.
  Future<void> addEventFromPicker({
    required String eventName,
    required TimeOfDay start,
    required TimeOfDay end,
  }) async {
    await addEvent(
      eventName: eventName,
      startHour: hour0to23(start),
      duration: durationHours(start, end),
    );
  }
}

class DefaultEventNotifier extends AsyncNotifier<List<Event>> {
  @override
  Future<List<Event>> build() async {
    final repo = ref.read(eventRepositoryProvider);
    return repo.fetchAllDefaultEvents();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}
