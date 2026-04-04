
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seniorsync/backend/modules/medication/medication_model.dart';
import 'package:seniorsync/backend/modules/medication/medication_service.dart';
import 'package:seniorsync/backend/modules/profile/auth_service.dart';
import 'package:seniorsync/frontend/modules/shared/senior_styles.dart';
import 'add_medication_screen.dart';
import 'package:seniorsync/backend/modules/shared/notification_service.dart';

class MedicationScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const MedicationScreen({super.key, this.onBack});

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
        leading: widget.onBack != null ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack) : null,
        backgroundColor: Colors.white,
        title: const Text("Medication Plan", style: SeniorStyles.header),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.black54,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            color: SeniorStyles.primaryBlue,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          tabs: const [
            Tab(child: Text("Tasks", style: TextStyle(fontWeight: FontWeight.bold))),
            Tab(child: Text("History", style: TextStyle(fontWeight: FontWeight.bold))),
            Tab(child: Text("All Meds", style: TextStyle(fontWeight: FontWeight.bold))),
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
        final isTaken = m.status == MedicationStatus.taken;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: SeniorStyles.cardDecoration,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: (isTaken ? SeniorStyles.successGreen : SeniorStyles.alertRed).withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(
                    m.medicineType == 'Syrup' ? Icons.water_drop : Icons.medication_rounded,
                    color: isTaken ? SeniorStyles.successGreen : SeniorStyles.alertRed
                  ),
                ),
                Icon(isTaken ? Icons.check_circle : Icons.cancel, color: isTaken ? Colors.green : Colors.red, size: 18),
              ],
            ),
            title: Text(m.name, style: SeniorStyles.cardTitle),
            subtitle: Text("${m.dosage} • ${isTaken ? 'Taken at' : 'Missed'}${isTaken ?' ' + m.timeOfDay.format(context) : ''}"),
          ),
        );
      },
    );
  }

  Widget _buildManageTab() {
    if (_medications.isEmpty) return _buildEmptyState("Your cabinet is empty", "Add your first medicine using the + button.");

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _medications.length,
      itemBuilder: (context, index) {
        final m = _medications[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: SeniorStyles.cardDecoration,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: SeniorStyles.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(
                m.medicineType == 'Syrup' ? Icons.water_drop : Icons.medication_rounded,
                color: SeniorStyles.primaryBlue
              ),
            ),
            title: Text(m.name, style: SeniorStyles.cardTitle),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text("${m.dosage} • ${m.timeOfDay.format(context)}", style: const TextStyle(color: Colors.black54)),
                if (m.foodTiming != null) 
                  Text(m.foodTiming!, style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: SeniorStyles.alertRed),
              onPressed: () => _deleteMedication(m),
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

  Color _getTimeColor() {
    final hour = medication.timeOfDay.hour;
    if (hour >= 5 && hour < 12) return Colors.orange.shade300; // Morning
    if (hour >= 12 && hour < 17) return Colors.blue.shade400; // Afternoon
    if (hour >= 17 && hour < 21) return Colors.deepOrange.shade400; // Evening
    return Colors.indigo.shade400; // Night
  }

  IconData _getTimeIcon() {
    final hour = medication.timeOfDay.hour;
    if (hour >= 5 && hour < 12) return Icons.wb_sunny_rounded;
    if (hour >= 12 && hour < 17) return Icons.light_mode_rounded;
    if (hour >= 17 && hour < 21) return Icons.wb_twilight_rounded;
    return Icons.bedtime_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final timeColor = _getTimeColor();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          // Header section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: timeColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Icon(_getTimeIcon(), color: timeColor, size: 24),
                const SizedBox(width: 10),
                Text(medication.timeOfDay.format(context), style: TextStyle(color: timeColor, fontWeight: FontWeight.bold, fontSize: 18)),
                const Spacer(),
                if (medication.foodTiming != null && medication.foodTiming != 'None')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Text(medication.foodTiming!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
                  ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: SeniorStyles.primaryBlue.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                      child: Icon(
                        medication.medicineType == 'Syrup' ? Icons.water_drop : Icons.medication_rounded,
                        color: SeniorStyles.primaryBlue, size: 32
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(medication.name, style: SeniorStyles.header.copyWith(fontSize: 20)),
                          const SizedBox(height: 4),
                          Text(medication.dosage, style: const TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
                
                if (medication.notes != null && medication.notes!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: SeniorStyles.backgroundGray, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Colors.black45),
                        const SizedBox(width: 8),
                        Expanded(child: Text(medication.notes!, style: const TextStyle(color: Colors.black54, fontSize: 13))),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: onTaken,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SeniorStyles.successGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline),
                            SizedBox(width: 8),
                            Text("DONE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _IconButton(icon: Icons.snooze, color: SeniorStyles.warningOrange, onTap: onSnooze),
                    const SizedBox(width: 12),
                    _IconButton(icon: Icons.close, color: SeniorStyles.alertRed, onTap: onSkipped),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}
