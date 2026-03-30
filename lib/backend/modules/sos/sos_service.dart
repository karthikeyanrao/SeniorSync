
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:seniorsync/backend/modules/shared/api_client.dart';

class SOSService {
  final String userId;

  SOSService({required this.userId});

  Future<Map<String, dynamic>?> triggerSOS() async {
    try {
      // 1. Get position
      Position position = await _determinePosition();
      
      // 2. Send to backend
      final response = await ApiClient.post('/sos/trigger', {
        'userId': userId,
        'location': {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      });

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('SOS Error: $e');
      rethrow;
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    } 

    return await Geolocator.getCurrentPosition();
  }

  Future<void> cancelSOS(String sosId) async {
    await ApiClient.put('/sos/$sosId', {'status': 'cancelled'});
  }

  Future<List<dynamic>> getSOSHistory() async {
    try {
      final response = await ApiClient.get('/sos/history/$userId');
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      print('SOS History Fetch Error: $e');
      return [];
    }
  }
}
