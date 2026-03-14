import 'dart:math';

import 'package:flutter/material.dart';

class Event {
  final String? id;

  int? startHour;
  int? startMinute;
  double? intensity;

  final String name;
  final String description;
  final String? createdAt;

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
    this.startMinute,
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
    this.createdAt,
    this.icon,
  });

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  factory Event.fromFirestore(Map<String, dynamic> data) {
    return Event(
      id: (data['id'] ?? data['docId']) as String?,
      startHour: _asInt(data['startHour']) ?? 0,
      startMinute: _asInt(data['startMinute']) ?? 0,
      intensity: (data['intensity'] as num?)?.toDouble() ?? 3.0,
      name: data['name'],
      initialDuration: (data['initialDuration'] as num).toDouble(),
      initialEffect: (data['initialEffect'] as num).toDouble(),
      initialDecay: (data['initialDecay'] as num).toDouble(),
      tailDuration: (data['tailDuration'] as num).toDouble(),
      tailEffect: (data['tailEffect'] as num).toDouble(),
      tailDecay: (data['tailDecay'] as num).toDouble(),
      booster: data['booster'] ?? false,
      description: data['description'] ?? '',
      createdAt: data['createdAt'] as String?,
      icon: (data['icon'] is Map<String, dynamic>)
          ? IconSpec.fromFirestore(data['icon'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'startHour': startHour,
      'startMinute': startMinute,
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
        'startMinute: $startMinute, '
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

  DateTime? get createdAtDate {
    final v = createdAt;
    if (v == null || v.isEmpty) return null;
    return DateTime.tryParse(v);
  }

  int get safeStartHour => startHour ?? 0;
  int get safeStartMinute => startMinute ?? 0;

  int get startTotalMinutes => safeStartHour * 60 + safeStartMinute;

  double get startTimeAsDouble => safeStartHour + safeStartMinute / 60.0;

  double get _scale {
    final i = intensity ?? 3.0;
    final clamped = i < 1.0 ? 1.0 : (i > 5.0 ? 5.0 : i);
    return 1.0 + (clamped - 3.0) * 0.25;
  }

  double get _mainEffectDuration => initialDuration * _scale;
  double get _mainEffect => initialEffect * _scale;
  double get _mainDecay => max(initialDecay, 1e-9) / max(_scale, 1e-9);
  double get _tailEffectDuration => tailDuration * _scale;
  double get _tailEffect => tailEffect * _scale;
  double get _tailDecay => max(tailDecay, 1e-9) / max(_scale, 1e-9);

  double applyEffect(int hour) {
    final sh = startHour;
    if (sh == null) return 0.0;

    final int t = (hour - sh) % 24;

    final double totalDuration = _mainEffectDuration + _tailEffectDuration;

    if (totalDuration <= 0) return 0.0;
    if (totalDuration < 24 && t >= totalDuration) return 0.0;

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
  final String family;
  final String? package;

  const IconSpec({required this.codePoint, required this.family, this.package});

  factory IconSpec.fromFirestore(Map<String, dynamic> m) {
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
