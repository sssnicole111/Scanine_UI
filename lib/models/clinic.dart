import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// One veterinary clinic, loaded from assets/clinics.json.
class Clinic {
  final String name;
  final String? address;
  final String? phone;
  final String? hours;
  final String? services;

  /// Normalised position on assets/map/tacloban.png, 0..1 from the top-left.
  final double? x;
  final double? y;

  final bool verified;

  const Clinic({
    required this.name,
    this.address,
    this.phone,
    this.hours,
    this.services,
    this.x,
    this.y,
    this.verified = false,
  });

  bool get hasPin => x != null && y != null;
  bool get canCall => phone != null && phone!.trim().isNotEmpty;

  /// What the Directions button searches for. Deliberately a name/address
  /// query rather than a coordinate: the pin positions are read off a map
  /// image, so letting the map app resolve the real place means an
  /// imprecise pin can never route someone to the wrong building.
  String get mapQuery {
    final where = (address != null && address!.trim().isNotEmpty)
        ? address!
        : 'Tacloban City, Leyte';
    return '$name, $where';
  }

  factory Clinic.fromJson(Map<String, dynamic> j) => Clinic(
        name: j['name'] as String,
        address: j['address'] as String?,
        phone: j['phone'] as String?,
        hours: j['hours'] as String?,
        services: j['services'] as String?,
        x: (j['x'] as num?)?.toDouble(),
        y: (j['y'] as num?)?.toDouble(),
        verified: (j['verified'] as bool?) ?? false,
      );

  static Future<List<Clinic>> loadAll() async {
    final raw = await rootBundle.loadString('assets/clinics.json');
    final decoded = json.decode(raw) as Map<String, dynamic>;
    return (decoded['clinics'] as List)
        .map((e) => Clinic.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
