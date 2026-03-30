
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seniorsync/backend/modules/medication/medication_model.dart';
import 'package:seniorsync/backend/modules/medication/medication_service.dart';
import 'package:seniorsync/backend/modules/profile/auth_service.dart';
import 'prescription_scanner.dart';
import 'package:seniorsync/frontend/modules/shared/senior_styles.dart';

class AddMedicationScreen extends StatefulWidget {
  final Medication? initialMedication;

  const AddMedicationScreen({super.key, this.initialMedication});

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _notesController;
  late TimeOfDay _timeOfDay;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialMedication?.name ?? '');
    _dosageController = TextEditingController(text: widget.initialMedication?.dosage ?? '');
    _timeOfDay = widget.initialMedication?.timeOfDay ?? const TimeOfDay(hour: 8, minute: 0);
    _notesController = TextEditingController(text: widget.initialMedication?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _launchScanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrescriptionScannerScreen()),
    );

    if (result != null && result is Map) {
       setState(() {
         if (result['name'] != null && result['name'] != '') {
           _nameController.text = result['name'];
         }
         if (result['dosage'] != null && result['dosage'] != '') {
           _dosageController.text = result['dosage'];
         }
         if (result['notes'] != null) {
           _notesController.text = result['notes'];
         }
       });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeOfDay,
    );
    if (picked != null) {
      setState(() => _timeOfDay = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isSaving = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final medService = MedicationService(userId: auth.user!.uid);

      final med = Medication(
        id: widget.initialMedication?.id,
        name: _nameController.text.trim(),
        dosage: _dosageController.text.trim(),
        timeOfDay: _timeOfDay,
        notes: _notesController.text.trim(),
        status: widget.initialMedication?.status ?? MedicationStatus.scheduled,
      );

      if (widget.initialMedication == null) {
        await medService.addMedication(med);
      } else {
        await medService.updateMedication(med);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeniorStyles.backgroundGray,
      appBar: AppBar(
        title: Text(widget.initialMedication == null ? "Add Medication" : "Edit Medication", style: SeniorStyles.header),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (widget.initialMedication == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SeniorStyles.successGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.document_scanner),
                    label: const Text("Scan Pill Bottle Label", style: SeniorStyles.largeButtonText),
                    onPressed: _launchScanner,
                  ),
                ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Medication Name",
                  prefixIcon: Icon(Icons.medication),
                  border: OutlineInputBorder(),
                  fillColor: Colors.white,
                  filled: true,
                ),
                validator: (v) => v == null || v.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dosageController,
                decoration: const InputDecoration(
                  labelText: "Dosage (e.g., 10mg, 1 tablet)",
                  prefixIcon: Icon(Icons.format_list_numbered),
                  border: OutlineInputBorder(),
                  fillColor: Colors.white,
                  filled: true,
                ),
                validator: (v) => v == null || v.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text("Reminder Time", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                subtitle: Text(_timeOfDay.format(context), style: const TextStyle(fontSize: 20, color: SeniorStyles.primaryBlue)),
                leading: const Icon(Icons.access_time, color: SeniorStyles.primaryBlue),
                trailing: const Icon(Icons.edit, color: SeniorStyles.primaryBlue),
                onTap: _selectTime,
                shape: RoundedRectangleEdges(),
                tileColor: Colors.white,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: "Notes (Optional)",
                  prefixIcon: Icon(Icons.note_alt_outlined),
                  border: OutlineInputBorder(),
                  fillColor: Colors.white,
                  filled: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  backgroundColor: SeniorStyles.primaryBlue,
                  foregroundColor: Colors.white,
                ),
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : Text(widget.initialMedication == null ? "Schedule Medication" : "Update Schedule", style: SeniorStyles.largeButtonText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoundedRectangleEdges extends ShapeBorder {
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)));
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}
