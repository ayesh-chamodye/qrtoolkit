import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'features/scanner/qr_parser.dart';
import 'features/scanner/scan_result.dart';
import 'models/scan_item.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _handled = false;
  bool _isFlashOn = false;

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    }
    controller?.resumeCamera();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      final code = scanData.code;
      if (_handled || code == null || code.isEmpty) return;

      _handled = true;
      controller.pauseCamera();

      // Save scan to Hive history
      _saveScan(code);

      // Parse result
      final result = QrParser.parse(code);

      // Show result dialog
      _showResultDialog(result);
    });
  }

  void _saveScan(String content) {
    final box = Hive.box<ScanItem>('history');
    final newItem = ScanItem(
      content: content,
      dateTime: DateTime.now(),
      type: 'scan',
    );
    box.add(newItem);
  }

  void _showResultDialog(ScanResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getColorForType(result.type).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIconForType(result.type),
                color: _getColorForType(result.type),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _getTitleForType(result.type),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scanned Content:',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: SelectableText(
                result.rawValue,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => _performAction(result),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(_getActionLabel(result.type)),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _handled = false;
              });
              controller?.resumeCamera();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.2)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Scan Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to Home
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade400,
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(QrType type) {
    switch (type) {
      case QrType.url: return Icons.language_rounded;
      case QrType.phone: return Icons.phone_rounded;
      case QrType.email: return Icons.email_rounded;
      case QrType.sms: return Icons.sms_rounded;
      case QrType.wifi: return Icons.wifi_rounded;
      case QrType.location: return Icons.location_on_rounded;
      default: return Icons.text_fields_rounded;
    }
  }

  Color _getColorForType(QrType type) {
    switch (type) {
      case QrType.url: return const Color(0xFF3B82F6);
      case QrType.phone: return const Color(0xFF10B981);
      case QrType.email: return const Color(0xFFEF4444);
      case QrType.sms: return const Color(0xFFF59E0B);
      case QrType.wifi: return const Color(0xFF8B5CF6);
      case QrType.location: return const Color(0xFF06B6D4);
      default: return const Color(0xFF6366F1);
    }
  }

  String _getTitleForType(QrType type) {
    switch (type) {
      case QrType.url: return 'Website';
      case QrType.phone: return 'Phone Number';
      case QrType.email: return 'Email';
      case QrType.sms: return 'SMS';
      case QrType.wifi: return 'Wi-Fi';
      case QrType.location: return 'Location';
      default: return 'Text';
    }
  }

  String _getActionLabel(QrType type) {
    switch (type) {
      case QrType.url: return 'Open Website';
      case QrType.phone: return 'Call';
      case QrType.email: return 'Send Email';
      case QrType.sms: return 'Send SMS';
      case QrType.wifi: return 'Connect';
      case QrType.location: return 'Open Maps';
      default: return 'Copy';
    }
  }

  Future<void> _performAction(ScanResult result) async {
    final uri = Uri.parse(result.rawValue);
    if (result.type == QrType.text) {
      await Clipboard.setData(ClipboardData(text: result.rawValue));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied to clipboard')),
        );
      }
    } else {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not perform action')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded),
            onPressed: () async {
              await controller?.toggleFlash();
              final flashState = await controller?.getFlashStatus();
              setState(() {
                _isFlashOn = flashState ?? false;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_rounded),
            onPressed: () async {
              await controller?.flipCamera();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: const Color(0xFF6366F1),
              borderRadius: 16,
              borderLength: 35,
              borderWidth: 8,
              cutOutSize: 260,
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.center_focus_weak_rounded, color: Color(0xFF818CF8), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Align QR code within frame',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
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
