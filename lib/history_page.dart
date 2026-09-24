import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import 'models/scan_item.dart';
import 'features/scanner/qr_parser.dart';
import 'features/scanner/scan_result.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear history',
            onPressed: () => _confirmClear(context),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<ScanItem>('history').listenable(),
        builder: (context, Box<ScanItem> box, _) {
          if (box.values.isEmpty) {
            return const Center(child: Text('No history yet'));
          }

          final historyList = box.values.toList().reversed.toList();

          return ListView.builder(
            itemCount: historyList.length,
            itemBuilder: (context, index) {
              final item = historyList[index];
              final result = QrParser.parse(item.content);

              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getColorForType(result.type).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIconForType(result.type),
                    color: _getColorForType(result.type),
                  ),
                ),
                title: Text(
                  item.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${_getTitleForType(result.type)} • '
                  '${DateFormat('yyyy-MM-dd HH:mm').format(item.dateTime)}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => item.delete(),
                ),
                onTap: () => _showDetails(context, item, result),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('This will remove every saved item.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await Hive.box<ScanItem>('history').clear();
    }
  }

  // ---------------------------------------------------------------------------
  // Type helpers
  // ---------------------------------------------------------------------------

  IconData _getIconForType(QrType type) {
    switch (type) {
      case QrType.url:
        return Icons.language;
      case QrType.phone:
        return Icons.phone;
      case QrType.email:
        return Icons.email;
      case QrType.sms:
        return Icons.sms;
      case QrType.wifi:
        return Icons.wifi;
      case QrType.location:
        return Icons.location_on;
      default:
        return Icons.text_fields;
    }
  }

  Color _getColorForType(QrType type) {
    switch (type) {
      case QrType.url:
        return Colors.blue;
      case QrType.phone:
        return Colors.green;
      case QrType.email:
        return Colors.red;
      case QrType.sms:
        return Colors.orange;
      case QrType.wifi:
        return Colors.purple;
      case QrType.location:
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _getTitleForType(QrType type) {
    switch (type) {
      case QrType.url:
        return 'Website';
      case QrType.phone:
        return 'Phone Number';
      case QrType.email:
        return 'Email';
      case QrType.sms:
        return 'SMS';
      case QrType.wifi:
        return 'Wi-Fi';
      case QrType.location:
        return 'Location';
      default:
        return 'Text';
    }
  }

  // ---------------------------------------------------------------------------
  // QR capture / export
  // ---------------------------------------------------------------------------

  /// Captures the already-rendered QR widget behind [key] as PNG bytes.
  static Future<Uint8List?> _captureQrImage(
    GlobalKey key, {
    int retries = 3,
  }) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      if (boundary.debugNeedsPaint && retries > 0) {
        await Future.delayed(const Duration(milliseconds: 30));
        return _captureQrImage(key, retries: retries - 1);
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 4.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('QR capture failed: $e');
      return null;
    }
  }

  /// Captures, cleans up old temp files, writes a fresh PNG, returns its path.
  static Future<String?> _saveQrToTempFile(GlobalKey key) async {
    final bytes = await _captureQrImage(key);
    if (bytes == null) return null;

    final directory = await getTemporaryDirectory();
    await _cleanOldQrFiles(directory);

    final path =
        '${directory.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  static Future<void> _cleanOldQrFiles(Directory directory) async {
    try {
      for (final entity in directory.listSync()) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (entity is File && name.startsWith('qr_') && name.endsWith('.png')) {
          await entity.delete();
        }
      }
    } catch (_) {
      // Best effort cleanup.
    }
  }

  static void _snack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static Future<void> _shareQr(BuildContext context, GlobalKey key) async {
    try {
      final path = await _saveQrToTempFile(key);
      if (path == null) {
        _snack(context, 'Could not generate the image. Try again.');
        return;
      }

      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Check out this QR code!',
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
    } catch (e) {
      _snack(context, 'Share failed: $e');
    }
  }

  static Future<void> _saveQrToGallery(
    BuildContext context,
    GlobalKey key,
  ) async {
    try {
      final path = await _saveQrToTempFile(key);
      if (path == null) {
        _snack(context, 'Could not generate the image. Try again.');
        return;
      }

      if (!await Gal.hasAccess()) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          _snack(context, 'Gallery permission denied.');
          return;
        }
      }

      await Gal.putImage(path, album: 'QR Codes');
      _snack(context, 'Saved to Gallery!');
    } on GalException catch (e) {
      _snack(context, 'Save failed: ${e.type.message}');
    } catch (e) {
      _snack(context, 'Save failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Detail dialog
  // ---------------------------------------------------------------------------

  void _showDetails(BuildContext context, ScanItem item, ScanResult result) {
    final GlobalKey qrKey = GlobalKey();
    bool busy = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> run(Future<void> Function() action) async {
            if (busy) return;
            setDialogState(() => busy = true);
            try {
              await action();
            } finally {
              if (dialogContext.mounted) setDialogState(() => busy = false);
            }
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              _getTitleForType(result.type),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RepaintBoundary(
                    key: qrKey,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: QrImageView(
                        data: item.content,
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SelectableText(
                      item.content,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy),
                          tooltip: 'Copy',
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: item.content),
                            );
                            _snack(dialogContext, 'Copied to clipboard');
                          },
                        ),
                        IconButton(
                          icon: Icon(_getActionIcon(result.type)),
                          tooltip: 'Open',
                          onPressed: () => _performAction(dialogContext, result),
                        ),
                        IconButton(
                          icon: const Icon(Icons.share),
                          tooltip: 'Share QR',
                          onPressed: () =>
                              run(() => _shareQr(dialogContext, qrKey)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.save_alt),
                          tooltip: 'Save to Gallery',
                          onPressed: () =>
                              run(() => _saveQrToGallery(dialogContext, qrKey)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  IconData _getActionIcon(QrType type) {
    switch (type) {
      case QrType.url:
        return Icons.open_in_new;
      case QrType.phone:
        return Icons.call;
      case QrType.email:
        return Icons.send;
      case QrType.sms:
        return Icons.message;
      case QrType.location:
        return Icons.map;
      default:
        return Icons.open_in_new;
    }
  }

  Future<void> _performAction(BuildContext context, ScanResult result) async {
    if (result.type == QrType.text || result.type == QrType.wifi) {
      await Clipboard.setData(ClipboardData(text: result.rawValue));
      _snack(context, 'Copied to clipboard');
      return;
    }

    final uri = Uri.tryParse(result.rawValue);
    if (uri == null) {
      _snack(context, 'Could not perform action');
      return;
    }

    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) _snack(context, 'Could not perform action');
    } catch (e) {
      _snack(context, 'Could not perform action');
    }
  }
}
