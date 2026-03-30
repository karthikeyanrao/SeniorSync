import 'dart:convert';
import 'package:seniorsync/backend/modules/shared/api_client.dart';

class CaregiverService {
  final String caregiverUid;

  CaregiverService({required this.caregiverUid});

  Future<List<Map<String, dynamic>>> fetchLinkedSeniors() async {
    try {
      final response = await ApiClient.get('/caregivers/seniors/$caregiverUid');
      
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load linked seniors');
      }
    } catch (e) {
      print('Error fetching linked seniors: $e');
      rethrow;
    }
  }
}
