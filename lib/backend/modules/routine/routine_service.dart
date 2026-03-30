
import 'dart:convert';
import 'package:seniorsync/backend/modules/shared/api_client.dart';
import 'routine_model.dart';

class RoutineService {
  final String userId;

  RoutineService({required this.userId});

  Future<List<Routine>> fetchRoutines() async {
    try {
      final response = await ApiClient.get('/routines/$userId');
      
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((item) => Routine.fromMap(item)).toList();
      } else {
        throw Exception('Failed to load routines');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Routine> addRoutine(Routine routine) async {
    final response = await ApiClient.post('/routines', routine.toMap(userId));

    if (response.statusCode == 201) {
      return Routine.fromMap(json.decode(response.body));
    } else {
      throw Exception('Failed to add routine');
    }
  }

  Future<void> updateRoutine(Routine routine) async {
    final response = await ApiClient.put('/routines/${routine.id}', routine.toMap(userId));
    if (response.statusCode != 200) {
      throw Exception('Failed to update routine');
    }
  }

  Future<void> completeRoutine(String id) async {
    final response = await ApiClient.put('/routines/complete/$id', {});

    if (response.statusCode != 200) {
      throw Exception('Failed to mark routine as complete');
    }
  }

  Future<void> deleteRoutine(String id) async {
    final response = await ApiClient.delete('/routines/$id');

    if (response.statusCode != 200) {
      throw Exception('Failed to delete routine');
    }
  }
}
