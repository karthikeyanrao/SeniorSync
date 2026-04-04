
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seniorsync/backend/modules/routine/routine_model.dart';
import 'package:seniorsync/backend/modules/routine/routine_service.dart';
import 'package:seniorsync/backend/modules/profile/auth_service.dart';
import 'package:seniorsync/frontend/modules/shared/senior_styles.dart';
import 'package:seniorsync/backend/modules/shared/notification_service.dart';

class RoutineScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const RoutineScreen({super.key, this.onBack});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> with SingleTickerProviderStateMixin {
  late RoutineService _routineService;
  late TabController _tabController;
  List<Routine> _routines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.user != null) {
      _routineService = RoutineService(userId: auth.user!.uid);
      _loadRoutines();
    }
  }

  Future<void> _loadRoutines() async {
    setState(() => _isLoading = true);
    try {
      final routines = await _routineService.fetchRoutines();
      setState(() => _routines = routines);
      await _scheduleAllRoutineReminders(routines);
    } catch (e) {
      _showSnack("Error loading routines: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _scheduleAllRoutineReminders(List<Routine> routines) async {
    try {
      final notifService = NotificationService();
      for (int i = 0; i < routines.length; i++) {
        final routine = routines[i];
        await notifService.scheduleRoutineReminder(
          id: 2000 + i,
          routineTitle: routine.title,
          timeOfDay: routine.time,
          days: routine.days,
        );
      }
    } catch (e) {
      debugPrint('[Notifications] Alarm scheduling skipped: $e');
    }
  }

  Future<void> _completeRoutine(Routine routine) async {
    if (routine.isCompletedToday) return;
    try {
      await _routineService.completeRoutine(routine.id!);
      _loadRoutines();
      _showSnack("Great job! Streak: ${routine.streak + 1} 🔥");
    } catch (e) {
      _showSnack("Error completing routine");
    }
  }

  Future<void> _deleteRoutine(Routine routine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Task?"),
        content: Text("Are you sure you want to delete \"${routine.title}\"?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: SeniorStyles.alertRed),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final index = _routines.indexOf(routine);
        await NotificationService().cancelNotification(2000 + index);
        await _routineService.deleteRoutine(routine.id!);
        _loadRoutines();
        _showSnack("Task deleted");
      } catch (e) {
        _showSnack("Error deleting: $e");
      }
    }
  }

  Future<void> _addOrEditRoutine({Routine? existingRoutine}) async {
    final titleController = TextEditingController(text: existingRoutine?.title ?? '');
    TimeOfDay selectedTime = existingRoutine?.time ?? TimeOfDay.now();
    List<String> selectedDays = existingRoutine?.days ?? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    const allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existingRoutine == null ? "Add New Task" : "Edit Task", style: SeniorStyles.header),
              const SizedBox(height: 24),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: "Task Name",
                  prefixIcon: Icon(Icons.task_alt),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Scheduled Time", style: TextStyle(fontSize: 18)),
                subtitle: Text(selectedTime.format(context), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: SeniorStyles.primaryBlue)),
                trailing: const Icon(Icons.access_time, color: SeniorStyles.primaryBlue),
                onTap: () async {
                  final time = await showTimePicker(context: context, initialTime: selectedTime);
                  if (time != null) setSheetState(() => selectedTime = time);
                },
              ),
              const SizedBox(height: 16),
              const Text("Repeat Days", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: allDays.map((day) {
                  final isSelected = selectedDays.contains(day);
                  return FilterChip(
                    label: Text(day),
                    selected: isSelected,
                    selectedColor: SeniorStyles.primaryBlue.withOpacity(0.2),
                    onSelected: (bool selected) {
                      setSheetState(() {
                        if (selected) {
                          selectedDays.add(day);
                        } else {
                          selectedDays.remove(day);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.isNotEmpty && selectedDays.isNotEmpty) {
                      if (existingRoutine == null) {
                        final newRoutine = Routine(
                          title: titleController.text,
                          time: selectedTime,
                          days: selectedDays,
                        );
                        await _routineService.addRoutine(newRoutine);
                      } else {
                        final updatedRoutine = existingRoutine.copyWith(
                          title: titleController.text,
                          time: selectedTime,
                          days: selectedDays,
                        );
                        await _routineService.updateRoutine(updatedRoutine);
                      }
                      if (context.mounted) Navigator.pop(context);
                      _loadRoutines();
                    } else if (selectedDays.isEmpty) {
                      _showSnack("Please select at least one day!");
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: SeniorStyles.primaryBlue, foregroundColor: Colors.white),
                  child: Text(existingRoutine == null ? "Add Task" : "Save Changes", style: SeniorStyles.largeButtonText),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeniorStyles.backgroundGray,
      appBar: AppBar(
        leading: widget.onBack != null ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack) : null,
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text("Daily Routine", style: SeniorStyles.header),
        actions: [
          IconButton(onPressed: _loadRoutines, icon: const Icon(Icons.refresh, color: SeniorStyles.primaryBlue)),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: SeniorStyles.primaryBlue,
          unselectedLabelColor: Colors.black38,
          indicatorColor: SeniorStyles.primaryBlue,
          indicatorWeight: 4,
          labelStyle: SeniorStyles.subheader,
          tabs: const [
            Tab(text: "Today's Tasks"),
            Tab(text: "All List"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRoutines,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRoutineList(isTodayOnly: true),
                  _buildRoutineList(isTodayOnly: false),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: SeniorStyles.primaryBlue,
        onPressed: _addOrEditRoutine,
        tooltip: 'Add Task',
        child: const Icon(Icons.add_task, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildRoutineList({required bool isTodayOnly}) {
    final todayStr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][DateTime.now().weekday - 1];
    
    final displayRoutines = isTodayOnly 
      ? _routines.where((r) => r.days.contains(todayStr)).toList()
      : _routines;

    if (displayRoutines.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.checklist, size: 80, color: Colors.grey.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  const Text("No routine tasks yet", style: SeniorStyles.subheader),
                  const SizedBox(height: 8),
                  const Text("Add tasks to build healthy habits", style: SeniorStyles.cardSubtitle),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: displayRoutines.length,
      itemBuilder: (context, index) {
        final routine = displayRoutines[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: SeniorStyles.cardDecoration,
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: routine.isCompletedToday ? SeniorStyles.successGreen.withOpacity(0.15) : SeniorStyles.primaryBlue.withOpacity(0.1),
                child: Icon(
                  routine.isCompletedToday ? Icons.check : Icons.circle_outlined,
                  color: routine.isCompletedToday ? SeniorStyles.successGreen : SeniorStyles.primaryBlue,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routine.title,
                      style: SeniorStyles.cardTitle.copyWith(
                        decoration: routine.isCompletedToday ? TextDecoration.lineThrough : null,
                        color: routine.isCompletedToday ? Colors.black38 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: Colors.black38),
                          const SizedBox(width: 4),
                          Text(routine.time.format(context), style: SeniorStyles.cardSubtitle),
                          const SizedBox(width: 12),
                          Icon(Icons.local_fire_department, size: 16, color: routine.streak > 0 ? SeniorStyles.warningOrange : Colors.black38),
                          const SizedBox(width: 4),
                          Text("${routine.streak} days", style: SeniorStyles.cardSubtitle.copyWith(color: routine.streak > 0 ? SeniorStyles.warningOrange : Colors.black38)),
                        ],
                      ),
                    ),
                    if (!isTodayOnly)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(routine.days.join(', '), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                  ],
                ),
              ),
              Column(
                children: [
                  if (routine.isCompletedToday)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.celebration, color: SeniorStyles.warningOrange, size: 28),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline, color: SeniorStyles.successGreen, size: 32),
                      onPressed: () => _completeRoutine(routine),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: SeniorStyles.primaryBlue, size: 22),
                        onPressed: () => _addOrEditRoutine(existingRoutine: routine),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.grey.shade400, size: 22),
                        onPressed: () => _deleteRoutine(routine),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
