import 'dart:math';

import 'package:flutter/material.dart';

class Event {
  final String? id;
  int? startHour;
  double? intensity;
  final String name;
  final String description;

  final String? createdAt; // ✅ NEW

  final double initialDuration;
  final double initialEffect;
  final double initialDecay;
  final double tailDuration;
  final double tailEffect;
  final double tailDecay;
  final bool booster;

  final IconSpec? icon;

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
    this.createdAt, // ✅ NEW
    this.icon,
  });

  factory Event.fromFirestore(Map<String, dynamic> data) {
    return Event(
      id: (data['id'] ?? data['docId']) as String?,
      startHour: data['startHour'] ?? 0,
      intensity: (data['intensity'] as num?)?.toDouble() ?? 3.0,
      name: data['name'],
      initialDuration: (data['initialDuration'] as num).toDouble(),
      initialEffect: data['initialEffect'].toDouble(),
      initialDecay: data['initialDecay'].toDouble(),
      tailDuration: (data['tailDuration'] as num).toDouble(),
      tailEffect: data['tailEffect'].toDouble(),
      tailDecay: data['tailDecay'].toDouble(),
      booster: data['booster'] ?? false,
      description: data['description'] ?? '',
      createdAt: data['createdAt'] as String?, // ✅ NEW
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

  @override
  String toString() {
    return 'Event('
        'id: $id, '
        'name: $name, '
        'description: $description, '
        'startHour: $startHour, '
        'intensity: $intensity, '
        'createdAt: $createdAt, '
        'initialDuration: $initialDuration, '
        'initialEffect: $initialEffect, '
        'initialDecay: $initialDecay, '
        'tailDuration: $tailDuration, '
        'tailEffect: $tailEffect, '
        'tailDecay: $tailDecay, '
        'booster: $booster, '
        'icon: $icon'
        ')';
  }

  // Optional helper if you want DateTime usage in UI/sorting
  DateTime? get createdAtDate {
    final v = createdAt;
    if (v == null || v.isEmpty) return null;
    return DateTime.tryParse(v);
  }

  double get _scale {
    // Centered scaling for UI slider 1..5, with 3 = baseline (1.0x)
    final i = intensity ?? 3.0;
    final clamped = i < 1.0 ? 1.0 : (i > 5.0 ? 5.0 : i);
    return 1.0 + (clamped - 3.0) * 0.25; // 1->0.5x, 3->1.0x, 5->1.5x
  }

  double get _mainEffectDuration => initialDuration * _scale;
  double get _mainEffect => initialEffect * _scale;
  double get _mainDecay => max(initialDecay, 1e-9) / max(_scale, 1e-9);
  double get _tailEffectDuration => tailDuration * _scale;
  double get _tailEffect => tailEffect * _scale;
  double get _tailDecay => max(tailDecay, 1e-9) / max(_scale, 1e-9);

  double applyEffect(int hour) {
    // Null safety guards
    final sh = startHour;
    if (sh == null) return 0.0;

    // hours since start, wrapped forward
    final int t = (hour - sh) % 24; // 0..23

    // length of the interval start->end
    final double totalDuration = _mainEffectDuration + _tailEffectDuration;

    // No effect if zero duration
    if (totalDuration <= 0) return 0.0;

    // If duration >= 24h, effect applies to all hours; otherwise check bounds
    if (totalDuration < 24 && t >= totalDuration) return 0.0;

    // Main/tail boundary fix: half-open interval [0, mainDuration)
    if (t < _mainEffectDuration) {
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
