import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:hive/hive.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import 'models/scan_item.dart';

class CreatePage extends StatefulWidget {
  const CreatePage({super.key});

  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  String? _selectedType;

  final TextEditingController _c1 = TextEditingController();
  final TextEditingController _c2 = TextEditingController();
  final TextEditingController _c3 = TextEditingController();
  final TextEditingController _c4 = TextEditingController();
  final TextEditingController _c5 = TextEditingController();
  final TextEditingController _c6 = TextEditingController();
  final TextEditingController _c7 = TextEditingController();

  final GlobalKey _qrKey = GlobalKey();

  String _qrData = '';
  bool _busy = false;

  final List<Map<String, dynamic>> _qrTypes = [
    {'name': 'Text', 'icon': Icons.text_fields_rounded, 'cat': '📝 Basic', 'color': Color(0xFF6366F1)},
    {'name': 'URL', 'icon': Icons.language_rounded, 'cat': '🌐 Web', 'color': Color(0xFF3B82F6)},
    {'name': 'Phone', 'icon': Icons.phone_rounded, 'cat': '📱 Contact', 'color': Color(0xFF10B981)},
    {'name': 'vCard', 'icon': Icons.contact_page_rounded, 'cat': '👤 Contact', 'color': Color(0xFF14B8A6)},
    {'name': 'Email', 'icon': Icons.email_rounded, 'cat': '✉️ Comm', 'color': Color(0xFFEF4444)},
    {'name': 'SMS', 'icon': Icons.sms_rounded, 'cat': '💬 Comm', 'color': Color(0xFFF59E0B)},
    {'name': 'Wi-Fi', 'icon': Icons.wifi_rounded, 'cat': '📶 Network', 'color': Color(0xFF8B5CF6)},
    {'name': 'Location', 'icon': Icons.location_on_rounded, 'cat': '📍 Map', 'color': Color(0xFF06B6D4)},
    {'name': 'Event', 'icon': Icons.event_rounded, 'cat': '📅 Calendar', 'color': Color(0xFFEC4899)},
    {'name': 'UPI', 'icon': Icons.account_balance_wallet_rounded, 'cat': '💳 Pay', 'color': Color(0xFF10B981)},
    {'name': 'Crypto', 'icon': Icons.currency_bitcoin_rounded, 'cat': '💰 Pay', 'color': Color(0xFFF59E0B)},
    {'name': 'WhatsApp', 'icon': Icons.chat_rounded, 'cat': '💬 Social', 'color': Color(0xFF22C55E)},
    {'name': 'Telegram', 'icon': Icons.telegram_rounded, 'cat': '💬 Social', 'color': Color(0xFF0EA5E9)},
    {'name': 'Instagram', 'icon': Icons.camera_alt_rounded, 'cat': '📸 Social', 'color': Color(0xFFE1306C)},
    {'name': 'Facebook', 'icon': Icons.facebook_rounded, 'cat': '👤 Social', 'color': Color(0xFF1877F2)},
    {'name': 'LinkedIn', 'icon': Icons.work_rounded, 'cat': '💼 Social', 'color': Color(0xFF0A66C2)},
    {'name': 'Twitter/X', 'icon': Icons.close_rounded, 'cat': '🐦 Social', 'color': Color(0xFF64748B)},
    {'name': 'Spotify', 'icon': Icons.music_note_rounded, 'cat': '🎵 Media', 'color': Color(0xFF1DB954)},
    {'name': 'YouTube', 'icon': Icons.play_circle_rounded, 'cat': '▶️ Media', 'color': Color(0xFFFF0000)},
    {'name': 'GitHub', 'icon': Icons.code_rounded, 'cat': '💻 Dev', 'color': Color(0xFF94A3B8)},
    {'name': 'Maps', 'icon': Icons.map_rounded, 'cat': '🗺️ Navigation', 'color': Color(0xFF06B6D4)},
  ];

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    _c4.dispose();
    _c5.dispose();
    _c6.dispose();
    _c7.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // QR capture / export
  // ---------------------------------------------------------------------------

  Future<Uint8List?> _captureQrImage({int retries = 3}) async {
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      if (boundary.debugNeedsPaint && retries > 0) {
        await Future.delayed(const Duration(milliseconds: 30));
        return await _captureQrImage(retries: retries - 1);
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

  Future<String?> _saveQrToTempFile() async {
    final bytes = await _captureQrImage();
    if (bytes == null) return null;

    final directory = await getTemporaryDirectory();
    await _cleanOldQrFiles(directory);

    final path =
        '${directory.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return path;
  }

  Future<void> _cleanOldQrFiles(Directory directory) async {
    try {
      for (final entity in directory.listSync()) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (entity is File && name.startsWith('qr_') && name.endsWith('.png')) {
          await entity.delete();
        }
      }
    } catch (_) {}
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _shareQr() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final path = await _saveQrToTempFile();
      if (path == null) {
        _showSnack('Could not generate the image. Try again.');
        return;
      }
      await Share.shareXFiles([XFile(path)], text: 'Check out my QR code!');
    } catch (e) {
      _showSnack('Share failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveQrToGallery() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final path = await _saveQrToTempFile();
      if (path == null) {
        _showSnack('Could not generate the image. Try again.');
        return;
      }

      if (!await Gal.hasAccess()) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          _showSnack('Gallery permission denied.');
          return;
        }
      }

      await Gal.putImage(path, album: 'QR Codes');
      _showSnack('Saved to Gallery!');
    } on GalException catch (e) {
      _showSnack('Save failed: ${e.type.message}');
    } catch (e) {
      _showSnack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Input helpers
  // ---------------------------------------------------------------------------

  Future<void> _pickDateTime(TextEditingController controller) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (pickedDate == null || !mounted) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime == null) return;

