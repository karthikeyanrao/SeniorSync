import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seniorsync/backend/modules/medication/medication_model.dart';
import 'package:seniorsync/backend/modules/medication/medication_service.dart';
import 'package:seniorsync/backend/modules/health/health_service.dart';
import 'package:seniorsync/backend/modules/health/vitals_model.dart';
import 'package:seniorsync/backend/modules/routine/routine_model.dart';
import 'package:seniorsync/backend/modules/routine/routine_service.dart';
import 'package:seniorsync/backend/modules/profile/auth_service.dart';
import 'package:seniorsync/frontend/modules/shared/senior_styles.dart';

class SeniorDashboardScreen extends StatefulWidget {
  const SeniorDashboardScreen({super.key});

  @override
  State<SeniorDashboardScreen> createState() => _SeniorDashboardScreenState();
}

class _SeniorDashboardScreenState extends State<SeniorDashboardScreen> {
  bool _isLoading = true;
  List<Medication> _upcomingMeds = [];
  List<Routine> _todayRoutines = [];
  Vitals? _latestVitals;
  String _greeting = "Good Morning";
  double _dailyProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _updateGreeting();
    _loadAllData();
  }

  void _updateGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = "Good Morning";
    } else if (hour < 17) {
      _greeting = "Good Afternoon";
    } else {
      _greeting = "Good Evening";
    }
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.user == null) return;

    try {
      final medService = MedicationService(userId: auth.user!.uid);
      final healthService = HealthService(userId: auth.user!.uid);
      final routineService = RoutineService(userId: auth.user!.uid);

      final results = await Future.wait([
        medService.fetchMedications(),
        healthService.fetchVitals(),
        routineService.fetchRoutines(),
      ]);

      final allMeds = results[0] as List<Medication>;
      final allVitals = results[1] as List<Vitals>;
      final allRoutines = results[2] as List<Routine>;

      final now = DateTime.now();
      final todayStr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][now.weekday - 1];

      if (mounted) {
        setState(() {
          final allTodayMeds = allMeds.toList(); // Assuming fetching for today
          _upcomingMeds = allTodayMeds.where((m) => m.status == MedicationStatus.scheduled || m.status == MedicationStatus.snoozed).toList();
          _upcomingMeds.sort((a, b) => (a.timeOfDay.hour * 60 + a.timeOfDay.minute).compareTo(b.timeOfDay.hour * 60 + b.timeOfDay.minute));
          
          _todayRoutines = allRoutines.where((r) => r.days.contains(todayStr)).toList();
          
          // Calculate overall progress stats
          int totalMeds = allTodayMeds.length;
          int completedMeds = allTodayMeds.where((m) => m.status == MedicationStatus.taken).length;
          int totalRoutines = _todayRoutines.length;
          int completedRoutines = _todayRoutines.where((r) => r.isCompletedToday).length;
          
          _dailyProgress = (totalMeds + totalRoutines) > 0 
              ? (completedMeds + completedRoutines) / (totalMeds + totalRoutines)
              : 0.0;
          
          if (allVitals.isNotEmpty) {
            _latestVitals = allVitals.first;
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      print("[Dashboard] Error loading data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final userName = auth.dbUser?['name']?.split(' ').first ?? "there";

    return Scaffold(
      backgroundColor: SeniorStyles.backgroundGray,
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 140,
              floating: false,
              pinned: true,
              backgroundColor: SeniorStyles.primaryBlue,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                title: Text("Hello, $userName", 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [SeniorStyles.primaryBlue, SeniorStyles.primaryBlue.withOpacity(0.8)],
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(_greeting, style: SeniorStyles.subheader),
                  const SizedBox(height: 20),
                  
                  // Summary Card
                  _buildSummaryCard(),
                  const SizedBox(height: 30),

                  // Medication Row
                  _buildSectionHeader("Medications Today", Icons.medication, () {
                    // Navigate to Meds tab
                  }),
                  const SizedBox(height: 12),
                  _buildMedicationSummary(),
                  const SizedBox(height: 30),

                  // Health Row
                  _buildSectionHeader("Latest Vitals", Icons.favorite, () {
                    // Navigate to Health tab
                  }),
                  const SizedBox(height: 12),
                  _buildVitalsCard(),
                  const SizedBox(height: 30),

                  // Routine Row
                  _buildSectionHeader("Daily Routine", Icons.task_alt, () {
                    // Navigate to Routine tab
                  }),
                  const SizedBox(height: 12),
                  _buildRoutineSummary(),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: SeniorStyles.primaryBlue, size: 24),
            const SizedBox(width: 8),
            Text(title, style: SeniorStyles.subheader),
          ],
        ),
        TextButton(
          onPressed: onTap,
          child: const Text("View All"),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: SeniorStyles.softShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Today's Progress", style: TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("${_upcomingMeds.length} medicines left", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: SeniorStyles.primaryBlue)),
                Text("${_todayRoutines.where((r) => !r.isCompletedToday).length} tasks remaining", style: const TextStyle(fontSize: 16, color: Colors.black45)),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 70,
                width: 70,
                child: CircularProgressIndicator(
                  value: _dailyProgress,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey.shade100,
                  color: SeniorStyles.successGreen,
                ),
              ),
              Text("${(_dailyProgress * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationSummary() {
    if (_upcomingMeds.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: SeniorStyles.cardDecoration,
        child: const Center(child: Text("No more medications for today!", style: TextStyle(color: Colors.black45))),
      );
    }

    final nextMed = _upcomingMeds.first;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SeniorStyles.cardDecoration,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: SeniorStyles.primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.medication, color: SeniorStyles.primaryBlue, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Next: ${nextMed.name}", style: SeniorStyles.cardTitle.copyWith(fontSize: 18)),
                Text("${nextMed.dosage} at ${nextMed.timeOfDay.format(context)}", style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.black26),
        ],
      ),
    );
  }

  Widget _buildVitalsCard() {
    if (_latestVitals == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: SeniorStyles.cardDecoration,
        child: const Center(child: Text("No vitals recorded recently.", style: TextStyle(color: Colors.black45))),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SeniorStyles.cardDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildVitalStat(Icons.favorite, "${_latestVitals!.heartRate}", "bpm", Colors.redAccent),
          _buildVitalStat(Icons.speed, _latestVitals!.bloodPressure, "mmHg", Colors.blue),
          _buildVitalStat(Icons.water_drop, "${_latestVitals!.bloodSugar}", "mg/dL", Colors.orange),
        ],
      ),
    );
  }

  Widget _buildVitalStat(IconData icon, String value, String unit, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(unit, style: const TextStyle(fontSize: 12, color: Colors.black38)),
      ],
    );
  }

  Widget _buildRoutineSummary() {
    final pending = _todayRoutines.where((r) => !r.isCompletedToday).toList();
    if (pending.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: SeniorStyles.cardDecoration,
        child: const Center(child: Text("All daily tasks completed! 🎉", style: TextStyle(color: SeniorStyles.successGreen, fontWeight: FontWeight.bold))),
      );
    }

    final nextTask = pending.first;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SeniorStyles.cardDecoration,
      child: Row(
        children: [
          const Icon(Icons.circle_outlined, color: SeniorStyles.primaryBlue),
          const SizedBox(width: 16),
          Expanded(
            child: Text(nextTask.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          ),
          Text(nextTask.time.format(context), style: const TextStyle(color: SeniorStyles.primaryBlue, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
