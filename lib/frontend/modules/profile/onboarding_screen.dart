import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seniorsync/backend/modules/profile/auth_service.dart';
import 'package:seniorsync/frontend/modules/shared/senior_styles.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _diseasesCtrl = TextEditingController();
  final _morningCtrl = TextEditingController(text: "08:00 AM");
  final _afternoonCtrl = TextEditingController(text: "01:00 PM");
  final _nightCtrl = TextEditingController(text: "07:00 PM");
  bool _isLoading = false;

  void _nextStep() {
    if (_step == 0) {
      if (_nameCtrl.text.isEmpty || _ageCtrl.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and age are required.')));
        return;
      }
    }
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final age = int.tryParse(_ageCtrl.text) ?? 60;
      final conditions = _diseasesCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final allergies = _allergiesCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      
      await auth.updateProfile(
        name: _nameCtrl.text,
        age: age,
        conditions: conditions,
        allergies: allergies,
        foodTimes: {
          'morning': _morningCtrl.text,
          'afternoon': _afternoonCtrl.text,
          'night': _nightCtrl.text,
        },
        onboarded: true,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Setup Profile", style: SeniorStyles.header),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_step == 0) _buildBasicInfo(),
                      if (_step == 1) _buildMedicalInfo(),
                      if (_step == 2) _buildDietInfo(),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _nextStep,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: SeniorStyles.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_step == 2 ? "Finish" : "Next", style: SeniorStyles.largeButtonText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Welcome to SeniorSync!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: SeniorStyles.primaryBlue)),
        const SizedBox(height: 16),
        const Text("Let's set up your profile so we can personalize your experience.", style: TextStyle(fontSize: 16)),
        const SizedBox(height: 24),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: "Your Full Name", border: OutlineInputBorder()),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _ageCtrl,
          decoration: const InputDecoration(labelText: "Your Age", border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildMedicalInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Health Information", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: SeniorStyles.primaryBlue)),
        const SizedBox(height: 16),
        const Text("Please list any allergies and chronic diseases (separated by commas).", style: TextStyle(fontSize: 16)),
        const SizedBox(height: 24),
        TextField(
          controller: _allergiesCtrl,
          decoration: const InputDecoration(labelText: "Allergies (e.g. Peanuts, Penicillin)", border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _diseasesCtrl,
          decoration: const InputDecoration(labelText: "Chronic Diseases (e.g. Diabetes, Hypertension)", border: OutlineInputBorder()),
        ),
      ],
    );
  }

  Widget _buildDietInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Meal Schedule", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: SeniorStyles.primaryBlue)),
        const SizedBox(height: 16),
        const Text("When do you usually have your meals? This helps us schedule your medications.", style: TextStyle(fontSize: 16)),
        const SizedBox(height: 24),
        TextField(
          controller: _morningCtrl,
          decoration: const InputDecoration(labelText: "Breakfast Time", border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _afternoonCtrl,
          decoration: const InputDecoration(labelText: "Lunch Time", border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nightCtrl,
          decoration: const InputDecoration(labelText: "Dinner Time", border: OutlineInputBorder()),
        ),
      ],
    );
  }
}