    final DateTime fullDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() {
      controller.text = DateFormat('yyyy-MM-dd HH:mm').format(fullDateTime);
    });
  }

  String _convertToICalFormat(String displayDate) {
    try {
      final DateTime dt = DateFormat('yyyy-MM-dd HH:mm').parse(displayDate);
      return DateFormat("yyyyMMdd'T'HHmmss'Z'").format(dt.toUtc());
    } catch (e) {
      return '';
    }
  }

  Future<void> _getCurrentLocation(
    TextEditingController latController,
    TextEditingController longController,
  ) async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnack('Location services are disabled.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnack('Location permissions are denied.');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showSnack('Location permissions are permanently denied.');
      return;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        latController.text = position.latitude.toString();
        longController.text = position.longitude.toString();
      });
    } catch (e) {
      _showSnack('Could not get location: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // QR data building
  // ---------------------------------------------------------------------------

  void _generateQR() {
    final String v1 = _c1.text.trim();
    final String v2 = _c2.text.trim();
    final String v3 = _c3.text.trim();
    final String v4 = _c4.text.trim();
    final String v5 = _c5.text.trim();
    final String v6 = _c6.text.trim();
    final String v7 = _c7.text.trim();

    if (v1.isEmpty && _selectedType != 'Location') {
      _showSnack('Please fill in the required field.');
      return;
    }

    String data;
    switch (_selectedType) {
      case 'URL':
        data = v1.startsWith('http') ? v1 : 'https://$v1';
        break;
      case 'Phone':
        data = 'tel:$v1';
        break;
      case 'Email':
        data =
            'mailto:$v1?subject=${Uri.encodeComponent(v2)}&body=${Uri.encodeComponent(v3)}';
        break;
      case 'SMS':
        data =
            'sms:$v1${v2.isNotEmpty ? "?body=${Uri.encodeComponent(v2)}" : ""}';
        break;
      case 'WhatsApp':
        data = 'https://wa.me/$v1';
        break;
      case 'Telegram':
        data = 'https://t.me/$v1';
        break;
      case 'Wi-Fi':
        data = 'WIFI:S:$v1;T:WPA;P:$v2;;';
        break;
      case 'Maps':
        data =
            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(v1)}';
        break;
      case 'Location':
        data = 'geo:$v1,$v2';
        break;
      case 'UPI':
        data =
            'upi://pay?pa=$v1&pn=${Uri.encodeComponent(v2)}&am=$v3&tn=${Uri.encodeComponent(v4)}';
        break;
      case 'vCard':
        data = 'BEGIN:VCARD\nVERSION:3.0\nFN:$v1\nTEL:$v2\nEMAIL:$v3\n'
            'ADR:$v4\nORG:$v5\nEND:VCARD';
        break;
      case 'Event':
        final start = _convertToICalFormat(v6);
        final end = _convertToICalFormat(v7);
        data = 'BEGIN:VEVENT\nSUMMARY:$v1\nDESCRIPTION:$v2\nLOCATION:$v3\n'
            'GEO:$v4;$v5\nDTSTART:$start\nDTEND:$end\nEND:VEVENT';
        break;
      case 'Instagram':
        data = 'https://instagram.com/$v1';
        break;
      case 'YouTube':
        data = 'https://youtube.com/$v1';
        break;
      case 'GitHub':
        data = 'https://github.com/$v1';
        break;
      default:
        data = v1;
    }

    setState(() => _qrData = data);

    if (data.isNotEmpty) {
      final box = Hive.box<ScanItem>('history');
      box.add(
        ScanItem(content: data, dateTime: DateTime.now(), type: 'create'),
      );
    }
  }

  void _resetSelection() {
    setState(() {
      _selectedType = null;
      _qrData = '';
      for (final c in [_c1, _c2, _c3, _c4, _c5, _c6, _c7]) {
        c.clear();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedType == null ? 'Create QR Code' : 'Create $_selectedType',
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_selectedType != null) {
              _resetSelection();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _selectedType == null ? _buildGrid() : _buildForm(),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: _qrTypes.length,
      itemBuilder: (context, i) {
        final t = _qrTypes[i];
        final Color itemColor = t['color'] as Color? ?? Colors.indigo;

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
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _selectedType = t['name'] as String),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: itemColor.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        t['icon'] as IconData,
                        color: itemColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t['name'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t['cat'] as String,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          ..._buildFields(),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _generateQR,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Generate & Save to History',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          if (_qrData.isNotEmpty) ...[
            const SizedBox(height: 35),
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.25),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _qrData,
                  version: QrVersions.auto,
                  size: 210.0,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildActionButton(
                    icon: Icons.share_rounded,
                    label: 'Share',
                    onPressed: _shareQr,
                  ),
                  const SizedBox(width: 16),
                  _buildActionButton(
                    icon: Icons.save_alt_rounded,
                    label: 'Save Gallery',
                    onPressed: _saveQrToGallery,
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: const Color(0xFF818CF8)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFields() {
    final List<Widget> fields = [];

    void addField(
      TextEditingController controller,
      String label, {
      IconData? icon,
      String? hint,
      bool readOnly = false,
      VoidCallback? onTap,
      bool isDateTime = false,
    }) {
      fields.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            onTap: onTap,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              prefixIcon: icon != null
                  ? Icon(icon, color: const Color(0xFF818CF8))
                  : null,
              suffixIcon: isDateTime
                  ? const Icon(Icons.calendar_today, color: Color(0xFF818CF8))
                  : null,
            ),
          ),
        ),
      );
    }

    void addLocationButton(
      TextEditingController lat,
      TextEditingController lng,
    ) {
      fields.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: OutlinedButton.icon(
            onPressed: () => _getCurrentLocation(lat, lng),
            icon: const Icon(Icons.my_location, color: Color(0xFF818CF8)),
            label: const Text('Get Current Location'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: Color(0xFF6366F1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      );
    }

    switch (_selectedType) {
      case 'Location':
        addField(_c1, 'Latitude', icon: Icons.map_rounded, hint: 'e.g. 6.9271');
        addField(_c2, 'Longitude', icon: Icons.map_rounded, hint: 'e.g. 79.8612');
        addLocationButton(_c1, _c2);
        break;
      case 'Event':
        addField(_c1, 'Event Title', icon: Icons.title_rounded);
        addField(_c2, 'Description', icon: Icons.description_rounded);
        addField(_c3, 'Location Name', icon: Icons.location_on_rounded);
        addField(_c4, 'Latitude', icon: Icons.map_rounded, hint: 'Optional');
        addField(_c5, 'Longitude', icon: Icons.map_rounded, hint: 'Optional');
        addLocationButton(_c4, _c5);
        addField(
          _c6,
          'Start Date/Time',
          icon: Icons.calendar_today_rounded,
          readOnly: true,
          isDateTime: true,
          onTap: () => _pickDateTime(_c6),
        );
        addField(
          _c7,
          'End Date/Time',
          icon: Icons.calendar_today_rounded,
          readOnly: true,
          isDateTime: true,
          onTap: () => _pickDateTime(_c7),
        );
        break;
      case 'Email':
        addField(_c1, 'Email Address', icon: Icons.email_rounded);
        addField(_c2, 'Subject', icon: Icons.subject_rounded);
        addField(_c3, 'Body', icon: Icons.message_rounded);
        break;
      case 'vCard':
        addField(_c1, 'Full Name', icon: Icons.person_rounded);
        addField(_c2, 'Phone Number', icon: Icons.phone_rounded);
        addField(_c3, 'Email', icon: Icons.email_rounded);
        addField(_c4, 'Address', icon: Icons.home_rounded);
        addField(_c5, 'Company', icon: Icons.business_rounded);
        break;
      case 'Wi-Fi':
        addField(_c1, 'Network Name (SSID)', icon: Icons.wifi_rounded);
        addField(_c2, 'Password', icon: Icons.lock_rounded);
        break;
      case 'SMS':
        addField(_c1, 'Phone Number', icon: Icons.phone_rounded);
        addField(_c2, 'Message', icon: Icons.message_rounded);
        break;
      case 'UPI':
        addField(_c1, 'Payee UPI ID', icon: Icons.payment_rounded);
        addField(_c2, 'Payee Name', icon: Icons.person_rounded);
        addField(_c3, 'Amount', icon: Icons.money_rounded);
        addField(_c4, 'Note', icon: Icons.note_rounded);
        break;
      default:
        addField(
          _c1,
          _getLabel1(),
          icon: _qrTypes.firstWhere(
            (e) => e['name'] == _selectedType,
            orElse: () => {'icon': Icons.text_fields_rounded},
          )['icon'] as IconData,
        );
    }
    return fields;
  }

  String _getLabel1() {
    switch (_selectedType) {
      case 'WhatsApp':
      case 'Phone':
      case 'Telegram':
        return 'Phone Number';
      case 'Instagram':
      case 'Twitter/X':
      case 'GitHub':
      case 'YouTube':
      case 'Spotify':
        return 'Username / URL';
      case 'URL':
        return 'Website URL';
      default:
        return 'Content / Value';
    }
  }
}
