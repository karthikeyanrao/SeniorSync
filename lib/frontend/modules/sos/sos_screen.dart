import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:seniorsync/backend/modules/sos/sos_service.dart';
import 'package:seniorsync/backend/modules/profile/auth_service.dart';
import 'package:seniorsync/frontend/modules/shared/senior_styles.dart';
import 'package:seniorsync/frontend/modules/sos/hospital_map_screen.dart';
import 'package:seniorsync/frontend/modules/sos/sos_history_screen.dart';
import 'package:seniorsync/frontend/modules/sos/emergency_contacts_screen.dart';

class SOSScreen extends StatefulWidget {
  const SOSScreen({super.key});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isCountdownActive = false;
  int _secondsLeft = 5;
  Timer? _timer;
  String? _currentSosId;
  bool _isTriggered = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused || state == AppLifecycleState.inactive) && _isCountdownActive) {
      // If the app goes to the background while SOS is counting down, trigger it instantly
      _timer?.cancel();
      _triggerSOS();
    }
  }

  void _startSOS() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isCountdownActive = true;
      _secondsLeft = 5;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      HapticFeedback.mediumImpact();
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
      } else {
        _timer?.cancel();
        _triggerSOS();
      }
    });
  }

  Future<void> _triggerSOS() async {
    HapticFeedback.heavyImpact();
    final auth = Provider.of<AuthService>(context, listen: false);
    final sosService = SOSService(userId: auth.user!.uid);

    try {
      final result = await sosService.triggerSOS();
      if (result != null) {
        setState(() {
          _isCountdownActive = false;
          _isTriggered = true;
          _currentSosId = result['_id'];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: SeniorStyles.alertRed),
      );
      setState(() => _isCountdownActive = false);
    }
  }

  void _cancelSOS() async {
    HapticFeedback.lightImpact();
    _timer?.cancel();
    if (_currentSosId != null) {
      final auth = Provider.of<AuthService>(context, listen: false);
      await SOSService(userId: auth.user!.uid).cancelSOS(_currentSosId!);
    }
    setState(() {
      _isCountdownActive = false;
      _isTriggered = false;
      _currentSosId = null;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeniorStyles.backgroundGray,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text("Emergency SOS", style: SeniorStyles.header),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: SeniorStyles.primaryBlue),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SOSHistoryScreen()));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height - kToolbarHeight - MediaQuery.of(context).padding.top - 80,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              if (!_isCountdownActive && !_isTriggered) ...[
                const Icon(Icons.emergency, size: 48, color: SeniorStyles.alertRed),
                const SizedBox(height: 16),
                const Text(
                  "NEED HELP?",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "Press the button below. Your location will be shared with your caregivers immediately.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.black54),
                  ),
                ),
                const SizedBox(height: 60),
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = 1.0 + (_pulseController.value * 0.05);
                    return Transform.scale(
                      scale: scale,
                      child: child,
                    );
                  },
                  child: GestureDetector(
                    onTap: _startSOS,
                    child: Container(
                      height: 200,
                      width: 200,
                      decoration: BoxDecoration(
                        color: SeniorStyles.alertRed,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: SeniorStyles.alertRed.withOpacity(0.4),
                            spreadRadius: 10,
                            blurRadius: 30,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          "SOS",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  "TAP TO ALERT",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 2),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const HospitalMapScreen()));
                    },
                    icon: const Icon(Icons.local_hospital, color: SeniorStyles.primaryBlue),
                    label: const Text("Find Nearby Hospitals", style: SeniorStyles.largeButtonText),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: SeniorStyles.primaryBlue, width: 2),
                      foregroundColor: SeniorStyles.primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()));
                    },
                    icon: const Icon(Icons.contact_phone, color: Colors.deepOrange),
                    label: const Text("Emergency Contacts", style: SeniorStyles.largeButtonText),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.deepOrange, width: 2),
                      foregroundColor: Colors.deepOrange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
              if (_isCountdownActive) ...[
                const Text(
                  "Sending Help Request in...",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 40),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 180,
                      width: 180,
                      child: CircularProgressIndicator(
                        value: _secondsLeft / 5,
                        strokeWidth: 12,
                        color: SeniorStyles.alertRed,
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ),
                    Text(
                      "$_secondsLeft",
                      style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: SeniorStyles.alertRed),
                    ),
                  ],
                ),
                const SizedBox(height: 60),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: OutlinedButton(
                    onPressed: _cancelSOS,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("CANCEL", style: TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
              if (_isTriggered) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: SeniorStyles.successGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: SeniorStyles.successGreen, size: 100),
                ),
                const SizedBox(height: 24),
                const Text(
                  "ALERTS SENT!",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: SeniorStyles.successGreen),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "Your caregivers have been notified and your location is being tracked.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.black54),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _cancelSOS,
                    icon: const Icon(Icons.shield),
                    label: const Text("I'M SAFE NOW", style: SeniorStyles.largeButtonText),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SeniorStyles.successGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }
}
