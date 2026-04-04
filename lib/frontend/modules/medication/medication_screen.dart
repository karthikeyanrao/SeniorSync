
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seniorsync/backend/modules/medication/medication_model.dart';
import 'package:seniorsync/backend/modules/medication/medication_service.dart';
import 'package:seniorsync/backend/modules/profile/auth_service.dart';
import 'package:seniorsync/frontend/modules/shared/senior_styles.dart';
import 'add_medication_screen.dart';
import 'package:seniorsync/backend/modules/shared/notification_service.dart';

class MedicationScreen extends StatefulWidget {
  const MedicationScreen({super.key});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late MedicationService _medService;
  List<Medication> _medications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.user != null) {
      _medService = MedicationService(userId: auth.user!.uid);
      _loadMedications();
    }
  }

  Future<void> _loadMedications() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final meds = await _medService.fetchMedications();
      if (mounted) setState(() => _medications = meds);
      // Reschedule all local notifications whenever list is refreshed
      await _scheduleAllMedReminders(meds);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _scheduleAllMedReminders(List<Medication> meds) async {
    try {
      final notifService = NotificationService();
      for (int i = 0; i < meds.length; i++) {
        final med = meds[i];
        if (med.status == MedicationStatus.scheduled) {
          await notifService.scheduleMedicationReminder(
            id: 1000 + i,
            medName: med.name,
            dosage: med.dosage,
            timeOfDay: med.timeOfDay,
          );
        }
      }
    } catch (e) {
      debugPrint('[Notifications] Med alarm scheduling skipped: $e');
    }
  }

  Future<void> _updateStatus(Medication med, MedicationStatus status) async {
    String? reason;
    if (status == MedicationStatus.skipped) {
      reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Why are you skipping?"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _reasonTile("Not feeling well", (v) => Navigator.pop(context, v)),
              _reasonTile("Feeling nauseous", (v) => Navigator.pop(context, v)),
              _reasonTile("Already took it", (v) => Navigator.pop(context, v)),
              _reasonTile("Doctor's instruction", (v) => Navigator.pop(context, v)),
              _reasonTile("Other", (v) => Navigator.pop(context, v)),
            ],
          ),
        ),
      );
      if (reason == null) return; // User cancelled
    }

    final index = _medications.indexWhere((m) => m.id == med.id);
    if (index == -1) return;
    final updated = med.copyWith(status: status, skippedReason: reason);
    
    setState(() => _medications[index] = updated);

    try {
      await _medService.updateMedication(updated);
    } catch (e) {
      if (mounted) setState(() => _medications[index] = med);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Action failed")));
    }
  }

  Widget _reasonTile(String text, Function(String) onTap) {
    return ListTile(
      title: Text(text, style: const TextStyle(fontSize: 18)),
      onTap: () => onTap(text),
    );
  }

  Future<void> _deleteMedication(Medication med) async {
    if (med.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Item hasn't synced yet, cannot delete immediately.")));
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Medicine"),
        content: Text("Delete '${med.name}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Delete", style: TextStyle(color: SeniorStyles.alertRed))
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final index = _medications.indexOf(med);
    setState(() => _medications.removeAt(index));

    try {
      await _medService.deleteMedication(med.id!);
    } catch (e) {
      if (mounted) {
        setState(() => _medications.insert(index, med));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Delete failed")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeniorStyles.backgroundGray,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text("My Medicines", style: SeniorStyles.header),
        bottom: TabBar(
          controller: _tabController,
          labelColor: SeniorStyles.primaryBlue,
          unselectedLabelColor: Colors.black38,
          indicatorColor: SeniorStyles.primaryBlue,
          indicatorWeight: 4,
          labelStyle: SeniorStyles.subheader,
          tabs: const [
            Tab(text: "Tasks"),
            Tab(text: "History"),
            Tab(text: "List"),
          ],
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMedications,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUpcomingTab(),
                  _buildHistoryTab(),
                  _buildManageTab(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: SeniorStyles.primaryBlue,
        onPressed: () async {
          final success = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddMedicationScreen()));
          if (success == true) _loadMedications();
        },
        tooltip: 'Add Medicine',
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildUpcomingTab() {
    final now = DateTime.now();

    // List of doses where time is strictly past and within the 30 min window (not officially transitioned to missed yet)
    final missed = _medications.where((m) {
      if (m.status == MedicationStatus.taken || m.status == MedicationStatus.skipped || m.status == MedicationStatus.missed) return false;
      final medTime = DateTime(now.year, now.month, now.day, m.timeOfDay.hour, m.timeOfDay.minute);
      return medTime.isBefore(now);
    }).toList();

    // List of doses where time is either current or upcoming today
    final upcoming = _medications.where((m) {
      if (m.status != MedicationStatus.scheduled && m.status != MedicationStatus.snoozed) return false;
      final medTime = DateTime(now.year, now.month, now.day, m.timeOfDay.hour, m.timeOfDay.minute);
      return medTime.isAfter(now) || medTime.isAtSameMomentAs(now);
    }).toList();

    if (missed.isEmpty && upcoming.isEmpty) {
      return _buildEmptyState("All caught up!", "No medications left for today.");
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (upcoming.isNotEmpty) ..._buildTimeSection("Upcoming Doses", upcoming, Icons.access_time_filled, SeniorStyles.primaryBlue),
        if (missed.isNotEmpty) ..._buildTimeSection("Missed Doses", missed, Icons.warning_amber_rounded, SeniorStyles.alertRed),
        const SizedBox(height: 80),
      ],
    );
  }

  List<Widget> _buildTimeSection(String title, List<Medication> meds, IconData icon, Color color) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 8),
            Text(title, style: SeniorStyles.subheader),
          ],
        ),
      ),
      ...meds.map((m) => _SeniorMedCard(
            medication: m,
            onTaken: () => _updateStatus(m, MedicationStatus.taken),
            onSkipped: () => _updateStatus(m, MedicationStatus.skipped),
            onSnooze: () => _updateStatus(m, MedicationStatus.snoozed),
          )),
    ];
  }

  Widget _buildHistoryTab() {
    final history = _medications.where((m) => m.status == MedicationStatus.taken || m.status == MedicationStatus.skipped || m.status == MedicationStatus.missed).toList();
    if (history.isEmpty) return _buildEmptyState("Nothing here yet", "Completed tasks will appear here.");
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final m = history[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(
              m.status == MedicationStatus.taken ? Icons.check_circle : Icons.cancel,
              color: m.status == MedicationStatus.taken ? SeniorStyles.successGreen : SeniorStyles.alertRed,
              size: 32,
            ),
            title: Text(m.name, style: SeniorStyles.cardTitle),
            subtitle: Text("${m.dosage} • ${m.status.name.toUpperCase()}"),
            // No revert option for history doses
          ),
        );
      },
    );
  }

  Widget _buildManageTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _medications.length,
      itemBuilder: (context, index) {
        final m = _medications[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(m.name, style: SeniorStyles.cardTitle),
            subtitle: Text("${m.dosage} at ${m.timeOfDay.format(context)}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: SeniorStyles.alertRed),
                  onPressed: () => _deleteMedication(m),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () async {
              final success = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddMedicationScreen(initialMedication: m)));
              if (success == true) _loadMedications();
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String sub) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medication_liquid_sharp, size: 100, color: Colors.grey.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(title, style: SeniorStyles.subheader),
          Text(sub, style: SeniorStyles.cardSubtitle),
        ],
      ),
    );
  }
}

class _SeniorMedCard extends StatelessWidget {
  final Medication medication;
  final VoidCallback onTaken;
  final VoidCallback onSkipped;
  final VoidCallback onSnooze;

  const _SeniorMedCard({required this.medication, required this.onTaken, required this.onSkipped, required this.onSnooze});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: SeniorStyles.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(medication.name, style: SeniorStyles.cardTitle),
                    Text(medication.dosage, style: SeniorStyles.cardSubtitle),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: SeniorStyles.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  medication.timeOfDay.format(context),
                  style: const TextStyle(color: SeniorStyles.primaryBlue, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onTaken,
                  icon: const Icon(Icons.check, size: 28),
                  label: const Text("I TOOK IT", style: SeniorStyles.largeButtonText),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SeniorStyles.successGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSkipped,
                  icon: const Icon(Icons.close, size: 24),
                  label: const Text("SKIP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: SeniorStyles.alertRed, width: 2),
                    foregroundColor: SeniorStyles.alertRed,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSnooze,
                  icon: const Icon(Icons.snooze, size: 24),
                  label: const Text("SNOOZE", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: SeniorStyles.warningOrange, width: 2),
                    foregroundColor: SeniorStyles.warningOrange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
