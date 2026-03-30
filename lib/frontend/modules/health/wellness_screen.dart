import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seniorsync/backend/modules/profile/auth_service.dart';
import 'package:seniorsync/backend/modules/routine/routine_service.dart';
import 'package:seniorsync/backend/modules/routine/routine_model.dart';
import 'package:seniorsync/backend/modules/shared/notification_service.dart';
import 'package:seniorsync/frontend/modules/shared/senior_styles.dart';

// ─── Static data ────────────────────────────────────────────────────────────

class _Recommendation {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String defaultTime; // for time picker hint

  const _Recommendation({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.defaultTime,
  });
}

const _recommendations = [
  _Recommendation(
    title: 'Morning Walk',
    description: '20 minutes of light walking improves circulation and mood.',
    icon: Icons.directions_walk,
    color: Colors.green,
    defaultTime: '06:30',
  ),
  _Recommendation(
    title: 'Drink a Glass of Water',
    description: 'Start the day hydrated. Aim for 8 glasses throughout the day.',
    icon: Icons.water_drop,
    color: Colors.blue,
    defaultTime: '07:00',
  ),
  _Recommendation(
    title: 'Chair Yoga / Stretching',
    description: '15 minutes of gentle stretching reduces stiffness and joint pain.',
    icon: Icons.self_improvement,
    color: Colors.teal,
    defaultTime: '08:00',
  ),
  _Recommendation(
    title: 'Take Medications',
    description: 'Review and take scheduled medications on time.',
    icon: Icons.medication,
    color: Color(0xFF2196F3),
    defaultTime: '09:00',
  ),
  _Recommendation(
    title: 'Healthy Breakfast Check',
    description: 'Ensure a balanced meal with protein and fibre to fuel the morning.',
    icon: Icons.restaurant,
    color: Colors.orange,
    defaultTime: '07:30',
  ),
  _Recommendation(
    title: 'Read or Brain Exercise',
    description: 'Daily reading or puzzles keep the mind sharp and improve memory.',
    icon: Icons.menu_book,
    color: Colors.purple,
    defaultTime: '10:00',
  ),
  _Recommendation(
    title: 'Call Family / Friend',
    description: 'Social connection daily reduces isolation and improves mental health.',
    icon: Icons.phone_in_talk,
    color: Colors.pink,
    defaultTime: '11:00',
  ),
  _Recommendation(
    title: 'Post-lunch Rest',
    description: 'A short 20-minute rest after lunch restores energy safely.',
    icon: Icons.bedtime_outlined,
    color: Colors.indigo,
    defaultTime: '13:30',
  ),
  _Recommendation(
    title: 'Evening Vitals Check',
    description: 'Log blood pressure, heart rate and sugar once a day.',
    icon: Icons.favorite,
    color: Colors.red,
    defaultTime: '18:00',
  ),
  _Recommendation(
    title: 'Limit Screen Time',
    description: 'Reduce device use an hour before bed for better sleep quality.',
    icon: Icons.no_cell,
    color: Colors.brown,
    defaultTime: '21:00',
  ),
];

// ─── Tip of the Day (static, cycles daily) ──────────────────────────────────

const _dailyTips = [
  '💧 Drink a glass of water first thing in the morning — it kick-starts your metabolism!',
  '🚶 A 20-minute walk can lower blood pressure as effectively as medication for some people.',
  '😴 Going to bed at the same time each night improves sleep quality within just 2 weeks.',
  '🥗 Eating 5 servings of fruits and vegetables daily reduces your risk of heart disease by 20%.',
  '📞 Calling a friend or family member daily is one of the most powerful mood boosters.',
  '🧘 Five deep breaths right now will lower your heart rate and reduce stress hormones.',
  '💊 Taking medications at the exact same time each day improves their effectiveness.',
  '🌞 10 minutes of morning sunlight helps regulate your sleep cycle and boosts vitamin D.',
  '🧠 Reading for 30 minutes a day helps preserve memory and mental sharpness as you age.',
  '🍵 Replacing one sugary drink with herbal tea or water daily saves hundreds of calories a week.',
];

String get dailyTip {
  final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
  return _dailyTips[dayOfYear % _dailyTips.length];
}

// ─── Widget ─────────────────────────────────────────────────────────────────

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  late RoutineService _routineService;
  final Set<String> _addedTitles = {};

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.user != null) {
      _routineService = RoutineService(userId: auth.user!.uid);
    }
  }

  Future<void> _addToRoutine(_Recommendation rec) async {
    final defaultParts = rec.defaultTime.split(':');
    TimeOfDay initialTime = TimeOfDay(
      hour: int.parse(defaultParts[0]),
      minute: int.parse(defaultParts[1]),
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'What time for "${rec.title}"?',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: SeniorStyles.primaryBlue),
        ),
        child: child!,
      ),
    );

    if (picked == null || !mounted) return;

    try {
      final routine = Routine(
        title: rec.title,
        description: rec.description,
        time: picked,
        days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        isCompletedToday: false,
        streak: 0,
      );

      await _routineService.addRoutine(routine);

      // Schedule local notification
      final auth = Provider.of<AuthService>(context, listen: false);
      final List routines = await _routineService.fetchRoutines();
      final index = routines.length;
      await NotificationService().scheduleRoutineReminder(
        id: 2000 + index,
        routineTitle: rec.title,
        timeOfDay: picked,
        days: routine.days,
      );

      setState(() => _addedTitles.add(rec.title));

      if (mounted) {
        final h = picked.hour;
        final m = picked.minute.toString().padLeft(2, '0');
        final amPm = h >= 12 ? 'PM' : 'AM';
        final displayH = h > 12 ? h - 12 : (h == 0 ? 12 : h);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ "${rec.title}" added to Daily at $displayH:$m $amPm'),
          backgroundColor: SeniorStyles.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not add routine: $e'),
          backgroundColor: SeniorStyles.alertRed,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeniorStyles.backgroundGray,
      appBar: AppBar(
        title: const Text('Wellness', style: SeniorStyles.header),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Daily tip banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [SeniorStyles.primaryBlue, Colors.blue.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: SeniorStyles.primaryBlue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tips_and_updates, color: Colors.amber, size: 22),
                    SizedBox(width: 8),
                    Text("Today's Health Tip", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  dailyTip,
                  style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text('Recommended Daily Habits', style: SeniorStyles.subheader),
          const SizedBox(height: 6),
          const Text('Tap "+ Add to My Routine" to schedule any habit at a time that works for you.', style: SeniorStyles.cardSubtitle),
          const SizedBox(height: 14),

          // Recommendation cards
          ..._recommendations.map((rec) {
            final isAdded = _addedTitles.contains(rec.title);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: isAdded ? 0 : 2,
              color: isAdded ? Colors.green.shade50 : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: rec.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(rec.icon, color: rec.color, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rec.title, style: SeniorStyles.cardTitle),
                          const SizedBox(height: 4),
                          Text(rec.description, style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.4)),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: isAdded
                                ? Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: SeniorStyles.successGreen, size: 18),
                                      const SizedBox(width: 6),
                                      const Text('Added to Daily Routine', style: TextStyle(color: SeniorStyles.successGreen, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  )
                                : OutlinedButton.icon(
                                    icon: const Icon(Icons.add_task, size: 18),
                                    label: const Text('Add to My Routine'),
                                    onPressed: () => _addToRoutine(rec),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: rec.color,
                                      side: BorderSide(color: rec.color),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
