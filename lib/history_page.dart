import 'dart:io';
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
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear history',
            onPressed: () => _confirmClear(context),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<ScanItem>('history').listenable(),
        builder: (context, Box<ScanItem> box, _) {
          if (box.values.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Icon(
                      Icons.history_rounded,
                      size: 56,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No History Yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Scanned and generated QR codes will appear here',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            );
          }

          final historyList = box.values.toList().reversed.toList();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            itemCount: historyList.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = historyList[index];
              final result = QrParser.parse(item.content);
              final Color typeColor = _getColorForType(result.type);

              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getIconForType(result.type),
                        color: typeColor,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      item.content,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${_getTitleForType(result.type)} • '
                        '${DateFormat('MMM dd, yyyy HH:mm').format(item.dateTime)}',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                      onPressed: () => item.delete(),
                    ),
                    onTap: () => _showDetails(context, item, result),
                  ),
                ),
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
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        title: const Text('Clear history?', style: TextStyle(color: Colors.white)),
        content: Text(
          'This will permanently remove every saved item.',
          style: TextStyle(color: Colors.grey.shade300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
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
        return Icons.language_rounded;
      case QrType.phone:
        return Icons.phone_rounded;
      case QrType.email:
        return Icons.email_rounded;
      case QrType.sms:
        return Icons.sms_rounded;
      case QrType.wifi:
        return Icons.wifi_rounded;
      case QrType.location:
        return Icons.location_on_rounded;
      default:
        return Icons.text_fields_rounded;
    }
  }

  Color _getColorForType(QrType type) {
    switch (type) {
      case QrType.url:
        return const Color(0xFF3B82F6);
      case QrType.phone:
        return const Color(0xFF10B981);
      case QrType.email:
        return const Color(0xFFEF4444);
      case QrType.sms:
        return const Color(0xFFF59E0B);
      case QrType.wifi:
        return const Color(0xFF8B5CF6);
      case QrType.location:
        return const Color(0xFF06B6D4);
      default:
        return const Color(0xFF6366F1);
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
        return await _captureQrImage(key, retries: retries - 1);
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
    } catch (_) {}
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
            backgroundColor: const Color(0xFF1E293B),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            title: Text(
              _getTitleForType(result.type),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
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
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: QrImageView(
                        data: item.content,
                        version: QrVersions.auto,
                        size: 190.0,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: SelectableText(
                      item.content,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: CircularProgressIndicator(),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, color: Color(0xFF818CF8)),
                          tooltip: 'Copy',
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: item.content),
                            );
                            _snack(dialogContext, 'Copied to clipboard');
                          },
                        ),
                        IconButton(
                          icon: Icon(_getActionIcon(result.type), color: const Color(0xFF818CF8)),
                          tooltip: 'Open',
                          onPressed: () => _performAction(dialogContext, result),
                        ),
                        IconButton(
                          icon: const Icon(Icons.share_rounded, color: Color(0xFF818CF8)),
                          tooltip: 'Share QR',
                          onPressed: () =>
                              run(() => _shareQr(dialogContext, qrKey)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.save_alt_rounded, color: Color(0xFF818CF8)),
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
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade400,
                ),
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
        return Icons.open_in_new_rounded;
      case QrType.phone:
        return Icons.call_rounded;
      case QrType.email:
        return Icons.send_rounded;
      case QrType.sms:
        return Icons.message_rounded;
      case QrType.location:
        return Icons.map_rounded;
      default:
        return Icons.open_in_new_rounded;
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
