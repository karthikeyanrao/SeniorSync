import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'app/app_router.dart';
import 'app/theme.dart';
import 'backend/modules/profile/auth_service.dart';
import 'firebase_options.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'backend/modules/shared/api_client.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Background message received: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request notification permissions
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (message.notification != null) {
      print('Foreground Notification: ${message.notification?.title}');
    }
  });
  
  // Initialize Offline Capabilities
  await Hive.initFlutter();
  await ApiClient.initOfflineBoxes();

  // Listen for Internet Restoration
  Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
    if (results.isNotEmpty && results.first != ConnectivityResult.none) {
      print('🌐 Network Restored — Syncing Offline Queue...');
      ApiClient.syncOfflineQueue();
    }
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: const SeniorSyncApp(),
    ),
  );
}

class SeniorSyncApp extends StatefulWidget {
  const SeniorSyncApp({super.key});

  @override
  State<SeniorSyncApp> createState() => _SeniorSyncAppState();
}

class _SeniorSyncAppState extends State<SeniorSyncApp> {
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final offline = results.isEmpty || results.first == ConnectivityResult.none;
      if (mounted) setState(() => _isOffline = offline);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "SeniorSync",
      debugShowCheckedModeBanner: false,
      theme: SeniorSyncTheme.lightTheme,
      home: Column(
        children: [
          if (_isOffline)
            Material(
              color: Colors.orange.shade700,
              child: const SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('No internet — changes will sync when reconnected', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          const Expanded(child: AppRouter()),
        ],
      ),
    );
  }
}
