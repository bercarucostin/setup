import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watt/features/auth/providers/providers.dart';
import 'package:watt/features/energy/models/event.dart';
import 'package:watt/features/energy/repositories/event_repository.dart';
import 'package:watt/features/firestore/providers/providers.dart'; // firestoreRepositoryProvider
import 'package:watt/utils/utils.dart';

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
      // Watch profile to get wake/bed hours
      final profileAsync = ref.watch(userProfileStreamProvider(uid));
      final profile = profileAsync.value;

      if (profile == null) return;

      final wakeHour = profile['wakeHour'] as int?;
      final bedHour = profile['bedHour'] as int?;

      if (wakeHour == null || bedHour == null) return;

      final today = dateWokeUp(wakeHour, bedHour);
      final repo = ref.read(eventRepositoryProvider);

      // Stream events for today
      await for (final events in repo.watchUserEventsForToday(uid, today)) {
        yield events;
      }
    });
