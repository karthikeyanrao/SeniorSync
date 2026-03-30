
import 'dart:convert';
import 'package:seniorsync/backend/modules/shared/api_client.dart';
import 'medication_model.dart';

class MedicationService {
  final String userId;

  MedicationService({required this.userId});

  Future<List<Medication>> fetchMedications() async {
    try {
      final response = await ApiClient.get('/medications/$userId');
      
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((item) => Medication.fromMap(item)).toList();
      } else {
        throw Exception('Failed to load medications: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching meds: $e');
      rethrow;
    }
  }

  Future<Medication> addMedication(Medication medication) async {
    final response = await ApiClient.post('/medications', medication.toMap(userId));

    if (response.statusCode == 201) {
      return Medication.fromMap(json.decode(response.body));
    } else {
      throw Exception('Failed to add medication');
    }
  }

  Future<void> updateMedication(Medication medication) async {
    if (medication.id == null) return;
    
    final response = await ApiClient.put(
      '/medications/${medication.id}',
      medication.toMap(userId),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update medication');
    }
  }

  Future<void> deleteMedication(String id) async {
    final response = await ApiClient.delete('/medications/$id');

    if (response.statusCode != 200) {
      throw Exception('Failed to delete medication');
    }
  }
}
