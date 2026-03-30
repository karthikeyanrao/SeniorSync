import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:seniorsync/frontend/modules/shared/senior_styles.dart';

class CaregiverQRScannerScreen extends StatefulWidget {
  const CaregiverQRScannerScreen({super.key});

  @override
  State<CaregiverQRScannerScreen> createState() => _CaregiverQRScannerScreenState();
}

class _CaregiverQRScannerScreenState extends State<CaregiverQRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Scan Senior's QR Code", style: SeniorStyles.header),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            color: SeniorStyles.primaryBlue,
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            color: SeniorStyles.primaryBlue,
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final rawValue = barcode.rawValue;
                if (rawValue != null && rawValue.startsWith("seniorsync_uid:")) {
                  _controller.stop(); // Stop scanning to prevent multiple pop
                  Navigator.pop(context, rawValue);
                  return;
                }
              }
            },
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Icon(Icons.qr_code_scanner, color: Colors.white, size: 80),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Center the QR code within the frame",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
