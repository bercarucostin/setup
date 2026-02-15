import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Watt/features/auth/providers/providers.dart';
import 'package:Watt/features/energy/models/event.dart';
import 'package:Watt/features/energy/repositories/event_repository.dart';
import 'package:Watt/features/firestore/providers/providers.dart'; // firestoreRepositoryProvider
import 'package:Watt/utils/utils.dart';

/// 1) Repository provider
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final firestoreRepo = ref.read(firestoreRepositoryProvider);
  return EventRepository(firestoreRepo);
});

/// 2) Defaults list (shared collection)
final defaultEventsProvider = FutureProvider.autoDispose<List<Event>>((
  ref,
) async {
  final repo = ref.read(eventRepositoryProvider);
  return repo.fetchAllDefaultEvents();
});

/// 3) Today events stream (per user)
final todayEventsProvider = StreamProvider.autoDispose
    .family<List<Event>, String>((ref, uid) async* {
      // If this provider is disposed (e.g. leaving tab / sign-out), stop work.
      bool disposed = false;
      ref.onDispose(() => disposed = true);

      // Watch profile to get wake/bed hours
      final profile = ref.watch(userProfileStreamProvider(uid)).value;
      if (profile == null) {
        yield const <Event>[];
        return;
      }

      final wakeHour = profile['wakeHour'] as int?;
      final bedHour = profile['bedHour'] as int?;
      if (wakeHour == null || bedHour == null) {
        yield const <Event>[];
        return;
      }

      final today = dateWokeUp(wakeHour, bedHour);
      final repo = ref.read(eventRepositoryProvider);

      try {
        await for (final events in repo.watchUserEventsForToday(uid, today)) {
          if (disposed) return;
          yield events;
        }
      } catch (_) {
        // On sign-out Firestore commonly throws permission-denied.
        // Don’t crash the app; just end the stream / show empty.
        if (!disposed) yield const <Event>[];
      }
    });
