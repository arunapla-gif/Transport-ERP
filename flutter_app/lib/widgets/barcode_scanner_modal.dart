import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerModal extends StatefulWidget {
  final String title;
  final String subtitle;

  const BarcodeScannerModal({
    super.key,
    this.title = 'Scan E-Way Bill / Barcode',
    this.subtitle = 'Align QR code or 1D barcode inside the frame',
  });

  /// Opens the live camera scanner modal and returns the scanned code (or null if cancelled).
  static Future<String?> show(
    BuildContext context, {
    String title = 'Scan E-Way Bill / Barcode',
    String subtitle = 'Align QR code or 1D barcode inside the frame',
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BarcodeScannerModal(title: title, subtitle: subtitle),
    );
  }

  @override
  State<BarcodeScannerModal> createState() => _BarcodeScannerModalState();
}

class _BarcodeScannerModalState extends State<BarcodeScannerModal> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _hasPopped = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Extracts a clean 12-digit E-Way Bill number if embedded in a NIC QR payload,
  /// otherwise returns the trimmed barcode text.
  String _normalizeScanValue(String raw) {
    final trimmed = raw.trim();
    // NIC E-Way Bill QR codes often look like "552028120315/33AAUFA.../01-11-2026..."
    final ewbPrefixMatch = RegExp(r'^(\d{12})(?:[/|\s,-]|$)').firstMatch(trimmed);
    if (ewbPrefixMatch != null) {
      return ewbPrefixMatch.group(1)!;
    }
    final anyTwelveDigits = RegExp(r'\b(\d{12})\b').firstMatch(trimmed);
    if (anyTwelveDigits != null && trimmed.contains('/')) {
      return anyTwelveDigits.group(1)!;
    }
    return trimmed;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasPopped) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        _hasPopped = true;
        final cleaned = _normalizeScanValue(raw);
        Navigator.of(context).pop(cleaned);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.72;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF60A5FA), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Toggle Flashlight',
                  onPressed: () async {
                    await _controller.toggleTorch();
                    if (mounted) setState(() => _torchOn = !_torchOn);
                  },
                  icon: Icon(
                    _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    color: _torchOn ? const Color(0xFFFBBF24) : Colors.white70,
                  ),
                ),
                IconButton(
                  tooltip: 'Switch Camera',
                  onPressed: () => _controller.switchCamera(),
                  icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white70),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),

          // Live Camera Preview
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                      errorBuilder: (context, error, child) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.videocam_off_rounded, color: Color(0xFFEF4444), size: 44),
                                const SizedBox(height: 12),
                                Text(
                                  'Camera unavailable (${error.errorCode.name})',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Grant camera permission or enter the barcode manually.',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    // Scanning reticle overlay
                    Center(
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF38BDF8), width: 2.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
