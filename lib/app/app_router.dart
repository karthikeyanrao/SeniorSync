
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seniorsync/frontend/modules/shared/senior_styles.dart';
import '../backend/modules/profile/auth_service.dart';
import '../frontend/modules/medication/medication_screen.dart';
import '../frontend/modules/health/health_screen.dart';
import '../frontend/modules/routine/routine_screen.dart';
import '../frontend/modules/profile/profile_screen.dart';
import '../frontend/modules/profile/login_screen.dart';
import '../frontend/modules/sos/sos_screen.dart';
import '../frontend/modules/caregiver/caregiver_dashboard.dart';
import '../frontend/modules/health/wellness_screen.dart';
import '../frontend/modules/profile/onboarding_screen.dart';
import '../frontend/modules/dashboard/senior_dashboard_screen.dart';
import 'package:local_auth/local_auth.dart';

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  int index = 0;
  bool _identifiedWithBiometrics = false;
  bool _tipShown = false;
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<void> _authenticateBiometrics() async {
    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access SeniorSync',
      );
      if (didAuthenticate) {
        setState(() => _identifiedWithBiometrics = true);
      }
    } catch (e) {
      // Fallback if local_auth fails or hardware missing
      print("Biometric Error: $e");
    }
  }

  Future<void> _showDailyTip(BuildContext context) async {
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    const tips = [
      '💧 Drink water first thing in the morning — it kick-starts your metabolism!',
      '🚶 A 20-minute walk can lower blood pressure as effectively as some medications.',
      '😴 Same bedtime every night improves sleep quality within just 2 weeks.',
      '🥗 5 servings of fruits & vegetables daily reduces heart disease risk by 20%.',
      '📞 Calling a friend or family daily is one of the most powerful mood boosters.',
      '🧘 Five deep breaths right now will lower your heart rate and reduce stress.',
      '💊 Same medication time daily improves effectiveness and reduces missed doses.',
      '🌞 10 mins of morning sunlight helps regulate your sleep cycle and vitamin D.',
      '🧠 Reading 30 min a day preserves memory and sharpness as you age.',
      '🍵 Replace one sugary drink with herbal tea or water — it adds up quickly.',
    ];
    final tip = tips[dayOfYear % tips.length];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [SeniorStyles.primaryBlue, Colors.blue.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.tips_and_updates, color: Colors.amber, size: 26),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text("Today's Health Tip",
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(tip, style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.6, fontWeight: FontWeight.w500)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.spa_outlined),
                  label: const Text('See Wellness Habits'),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() => index = 4); // Go to Wellness tab
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: SeniorStyles.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    if (auth.user == null) {
      _tipShown = false; // reset on logout
      return const LoginScreen();
    }

    // If user is authenticated but not onboarded natively or locally, force Onboarding Screen
    if (auth.dbUser != null && auth.dbUser!['onboarded'] != true && !auth.hasOnboardedLocally) {
      return const OnboardingScreen();
    }

    // Show daily tip once per session after login
    if (!_tipShown && auth.dbUser != null) {
      _tipShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showDailyTip(context));
    }

    if (auth.useBiometrics && !_identifiedWithBiometrics) {
      return Scaffold(
        backgroundColor: SeniorStyles.backgroundGray,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fingerprint, size: 80, color: SeniorStyles.primaryBlue),
              const SizedBox(height: 24),
              const Text("App Locked", style: SeniorStyles.header),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SeniorStyles.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _authenticateBiometrics,
                icon: const Icon(Icons.lock_open),
                label: const Text("Unlock with Biometrics", style: SeniorStyles.largeButtonText),
              ),
            ],
          ),
        ),
      );
    }

    final isCaregiver = auth.dbUser?['role'] == 'caregiver';

    final activeScreens = isCaregiver 
      ? [const CaregiverDashboard(), const ProfileScreen()]
      : [const SeniorDashboardScreen(), const MedicationScreen(), const HealthScreen(), const SOSScreen(), const RoutineScreen(), const WellnessScreen(), const ProfileScreen()];

    // Ensure index doesn't go out of bounds when switching roles
    if (index >= activeScreens.length) {
      index = 0;
    }

    return Scaffold(
      body: activeScreens[index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          child: NavigationBar(
            height: 80,
            backgroundColor: Colors.white,
            indicatorColor: SeniorStyles.primaryBlue.withOpacity(0.1),
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => index = i),
            destinations: isCaregiver
              ? const [
                  NavigationDestination(icon: Icon(Icons.people_alt, size: 30), label: "Dashboard"),
                  NavigationDestination(icon: Icon(Icons.person, size: 30), label: "Profile"),
                ]
              : const [
                  NavigationDestination(icon: Icon(Icons.dashboard_rounded, size: 30), label: "Home"),
                  NavigationDestination(icon: Icon(Icons.medication, size: 30), label: "Meds"),
                  NavigationDestination(icon: Icon(Icons.favorite, size: 30), label: "Health"),
                  NavigationDestination(
                    icon: CircleAvatar(
                      backgroundColor: SeniorStyles.alertRed,
                      radius: 25,
                      child: Icon(Icons.warning_amber_rounded, color: Colors.white, size: 30),
                    ),
                    label: "SOS",
                  ),
                  NavigationDestination(icon: Icon(Icons.task_alt, size: 30), label: "Daily"),
                  NavigationDestination(icon: Icon(Icons.spa_outlined, size: 30), label: "Wellness"),
                  NavigationDestination(icon: Icon(Icons.person, size: 30), label: "Profile"),
                ],
          ),
        ),
      ),
    );
  }
}
