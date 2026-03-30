
import 'package:flutter/material.dart';

class Routine {
  final String? id;
  final String title;
  final String? description;
  final TimeOfDay time;
  final List<String> days;
  final bool isCompletedToday;
  final int streak;

  Routine({
    this.id,
    required this.title,
    this.description,
    required this.time,
    required this.days,
    this.isCompletedToday = false,
    this.streak = 0,
  });

  Routine copyWith({
    String? id,
    String? title,
    String? description,
    TimeOfDay? time,
    List<String>? days,
    bool? isCompletedToday,
    int? streak,
  }) {
    return Routine(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      time: time ?? this.time,
      days: days ?? this.days,
      isCompletedToday: isCompletedToday ?? this.isCompletedToday,
      streak: streak ?? this.streak,
    );
  }

  factory Routine.fromMap(Map<String, dynamic> map) {
    final timeData = map['time'] as Map<String, dynamic>? ?? {'hour': 8, 'minute': 0};
    
    return Routine(
      id: map['_id'],
      title: map['title'] ?? '',
      description: map['description'],
      time: TimeOfDay(
        hour: timeData['hour'] ?? 8,
        minute: timeData['minute'] ?? 0,
      ),
      days: List<String>.from(map['days'] ?? []),
      isCompletedToday: map['isCompletedToday'] ?? false,
      streak: map['streak'] ?? 0,
    );
  }

  Map<String, dynamic> toMap(String userId) {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'time': {'hour': time.hour, 'minute': time.minute},
      'days': days,
      'isCompletedToday': isCompletedToday,
      'streak': streak,
    };
  }
}
