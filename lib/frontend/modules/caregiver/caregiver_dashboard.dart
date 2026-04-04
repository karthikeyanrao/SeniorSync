import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seniorsync/backend/modules/caregiver/caregiver_service.dart';
import 'package:seniorsync/backend/modules/profile/auth_service.dart';
import 'package:seniorsync/frontend/modules/shared/senior_styles.dart';
import 'package:seniorsync/frontend/modules/caregiver/senior_details_screen.dart';
import 'package:seniorsync/frontend/modules/caregiver/qr_scanner_screen.dart';
import 'dart:async';
import 'package:seniorsync/backend/modules/shared/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:seniorsync/backend/modules/shared/api_client.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({super.key});

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  late CaregiverService _service;
  List<Map<String, dynamic>> _seniors = [];
  bool _isLoading = true;
  Timer? _pollingTimer;
  
  // Track notified IDs to avoid duplicate notifications
  final Set<String> _notifiedIds = {};

  @override
  void initState() {
    super.initState();
    _initNotifications();
    
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.user != null) {
      _service = CaregiverService(caregiverUid: auth.user!.uid);
      _loadSeniors();
      // Shorten polling to 30 seconds for better responsiveness
      _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) => _pollBackground());
      
      // Real-time listener for SOS alerts
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.data['type'] == 'SOS_ALERT' || message.data['type'] == 'MISSED_MED') {
          print('[CaregiverDashboard] Real-time SOS alert received — refreshing...');
          _loadSeniors();
        }
      });
    }
  }

  Future<void> _initNotifications() async {
    await NotificationService().init();
  }

  Future<void> _pollBackground() async {
    try {
      final seniors = await _service.fetchLinkedSeniors();
      if (mounted) setState(() => _seniors = seniors);
      
      for (var senior in seniors) {
        // Check missed medications
        final missedMeds = senior['missedMedications'] as List<dynamic>? ?? [];
        for (var med in missedMeds) {
          final medId = med['_id']?.toString() ?? '';
          if (medId.isNotEmpty && !_notifiedIds.contains(medId)) {
            _notifiedIds.add(medId);
            _showNotification(
              "Missed Medication Alert 🚨",
              "${senior['name']} has missed their dose of ${med['name']}."
            );
          }
        }

        // Check active SOS
        final activeSOS = senior['activeSOS'];
        if (activeSOS != null) {
          final sosId = activeSOS['_id']?.toString() ?? '';
          if (sosId.isNotEmpty && !_notifiedIds.contains('sos_$sosId')) {
            _notifiedIds.add('sos_$sosId');
            _showNotification(
              "🚨 EMERGENCY: ${senior['name']} Needs Help!",
              "${senior['name']} has triggered an SOS alert. Tap to view their location."
            );
          }
        }
      }
    } catch (e) {
      // Background poll failure, ignore quietly
    }
  }

  Future<void> _showNotification(String title, String body) async {
    await NotificationService().showImmediate(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSeniors() async {
    setState(() => _isLoading = true);
    await _pollBackground();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _scanSeniorQRCode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CaregiverQRScannerScreen()),
    );
    if (result != null && result is String) {
      if (result.startsWith("seniorsync_uid:")) {
        final seniorUid = result.replaceAll("seniorsync_uid:", "");
        try {
          setState(() => _isLoading = true);
          final auth = Provider.of<AuthService>(context, listen: false);
          await auth.addSeniorByUid(seniorUid);
          await _loadSeniors();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Senior linked successfully!")));
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error linking: $e")));
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _resolveSOS(String sosId) async {
    try {
      setState(() => _isLoading = true);
      final auth = Provider.of<AuthService>(context, listen: false);
      final response = await ApiClient.put('/sos/$sosId', {
        'status': 'resolved',
        'resolvedBy': auth.user?.uid,
      });
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _loadSeniors();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("SOS Marked as Resolved")));
      } else {
        throw Exception("Failed to resolve SOS");
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeniorStyles.backgroundGray,
      appBar: AppBar(
        title: const Text("Caregiver Dashboard", style: SeniorStyles.header),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: SeniorStyles.primaryBlue),
            onPressed: _scanSeniorQRCode,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: SeniorStyles.primaryBlue),
            onPressed: _loadSeniors,
          )
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadSeniors,
            child: _seniors.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _seniors.length,
                  itemBuilder: (context, index) {
                    final senior = _seniors[index];
                    return _buildSeniorCard(senior);
                  },
                ),
          ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 80, color: Colors.grey.withOpacity(0.3)),
                const SizedBox(height: 16),
                const Text("No linked seniors yet", style: SeniorStyles.subheader),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    "Seniors can add you as a caregiver by entering your email in their profile settings.",
                    textAlign: TextAlign.center,
                    style: SeniorStyles.cardSubtitle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeniorCard(Map<String, dynamic> senior) {
    final hasActiveSOS = senior['activeSOS'] != null;
    final lastVitals = senior['latestVitals'];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SeniorDetailsScreen(senior: senior)),
        );
      },
      child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: hasActiveSOS ? SeniorStyles.alertRed : SeniorStyles.primaryBlue.withOpacity(0.1),
                  child: Text(
                    senior['name']?[0]?.toUpperCase() ?? 'U',
                    style: TextStyle(
                      color: hasActiveSOS ? Colors.white : SeniorStyles.primaryBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(senior['name'] ?? 'Unknown', style: SeniorStyles.cardTitle),
                      Text(senior['email'] ?? '', style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
                if ((senior['missedMedications']?.length ?? 0) > 0 && !hasActiveSOS)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: SeniorStyles.warningOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text("${senior['missedMedications']!.length} Missed Meds", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                if (hasActiveSOS)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: SeniorStyles.alertRed,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text("SOS ACTIVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  )
              ],
            ),
            if (hasActiveSOS) ...[
              const Divider(height: 24),
              GestureDetector(
                onTap: () {
                  final loc = senior['activeSOS']?['location'];
                  if (loc != null) {
                    final lat = loc['latitude'];
                    final lon = loc['longitude'];
                    launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon'));
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SeniorStyles.alertRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SeniorStyles.alertRed.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: SeniorStyles.alertRed, size: 20),
                          SizedBox(width: 8),
                          Flexible(child: Text("SOS ALERT ACTIVE — TAP TO VIEW LOCATION", style: TextStyle(color: SeniorStyles.alertRed, fontWeight: FontWeight.bold, fontSize: 13))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (senior['activeSOS']?['timestamp'] != null)
                        Text(
                          "Triggered: ${_formatSosTime(senior['activeSOS']['timestamp'])}",
                          style: const TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                      if (senior['activeSOS']?['location'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          "📍 Tap to open in Google Maps",
                          style: TextStyle(color: SeniorStyles.primaryBlue, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _resolveSOS(senior['activeSOS']['_id']),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text("MARK AS RESOLVED", style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SeniorStyles.successGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const Divider(height: 32),
            ],
            const Text("Latest Vitals", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 14)),
            const SizedBox(height: 8),
            if (lastVitals != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildVitalStat(Icons.favorite, "${lastVitals['heartRate']} bpm", Colors.redAccent),
                  _buildVitalStat(Icons.water_drop, "${lastVitals['bloodSugar']} mg/dL", Colors.blue),
                  _buildVitalStat(Icons.speed, lastVitals['bloodPressure'] ?? '--', Colors.orange),
                ],
              )
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text("No vitals recorded recently.", style: TextStyle(color: Colors.black38, fontStyle: FontStyle.italic)),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }

  String _formatSosTime(String? isoTimestamp) {
    if (isoTimestamp == null) return 'Unknown time';
    try {
      final dt = DateTime.parse(isoTimestamp).toLocal();
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return "${dt.day}/${dt.month}/${dt.year} at $hour:$min $amPm";
    } catch (_) {
      return isoTimestamp;
    }
  }

  Widget _buildVitalStat(IconData icon, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}
