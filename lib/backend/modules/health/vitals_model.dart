
class Vitals {
  final String? id;
  final String bloodPressure;
  final int heartRate;
  final int bloodSugar;
  final DateTime timestamp;

  Vitals({
    this.id,
    required this.bloodPressure,
    required this.heartRate,
    required this.bloodSugar,
    required this.timestamp,
  });

  factory Vitals.fromMap(Map<String, dynamic> data) {
    return Vitals(
      id: data['_id'],
      bloodPressure: data['bloodPressure'] ?? '',
      heartRate: data['heartRate'] ?? 0,
      bloodSugar: data['bloodSugar'] ?? 0,
      timestamp: DateTime.parse(data['timestamp']).toLocal(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bloodPressure': bloodPressure,
      'heartRate': heartRate,
      'bloodSugar': bloodSugar,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
