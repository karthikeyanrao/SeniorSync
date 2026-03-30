import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:seniorsync/frontend/modules/shared/senior_styles.dart';

class PrescriptionScannerScreen extends StatefulWidget {
  const PrescriptionScannerScreen({super.key});

  @override
  State<PrescriptionScannerScreen> createState() => _PrescriptionScannerScreenState();
}

class _PrescriptionScannerScreenState extends State<PrescriptionScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _isScanning = false;

  Future<void> _scanImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return;

      setState(() => _isScanning = true);

      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      String rawText = recognizedText.text;
      
      // Basic extraction effort
      String extractedName = "";
      String extractedDosage = "";
      
      final lines = rawText.split('\n');
      if (lines.isNotEmpty) {
        // Try to guess name (usually large text at top)
        extractedName = lines.first;
      }
      
      for (String line in lines) {
        final text = line.toLowerCase();
        if (text.contains("mg") || text.contains("ml") || text.contains("pill") || text.contains("tablet")) {
          extractedDosage = line;
          break;
        }
      }

      if (mounted) {
        Navigator.pop(context, {
          'name': extractedName, 
          'dosage': extractedDosage,
          'notes': "Scanned raw text:\n$rawText",
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error scanning: $e')));
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeniorStyles.backgroundGray,
      appBar: AppBar(
        title: const Text("Scan Prescription", style: SeniorStyles.header),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: _isScanning
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Analyzing label...", style: SeniorStyles.subheader)
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.document_scanner, size: 80, color: SeniorStyles.primaryBlue),
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      "Scan your pill bottle or prescription label to automatically extract the name and dosage.",
                      textAlign: TextAlign.center,
                      style: SeniorStyles.cardSubtitle,
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: 250,
                    height: 60,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("Open Camera", style: SeniorStyles.largeButtonText),
                      style: ElevatedButton.styleFrom(backgroundColor: SeniorStyles.primaryBlue, foregroundColor: Colors.white),
                      onPressed: () => _scanImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 250,
                    height: 60,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text("Choose from Gallery", style: SeniorStyles.largeButtonText),
                      style: OutlinedButton.styleFrom(foregroundColor: SeniorStyles.primaryBlue, side: const BorderSide(color: SeniorStyles.primaryBlue, width: 2)),
                      onPressed: () => _scanImage(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
