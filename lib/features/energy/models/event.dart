import 'dart:math';

import 'package:flutter/material.dart';

class Event {
  final String? id; // Optional ID for existing events
  int? startHour;
  double? intensity; // 1-10 scale
  final String name;
  final String description;

  // Baseline defaults (typically for a 1-hour “unit”)
  final int initialDuration;
  final double initialEffect;
  final double initialDecay;
  final int tailDuration;
  final double tailEffect;
  final double tailDecay;
  final bool booster;

  final IconSpec? icon; // NEW

  Event({
    this.id,
    this.startHour,
    this.intensity,
    required this.name,
    required this.initialDuration,
    required this.initialEffect,
    required this.initialDecay,
    required this.tailDuration,
    required this.tailEffect,
    required this.tailDecay,
    required this.booster,
    this.description = '',
    this.icon,
  });

  factory Event.fromFirestore(Map<String, dynamic> data) {
    return Event(
      id: (data['id'] ?? data['docId']) as String?,
      startHour: data['startHour'] ?? 0,
      intensity: data['intensity'] ?? 1.0,
      name: data['name'],
      initialDuration: data['initialDuration'].toInt(),
      initialEffect: data['initialEffect'].toDouble(),
      initialDecay: data['initialDecay'].toDouble(),
      tailDuration: data['tailDuration'].toInt(),
      tailEffect: data['tailEffect'].toDouble(),
      tailDecay: data['tailDecay'].toDouble(),
      booster: data['booster'] ?? false,
      description: data['description'] ?? '',
      icon: (data['icon'] is Map<String, dynamic>)
          ? IconSpec.fromFirestore(data['icon'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'startHour': startHour,
      'intensity': intensity,
      'name': name,
      'initialDuration': initialDuration,
      'initialEffect': initialEffect,
      'initialDecay': initialDecay,
      'tailDuration': tailDuration,
      'tailEffect': tailEffect,
      'tailDecay': tailDecay,
      'booster': booster,
      'description': description,
      if (icon != null) 'icon': icon!.toFirestore(),
    };
  }

  double get _scale {
    // Scale factor to convert hours to the 0-23 range
    return intensity!;
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
    // length of the interval start->end
    final double totalDuration = _mainEffectDuration + _tailEffectDuration;

    // No effect if zero duration
    if (totalDuration <= 0) return 0.0;
    // If duration >= 24h, effect applies to all hours; otherwise check bounds
    if (totalDuration < 24 && t >= totalDuration) return 0.0;

    if (t <= _mainEffectDuration) {
      return _mainEffect * exp(-_mainDecay * t);
    } else {
      final tailT = (t - _mainEffectDuration).toDouble();
      return _tailEffect * exp(-_tailDecay * tailT);
    }
  }
}

class IconSpec {
  final int codePoint;
  final String family; // e.g. 'MaterialIcons' or 'CupertinoIcons'
  final String? package; // usually null unless you use a package font

  const IconSpec({required this.codePoint, required this.family, this.package});

  factory IconSpec.fromFirestore(Map<String, dynamic> m) {
    // cp can be int or hex string like "0xe541"
    final raw = m['cp'];
    int cp;
    if (raw is int) {
      cp = raw;
    } else if (raw is String) {
      cp = int.parse(raw);
    } else {
      throw ArgumentError('icon.cp missing or invalid');
    }
    return IconSpec(
      codePoint: cp,
      family: (m['family'] as String?) ?? 'MaterialIcons',
      package: m['package'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'cp': codePoint,
    'family': family,
    if (package != null) 'package': package,
  };

  IconData toIconData({bool matchTextDirection = false}) => IconData(
    codePoint,
    fontFamily: family,
    fontPackage: package,
    matchTextDirection: matchTextDirection,
  );
}
