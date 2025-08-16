// lib/features/energy/energy_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setup/features/energy/models/event.dart';
import 'package:setup/features/energy/controllers/event_view_model.dart';
import 'package:setup/features/firestore/providers/providers.dart';
import 'package:setup/features/auth/providers/providers.dart';

/// Repository wiring only.
// final eventRepositoryProvider = Provider<EventRepository>((ref) {
//   final firestoreRepo = ref.read(firestoreRepositoryProvider);
//   return EventRepository(firestoreRepo);
// });

/// Thin provider that exposes the view-model.
/// All methods live in EventViewModel; access via the .notifier.
final eventListProvider = AsyncNotifierProvider<EventNotifier, List<Event>>(
  EventNotifier.new,
);

final defaultEventListProvider = FutureProvider<List<Event>>((ref) async {
  final user = ref.watch(firebaseUserProvider);
  if (user == null) return const <Event>[];

  // WAIT for the user's profile doc to exist / be readable (same trick as insights)
  await ref.watch(firestoreUserProvider.future);

  // Only now hit Firestore for defaults
  final repo = ref.read(eventRepositoryProvider);
  return repo.fetchAllDefaultEvents();
});
