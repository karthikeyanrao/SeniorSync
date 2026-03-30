import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:seniorsync/shared/constants.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized API client with timeouts, error handling, and logging.
class ApiClient {
  static const Duration _timeout = Duration(seconds: 5); // Shorter timeout to fall back to cache quickly
  static late Box _cacheBox;
  static late Box _queueBox;

  static Future<void> initOfflineBoxes() async {
    _cacheBox = await Hive.openBox('api_cache');
    _queueBox = await Hive.openBox('offline_queue');
    syncOfflineQueue(); // Fire off sync queue when app boots
  }

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// ----------------------------------------
  /// OFFLINE-FIRST GET
  /// ----------------------------------------
  static Future<http.Response> get(String path) async {
    final url = '${AppConstants.baseUrl}$path';
    print('[API] GET $url');
    
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(url), headers: headers).timeout(_timeout);
      print('[API] GET $path → ${response.statusCode}');
      
      // Update Cache if successful
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _cacheBox.put(path, response.body);
      }
      return response;
    } catch (e) {
      // ⚠️ Network failed — fallback to local cache
      print('[API/OFFLINE] Network failed for $path. Falling back to local cache.');
      final cachedBody = _cacheBox.get(path);
      
      if (cachedBody != null) {
        return http.Response(cachedBody as String, 200);
      }
      
      print('[API] ❌ GET $path failed entirely: $e');
      rethrow; // No cache and no internet -> throw
    }
  }

  /// ----------------------------------------
  /// OFFLINE-QUEUED MUTATIONS
  /// ----------------------------------------
  static Future<http.Response> post(String path, Map<String, dynamic> body) async {
    return _mutation('POST', path, body);
  }

  static Future<http.Response> put(String path, Map<String, dynamic> body) async {
    return _mutation('PUT', path, body);
  }

  static Future<http.Response> patch(String path, Map<String, dynamic> body) async {
    return _mutation('PATCH', path, body);
  }

  static Future<http.Response> delete(String path) async {
    return _mutation('DELETE', path, {});
  }

  static Future<http.Response> _mutation(String method, String path, Map<String, dynamic> body) async {
    final url = '${AppConstants.baseUrl}$path';
    final payloadString = json.encode(body);
    print('[API] $method $url');
    
    try {
      final headers = await _getHeaders();
      late http.Response response;
      if (method == 'POST') {
        response = await http.post(Uri.parse(url), headers: headers, body: payloadString).timeout(_timeout);
      } else if (method == 'PUT') {
        response = await http.put(Uri.parse(url), headers: headers, body: payloadString).timeout(_timeout);
      } else if (method == 'PATCH') {
        response = await http.patch(Uri.parse(url), headers: headers, body: payloadString).timeout(_timeout);
      } else if (method == 'DELETE') {
        response = await http.delete(Uri.parse(url), headers: headers).timeout(_timeout);
      }
      
      print('[API] $method $path → ${response.statusCode}');
      return response;
    } catch (e) {
      // ⚠️ Queue operation for later
      print('[API/OFFLINE] 💾 Queuing offline mutation: $method $path');
      _queueBox.add({
        'method': method,
        'path': path,
        'body': body,
        'timestamp': DateTime.now().toIso8601String()
      });
      // Ty to silently background sync when network returns
      syncOfflineQueue(); 
      // Return a fake 200/201 with the original payload echoed so the UI parsers don't crash optimistically
      return http.Response(json.encode({'offlineQueued': true, ...body}), method == 'POST' ? 201 : 200);
    }
  }

  /// Background Daemon to drain the mutation queue
  static Future<void> syncOfflineQueue() async {
    if (_queueBox.isEmpty) return;

    print('[API/SYNC] Attempting to sync ${_queueBox.length} queued operations...');
    
    // We fetch current items to prevent iterating over newly added items during sync
    final keys = _queueBox.keys.toList();
    
    for (var key in keys) {
      final item = _queueBox.get(key) as Map?;
      if (item == null) continue;

      final method = item['method'] as String;
      final path = item['path'] as String;
      final body = Map<String, dynamic>.from(item['body'] as Map);
      
      final url = '${AppConstants.baseUrl}$path';
      final payloadString = json.encode(body);

      try {
        final headers = await _getHeaders();
        if (method == 'POST') {
          await http.post(Uri.parse(url), headers: headers, body: payloadString).timeout(const Duration(seconds: 4));
        } else if (method == 'PUT') {
          await http.put(Uri.parse(url), headers: headers, body: payloadString).timeout(const Duration(seconds: 4));
        } else if (method == 'PATCH') {
          await http.patch(Uri.parse(url), headers: headers, body: payloadString).timeout(const Duration(seconds: 4));
        } else if (method == 'DELETE') {
          await http.delete(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 4));
        }
        
        // Success! Remove from queue.
        await _queueBox.delete(key);
      } catch (e) {
        // Stop sync on first network error to maintain order
        print('[API/SYNC] Sync aborted due to network failure: $e');
        break;
      }
    }
    print('[API/SYNC] Sync queue currently has ${_queueBox.length} items left.');
  }
}
