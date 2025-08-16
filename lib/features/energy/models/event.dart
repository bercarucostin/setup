import 'dart:math';

class Event {
  final String? id; // Optional ID for existing events
  int? startHour;
  double? duration; // number of hours e.g. 1, 1.5, etc.
  final String name;

  // Baseline defaults (typically for a 1-hour “unit”)
  final int initialDuration;
  final double initialEffect;
  final double initialDecay;
  final int tailDuration;
  final double tailEffect;
  final double tailDecay;

  Event({
    this.id,
    this.startHour,
    this.duration,
    required this.name,
    required this.initialDuration,
    required this.initialEffect,
    required this.initialDecay,
    required this.tailDuration,
    required this.tailEffect,
    required this.tailDecay,
  });

  factory Event.fromFirestore(Map<String, dynamic> data) {
    return Event(
      id: (data['id'] ?? data['docId']) as String?,
      startHour: data['startHour'] ?? 0,
      duration: data['duration'] ?? 1.0,
      name: data['name'],
      initialDuration: data['initialDuration'].toInt(),
      initialEffect: data['initialEffect'].toDouble(),
      initialDecay: data['initialDecay'].toDouble(),
      tailDuration: data['tailDuration'].toInt(),
      tailEffect: data['tailEffect'].toDouble(),
      tailDecay: data['tailDecay'].toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'startHour': startHour,
      'duration': duration,
      'name': name,
      'initialDuration': initialDuration,
      'initialEffect': initialEffect,
      'initialDecay': initialDecay,
      'tailDuration': tailDuration,
      'tailEffect': tailEffect,
      'tailDecay': tailDecay,
    };
  }

  double get _scale {
    // Scale factor to convert hours to the 0-23 range
    return duration!;
  }

  double get _mainEffectDuration => initialDuration * _scale;
  double get _mainEffect => initialEffect * _scale;
  double get _mainDecay => max(initialDecay, 1e-9) / max(_scale, 1e-9);
  double get _tailEffectDuration => tailDuration * _scale;
  double get _tailEffect => tailEffect * _scale;
  double get _tailDecay => max(tailDecay, 1e-9) / max(_scale, 1e-9);

  double applyEffect(int hour) {
    // hours since start, wrapped forward
    final int t = (hour - startHour!) % 24; // 0..23
    // length of the interval start->end, wrapped forward
    final double window =
        (_mainEffectDuration + _tailEffectDuration) % 24; // 0..23

    // Half-open interval: [start, end)
    if (window == 0) return 0.0; // degenerate: empty interval
    if (t >= window) return 0.0; // outside interval

    if (t <= _mainEffectDuration) {
      return _mainEffect * exp(-_mainDecay * t);
    } else {
      final tailT = (t - _mainEffectDuration).toDouble();
      return _tailEffect * exp(-_tailDecay * tailT);
    }
  }
}
