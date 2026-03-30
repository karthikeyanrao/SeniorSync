
import 'package:flutter/material.dart';

enum MedicationStatus { scheduled, taken, skipped, missed, snoozed }

class Medication {
  final String? id;
  final String name;
  final String dosage;
  final TimeOfDay timeOfDay;
  final String? notes;
  final MedicationStatus status;

  Medication({
    this.id,
    required this.name,
    required this.dosage,
    required this.timeOfDay,
    this.notes,
    this.status = MedicationStatus.scheduled,
  });

  factory Medication.fromMap(Map<String, dynamic> data) {
    // MongoDB stores time as {hour, minute}
    final timeData = data['timeOfDay'] as Map<String, dynamic>? ?? {'hour': 8, 'minute': 0};
    
    return Medication(
      id: data['_id'],
      name: data['name'] ?? '',
      dosage: data['dosage'] ?? '',
      timeOfDay: TimeOfDay(
        hour: timeData['hour'] ?? 8,
        minute: timeData['minute'] ?? 0,
      ),
      notes: data['notes'],
      status: MedicationStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'scheduled'),
        orElse: () => MedicationStatus.scheduled,
      ),
    );
  }

  Map<String, dynamic> toMap(String userId) {
    return {
      'userId': userId,
      'name': name,
      'dosage': dosage,
      'timeOfDay': {'hour': timeOfDay.hour, 'minute': timeOfDay.minute},
      'notes': notes,
      'status': status.name,
    };
  }

  Medication copyWith({
    String? id,
    String? name,
    String? dosage,
    TimeOfDay? timeOfDay,
    String? notes,
    MedicationStatus? status,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      notes: notes ?? this.notes,
      status: status ?? this.status,
    );
  }
}
