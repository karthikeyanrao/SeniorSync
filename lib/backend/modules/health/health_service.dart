
import 'dart:convert';
import 'package:seniorsync/backend/modules/shared/api_client.dart';
import 'vitals_model.dart';

class HealthService {
  final String userId;

  HealthService({required this.userId});

  Future<List<Vitals>> fetchVitals() async {
    final response = await ApiClient.get('/health/vitals/$userId');
    
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((item) => Vitals.fromMap(item)).toList();
    } else {
      throw Exception('Failed to load vitals');
    }
  }

  Future<void> addVitals(Vitals vitals) async {
    final response = await ApiClient.post('/health/vitals', {
      'userId': userId,
      'bloodPressure': vitals.bloodPressure,
      'heartRate': vitals.heartRate,
      'bloodSugar': vitals.bloodSugar,
    });

    if (response.statusCode != 201) {
      throw Exception('Failed to add vitals');
    }
  }
}
