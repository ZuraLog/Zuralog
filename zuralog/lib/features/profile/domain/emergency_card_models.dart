/// Emergency Health Card — shared data models.
///
/// Defines [EmergencyContact] and [EmergencyCardData] used by both
/// [EmergencyCardScreen] (view) and [EmergencyCardEditScreen] (edit).
///
/// Kept in the domain layer so neither screen owns the model.
library;

import 'package:flutter/foundation.dart';

@immutable
class EmergencyContact {
  const EmergencyContact({
    required this.name,
    required this.relationship,
    required this.phone,
  });

  final String name;
  final String relationship;
  final String phone;

  EmergencyContact copyWith({
    String? name,
    String? relationship,
    String? phone,
  }) =>
      EmergencyContact(
        name: name ?? this.name,
        relationship: relationship ?? this.relationship,
        phone: phone ?? this.phone,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'relationship': relationship,
        'phone': phone,
      };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        name: json['name'] as String? ?? '',
        relationship: json['relationship'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
      );
}

@immutable
class EmergencyCardData {
  const EmergencyCardData({
    this.bloodType = '',
    this.allergies = const [],
    this.medications = const [],
    this.conditions = const [],
    this.contacts = const [],
    this.updatedAt,
  });

  final String bloodType;
  final List<String> allergies;
  final List<String> medications;
  final List<String> conditions;
  final List<EmergencyContact> contacts;

  /// Null when the card has never been saved by the user.
  final DateTime? updatedAt;

  bool get isEmpty =>
      bloodType.isEmpty &&
      allergies.isEmpty &&
      medications.isEmpty &&
      conditions.isEmpty &&
      contacts.every((c) => c.name.isEmpty);

  EmergencyCardData copyWith({
    String? bloodType,
    List<String>? allergies,
    List<String>? medications,
    List<String>? conditions,
    List<EmergencyContact>? contacts,
    DateTime? updatedAt,
  }) =>
      EmergencyCardData(
        bloodType: bloodType ?? this.bloodType,
        allergies: allergies ?? this.allergies,
        medications: medications ?? this.medications,
        conditions: conditions ?? this.conditions,
        contacts: contacts ?? this.contacts,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'bloodType': bloodType,
        'allergies': allergies,
        'medications': medications,
        'conditions': conditions,
        'contacts': contacts.map((c) => c.toJson()).toList(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory EmergencyCardData.fromJson(Map<String, dynamic> json) =>
      EmergencyCardData(
        bloodType: json['bloodType'] as String? ?? '',
        allergies: List<String>.from(json['allergies'] as List? ?? []),
        medications: List<String>.from(json['medications'] as List? ?? []),
        conditions: List<String>.from(json['conditions'] as List? ?? []),
        contacts: (json['contacts'] as List? ?? [])
            .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
            .toList(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
      );
}
