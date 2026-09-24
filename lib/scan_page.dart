import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/scan_item.dart';
import 'features/scanner/qr_parser.dart';
import 'features/scanner/scan_result.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
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

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;

      if (value == null || value.isEmpty) continue;

      _handled = true;
      controller.stop();
      
      // Save to history
      _saveScan(value);

      // Parse result
      final result = QrParser.parse(value);
      
      // Show result UI
      _showResultDialog(result);
      break;
    }
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
                controller.start();
              });
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
      // Copy to clipboard
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
          ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, state, child) {
              if (!state.isInitialized || !state.isRunning) {
                return const SizedBox.shrink();
              }
              
              IconData icon;
              Color color;
              
              switch (state.torchState) {
                case TorchState.on:
                  icon = Icons.flash_on;
                  color = Colors.yellow;
                  break;
                case TorchState.auto:
                  icon = Icons.flash_auto;
                  color = Colors.blue;
                  break;
                case TorchState.off:
                case TorchState.unavailable:
                default:
                  icon = Icons.flash_off;
                  color = Colors.grey;
                  break;
              }
              
              if (state.torchState == TorchState.unavailable) {
                return const SizedBox.shrink();
              }
              
              return IconButton(
                icon: Icon(icon, color: color),
                onPressed: () => controller.toggleTorch(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
          ),
          // Scanner Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  // Corner borders or a scanning animation could go here
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
