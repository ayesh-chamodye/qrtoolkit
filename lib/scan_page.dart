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
    controller?.dispose();
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
        title: Row(
          children: [
            Icon(_getIconForType(result.type), color: _getColorForType(result.type)),
            const SizedBox(width: 10),
            Text(_getTitleForType(result.type)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Scanned Content:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SelectableText(result.rawValue),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _performAction(result),
            child: Text(_getActionLabel(result.type)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _handled = false;
              });
              controller?.resumeCamera();
            },
            child: const Text('Scan Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to Home
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(QrType type) {
    switch (type) {
      case QrType.url: return Icons.language;
      case QrType.phone: return Icons.phone;
      case QrType.email: return Icons.email;
      case QrType.sms: return Icons.sms;
      case QrType.wifi: return Icons.wifi;
      case QrType.location: return Icons.location_on;
      default: return Icons.text_fields;
    }
  }

  Color _getColorForType(QrType type) {
    switch (type) {
      case QrType.url: return Colors.blue;
      case QrType.phone: return Colors.green;
      case QrType.email: return Colors.red;
      case QrType.sms: return Colors.orange;
      case QrType.wifi: return Colors.purple;
      case QrType.location: return Colors.teal;
      default: return Colors.grey;
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
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () async {
              await controller?.toggleFlash();
              final flashState = await controller?.getFlashStatus();
              setState(() {
                _isFlashOn = flashState ?? false;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () async {
              await controller?.flipCamera();
            },
          ),
        ],
      ),
      body: QRView(
        key: qrKey,
        onQRViewCreated: _onQRViewCreated,
        overlay: QrScannerOverlayShape(
          borderColor: Theme.of(context).primaryColor,
          borderRadius: 12,
          borderLength: 30,
          borderWidth: 8,
          cutOutSize: 250,
        ),
      ),
    );
  }
}
