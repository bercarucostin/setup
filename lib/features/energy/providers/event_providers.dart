import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watt/features/energy/models/event.dart';
import 'package:watt/features/energy/repositories/event_repository.dart';
import 'package:watt/features/firestore/providers/providers.dart'; // firestoreRepositoryProvider

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
    .family<List<Event>, String>((ref, uid) {
      final repo = ref.read(eventRepositoryProvider);
      return repo.watchUserEventsForToday(uid);
    });
