
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:seniorsync/shared/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seniorsync/backend/modules/shared/api_client.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  Map<String, dynamic>? _dbUser;
  String? _accessToken;
  String? _refreshToken;

  bool _hasOnboardedLocally = false;
  bool get hasOnboardedLocally => _hasOnboardedLocally;

  AuthService() {
    _loadTokens();
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user != null) {
        _syncWithBackend(user);
      } else {
        _dbUser = null;
        _clearTokens();
      }
      notifyListeners();
    });
  }

  User? get user => _user;
  Map<String, dynamic>? get dbUser => _dbUser;
  bool get isAuthenticated => _user != null;
  String? get accessToken => _accessToken;

  bool _useBiometrics = false;
  bool get useBiometrics => _useBiometrics;

  Future<void> toggleBiometrics(bool val) async {
    _useBiometrics = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_biometrics', val);
    notifyListeners();
  }

  /// Public method to manually retry sync — call from Profile screen
  Future<void> retrySync() async {
    if (_user != null) {
      await _syncWithBackend(_user!);
    }
  }

  Future<void> _loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
    _useBiometrics = prefs.getBool('use_biometrics') ?? false;
    _hasOnboardedLocally = prefs.getBool('has_onboarded') ?? false;
    
    // Load cached profile
    final cachedUser = prefs.getString('cached_db_user');
    if (cachedUser != null) {
      try {
        _dbUser = json.decode(cachedUser);
      } catch (e) {
        print('[AuthService] Error decoding cached user: $e');
      }
    }

    if (_user != null) _fetchProfile();
    notifyListeners();
  }

  Future<void> _saveTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
    await prefs.setString('refresh_token', refresh);
    notifyListeners();
  }

  Future<void> _clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    notifyListeners();
  }

  Future<void> _fetchProfile() async {
    if (_user == null) return;
    try {
      final response = await ApiClient.get('/auth/profile/${_user!.uid}');
      if (response.statusCode == 200) {
        _dbUser = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_db_user', response.body);
        notifyListeners();
      }
    } catch (e) {
      print('[AuthService] ❌ Profile fetch error: $e');
    }
  }

  Future<void> updateProfile({String? name, int? age, List<String>? conditions, List<String>? allergies, Map<String, String>? foodTimes, bool? onboarded, String? role}) async {
    if (_user == null) return;
    try {
      final response = await ApiClient.patch(
        '/auth/profile/${_user!.uid}',
        {
          if (name != null) 'name': name,
          if (age != null) 'age': age,
          if (conditions != null) 'conditions': conditions,
          if (allergies != null) 'allergies': allergies,
          if (foodTimes != null) 'foodTimes': foodTimes,
          if (onboarded != null) 'onboarded': onboarded,
          if (role != null) 'role': role,
        },
      );
      if (onboarded == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_onboarded', true);
        _hasOnboardedLocally = true;
      }
      if (response.statusCode == 200) {
        _dbUser = json.decode(response.body);
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addCaregiver(String email) async {
    if (_user == null) return;
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/pair/caregiver'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'seniorUid': _user!.uid, 'caregiverEmail': email}),
    );
    if (res.statusCode != 200) {
      try {
        final error = jsonDecode(res.body)['error'];
        throw Exception(error ?? 'Operation failed');
      } catch (e) {
        throw Exception('Server error: ${res.statusCode}');
      }
    }
    await _syncWithBackend(_user!);
  }

  Future<void> unlinkCaregiver(String caregiverUid) async {
    if (_user == null) return;
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/unlink'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'seniorUid': _user!.uid, 'caregiverUid': caregiverUid}),
    );
    if (res.statusCode != 200) {
      try {
        final error = jsonDecode(res.body)['error'];
        throw Exception(error ?? 'Operation failed');
      } catch (e) {
        throw Exception('Server error: ${res.statusCode}');
      }
    }
    await _syncWithBackend(_user!);
  }

  Future<void> addSeniorByUid(String seniorUid) async {
    if (_user == null) return;
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/auth/pair/senior'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'caregiverUid': _user!.uid,
          'seniorUid': seniorUid,
        }),
      );
      if (response.statusCode != 200) {
        final err = json.decode(response.body);
        throw Exception(err['error'] ?? 'Linking failed');
      }
      _fetchProfile();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> eraseAccount() async {
    if (_user == null) return;
    try {
      await ApiClient.delete('/auth/profile/${_user!.uid}');
      await _clearTokens();
      _user = null;
      _dbUser = null;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _syncWithBackend(User user) async {
    // Attempt to get FCM Token for push notifications
    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 2));
    } catch (e) {
      print('[AuthService] Could not request FCM token: $e');
    }

    // Retry up to 2 times with no delay to speed up login
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final url = '${AppConstants.baseUrl}/auth/sync';
        print('[AuthService] Sync attempt $attempt to: $url');
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'firebaseUid': user.uid,
            'email': user.email ?? '',
            'name': (user.displayName != null && user.displayName!.isNotEmpty)
                ? user.displayName!
                : (user.email?.split('@').first ?? 'User'),
            'fcmToken': fcmToken,
          }),
        ).timeout(const Duration(seconds: 15));
        print('[AuthService] Sync response: ${response.statusCode}');
        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = json.decode(response.body);
          _dbUser = data['user'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_db_user', json.encode(_dbUser));
          await _saveTokens(data['accessToken'] ?? '', data['refreshToken'] ?? '');
          notifyListeners();
          return; // Success — exit retry loop
        }
      } catch (e) {
        print('[AuthService] ❌ Sync attempt $attempt failed: $e');
      }
    }
    // All sync attempts failed — fallback to fetching existing profile
    print('[AuthService] Sync failed, falling back to profile fetch...');
    await _fetchProfile();
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signUp(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signInWithGoogle() async {
    try {
      print('[AuthService] Starting Google Sign-In...');
      // Use default constructor — reads web client ID from google-services.json automatically
      final GoogleSignIn googleSignIn = GoogleSignIn();
      
      // Disconnect any previous session first to force account picker
      await googleSignIn.signOut();
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        print('[AuthService] Google Sign-In cancelled by user');
        return;
      }
      print('[AuthService] Google user: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print('[AuthService] Got Google auth tokens - accessToken: ${googleAuth.accessToken != null}, idToken: ${googleAuth.idToken != null}');

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      print('[AuthService] ✅ Google Sign-In successful');
    } catch (e, stack) {
      print('[AuthService] ❌ Google Sign-In error: $e');
      print('[AuthService] Stack: $stack');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }
}
