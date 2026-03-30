import 'package:flutter/material.dart';
import 'package:seniorsync/frontend/modules/shared/senior_styles.dart';
import 'package:seniorsync/backend/modules/medication/medication_service.dart';
import 'package:seniorsync/backend/modules/health/health_service.dart';
import 'package:seniorsync/backend/modules/routine/routine_service.dart';
import 'package:seniorsync/backend/modules/medication/medication_model.dart';
import 'package:seniorsync/backend/modules/health/vitals_model.dart';
import 'package:seniorsync/backend/modules/routine/routine_model.dart';

class SeniorDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> senior;

  const SeniorDetailsScreen({super.key, required this.senior});

  @override
  State<SeniorDetailsScreen> createState() => _SeniorDetailsScreenState();
}

class _SeniorDetailsScreenState extends State<SeniorDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  List<Medication> _medications = [];
  List<Vitals> _vitals = [];
  List<Routine> _routines = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSeniorData();
  }

  Future<void> _loadSeniorData() async {
    setState(() => _isLoading = true);
    final uid = widget.senior['firebaseUid'];
    try {
      final medService = MedicationService(userId: uid);
      final healthService = HealthService(userId: uid);
      final routineService = RoutineService(userId: uid);

      final meds = await medService.fetchMedications();
      final vitals = await healthService.fetchVitals();
      final routines = await routineService.fetchRoutines();

      setState(() {
        _medications = meds;
        _vitals = vitals;
        _routines = routines;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading details: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeniorStyles.backgroundGray,
      appBar: AppBar(
        title: Text(widget.senior['name'] ?? 'Senior Details', style: SeniorStyles.header),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: SeniorStyles.primaryBlue,
          unselectedLabelColor: Colors.black54,
          indicatorColor: SeniorStyles.primaryBlue,
          tabs: const [
            Tab(icon: Icon(Icons.medication), text: "Meds"),
            Tab(icon: Icon(Icons.task_alt), text: "Routines"),
            Tab(icon: Icon(Icons.favorite), text: "Vitals"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSeniorData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMedsTab(),
                  _buildRoutinesTab(),
                  _buildVitalsTab(),
                ],
              ),
            ),
    );
  }

  Widget _buildMedsTab() {
    if (_medications.isEmpty) {
      return const Center(child: Text("No medications recorded.", style: SeniorStyles.cardSubtitle));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _medications.length,
      itemBuilder: (context, index) {
        final med = _medications[index];
        bool isTaken = med.status == MedicationStatus.taken;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(
              isTaken ? Icons.check_circle : Icons.warning_amber_rounded,
              color: isTaken ? SeniorStyles.successGreen : SeniorStyles.warningOrange,
              size: 32,
            ),
            title: Text(med.name, style: SeniorStyles.cardTitle),
            subtitle: Text("${med.dosage} • ${med.timeOfDay.format(context)}"),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isTaken ? SeniorStyles.successGreen.withOpacity(0.1) : SeniorStyles.alertRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isTaken ? "TAKEN" : "PENDING",
                style: TextStyle(
                  color: isTaken ? SeniorStyles.successGreen : SeniorStyles.alertRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoutinesTab() {
    if (_routines.isEmpty) {
      return const Center(child: Text("No routines recorded.", style: SeniorStyles.cardSubtitle));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _routines.length,
      itemBuilder: (context, index) {
        final routine = _routines[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(
              routine.isCompletedToday ? Icons.check_circle : Icons.circle_outlined,
              color: routine.isCompletedToday ? SeniorStyles.successGreen : SeniorStyles.primaryBlue,
              size: 32,
            ),
            title: Text(routine.title, style: SeniorStyles.cardTitle),
            subtitle: Text(routine.time.format(context)),
            trailing: Text(
              "Streak: ${routine.streak} 🔥",
              style: TextStyle(
                color: routine.streak > 0 ? SeniorStyles.warningOrange : Colors.black38,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVitalsTab() {
    if (_vitals.isEmpty) {
      return const Center(child: Text("No past vitals recorded.", style: SeniorStyles.cardSubtitle));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _vitals.length,
      itemBuilder: (context, index) {
        final vital = _vitals[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatTimestamp(vital.timestamp),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildVitalStat(Icons.favorite, "${vital.heartRate} bpm", Colors.redAccent),
                    _buildVitalStat(Icons.water_drop, "${vital.bloodSugar} mg/dL", Colors.blue),
                    _buildVitalStat(Icons.speed, vital.bloodPressure, Colors.orange),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime dt) {
    final d = dt.toLocal();
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final amPm = d.hour >= 12 ? 'PM' : 'AM';
    final min = d.minute.toString().padLeft(2, '0');
    return "${d.day}/${d.month}/${d.year}  $hour:$min $amPm";
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
