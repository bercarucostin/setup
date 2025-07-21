import 'dart:math';

class Event {
  final String name;
  final double duration;
  final double effect;
  final double decay;
  final double tailEffect;
  final double tailDecay;
  final double endTime;

  Event({
    required this.name,
    required this.duration,
    required this.effect,
    required this.decay,
    required this.tailEffect,
    required this.tailDecay,
    required this.endTime,
  });

  double applyEffect(int hour) {
    double t = hour - endTime;
    if (t < 0) return 0;
    if (t <= duration) return effect * exp(-decay * t);
    double tailT = t - duration;
    return tailEffect * exp(-tailDecay * tailT);
  }
}
