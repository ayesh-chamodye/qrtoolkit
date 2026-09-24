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

  /// Key attached to the RepaintBoundary wrapping the on-screen QR code.
  /// Lets us capture exactly what the user sees, with no second render pass.
  final GlobalKey _qrKey = GlobalKey();

  String _qrData = '';
  bool _busy = false;

  final List<Map<String, dynamic>> _qrTypes = [
    {'name': 'Text', 'icon': Icons.text_fields, 'cat': '📝 Basic'},
    {'name': 'URL', 'icon': Icons.language, 'cat': '🌐 Web'},
    {'name': 'Phone', 'icon': Icons.phone, 'cat': '📱 Contact'},
    {'name': 'vCard', 'icon': Icons.contact_page, 'cat': '👤 Contact'},
    {'name': 'Email', 'icon': Icons.email, 'cat': '✉️ Communication'},
    {'name': 'SMS', 'icon': Icons.sms, 'cat': '💬 Communication'},
    {'name': 'Wi-Fi', 'icon': Icons.wifi, 'cat': '📶 Network'},
    {'name': 'Location', 'icon': Icons.location_on, 'cat': '📍 Location'},
    {'name': 'Event', 'icon': Icons.event, 'cat': '📅 Events'},
    {'name': 'UPI', 'icon': Icons.account_balance_wallet, 'cat': '💳 Payment'},
    {'name': 'Crypto', 'icon': Icons.currency_bitcoin, 'cat': '💰 Payment'},
    {'name': 'WhatsApp', 'icon': Icons.chat, 'cat': '💬 Social'},
    {'name': 'Telegram', 'icon': Icons.telegram, 'cat': '💬 Social'},
    {'name': 'Instagram', 'icon': Icons.camera_alt, 'cat': '📸 Social'},
    {'name': 'Facebook', 'icon': Icons.facebook, 'cat': '👤 Social'},
    {'name': 'LinkedIn', 'icon': Icons.work, 'cat': '💼 Social'},
    {'name': 'Twitter/X', 'icon': Icons.close, 'cat': '🐦 Social'},
    {'name': 'Spotify', 'icon': Icons.music_note, 'cat': '🎵 Media'},
    {'name': 'YouTube', 'icon': Icons.play_circle, 'cat': '▶️ Media'},
    {'name': 'GitHub', 'icon': Icons.code, 'cat': '💻 Developer'},
    {'name': 'Maps', 'icon': Icons.map, 'cat': '🗺️ Maps'},
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

  /// Captures the already-rendered QR widget as PNG bytes.
  /// No QrPainter / PictureRecorder second pass needed.
  Future<Uint8List?> _captureQrImage({int retries = 3}) async {
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // If a repaint is still pending, wait a frame and try again.
      if (boundary.debugNeedsPaint && retries > 0) {
        await Future.delayed(const Duration(milliseconds: 30));
        return _captureQrImage(retries: retries - 1);
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 4.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose(); // free native memory
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('QR capture failed: $e');
      return null;
    }
  }

  /// Writes the captured QR to a temp file and returns its path.
  /// Old temp QR files are cleaned up first so they don't pile up.
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
    } catch (_) {
      // Cleanup is best-effort; never block the export on it.
    }
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
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: _qrTypes.length,
      itemBuilder: (context, i) {
        final t = _qrTypes[i];
        return InkWell(
          onTap: () => setState(() => _selectedType = t['name'] as String),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(t['icon'] as IconData, color: Colors.deepPurple, size: 28),
                const SizedBox(height: 6),
                Text(
                  t['name'] as String,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  t['cat'] as String,
                  style: const TextStyle(fontSize: 8, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          ..._buildFields(),
          const SizedBox(height: 25),
          ElevatedButton(
            onPressed: _generateQR,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Generate & Save to History'),
          ),
          if (_qrData.isNotEmpty) ...[
            const SizedBox(height: 30),

            // The RepaintBoundary is what gets captured. Everything inside it
            // (padding + white background) ends up in the exported PNG.
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 10),
                  ],
                ),
                child: QrImageView(
                  data: _qrData,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 20),
            if (_busy)
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
                    icon: const Icon(Icons.share),
                    onPressed: _shareQr,
                    tooltip: 'Share QR',
                  ),
                  IconButton(
                    icon: const Icon(Icons.save_alt),
                    onPressed: _saveQrToGallery,
                    tooltip: 'Save to Gallery',
                  ),
                ],
              ),
          ],
        ],
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
          padding: const EdgeInsets.only(bottom: 15),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            onTap: onTap,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: icon != null ? Icon(icon) : null,
              suffixIcon: isDateTime ? const Icon(Icons.calendar_today) : null,
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
          padding: const EdgeInsets.only(bottom: 15),
          child: ElevatedButton.icon(
            onPressed: () => _getCurrentLocation(lat, lng),
            icon: const Icon(Icons.my_location),
            label: const Text('Get Current Location'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ),
      );
    }

    switch (_selectedType) {
      case 'Location':
        addField(_c1, 'Latitude', icon: Icons.map, hint: 'e.g. 6.9271');
        addField(_c2, 'Longitude', icon: Icons.map, hint: 'e.g. 79.8612');
        addLocationButton(_c1, _c2);
        break;
      case 'Event':
        addField(_c1, 'Event Title', icon: Icons.title);
        addField(_c2, 'Description', icon: Icons.description);
        addField(_c3, 'Location Name', icon: Icons.location_on);
        addField(_c4, 'Latitude', icon: Icons.map, hint: 'Optional');
        addField(_c5, 'Longitude', icon: Icons.map, hint: 'Optional');
        addLocationButton(_c4, _c5);
        addField(
          _c6,
          'Start Date/Time',
          icon: Icons.calendar_today,
          readOnly: true,
          isDateTime: true,
          onTap: () => _pickDateTime(_c6),
        );
        addField(
          _c7,
          'End Date/Time',
          icon: Icons.calendar_today,
          readOnly: true,
          isDateTime: true,
          onTap: () => _pickDateTime(_c7),
        );
        break;
      case 'Email':
        addField(_c1, 'Email Address', icon: Icons.email);
        addField(_c2, 'Subject', icon: Icons.subject);
        addField(_c3, 'Body', icon: Icons.message);
        break;
      case 'vCard':
        addField(_c1, 'Full Name', icon: Icons.person);
        addField(_c2, 'Phone Number', icon: Icons.phone);
        addField(_c3, 'Email', icon: Icons.email);
        addField(_c4, 'Address', icon: Icons.home);
        addField(_c5, 'Company', icon: Icons.business);
        break;
      case 'Wi-Fi':
        addField(_c1, 'Network Name (SSID)', icon: Icons.wifi);
        addField(_c2, 'Password', icon: Icons.lock);
        break;
      case 'SMS':
        addField(_c1, 'Phone Number', icon: Icons.phone);
        addField(_c2, 'Message', icon: Icons.message);
        break;
      case 'UPI':
        addField(_c1, 'Payee UPI ID', icon: Icons.payment);
        addField(_c2, 'Payee Name', icon: Icons.person);
        addField(_c3, 'Amount', icon: Icons.money);
        addField(_c4, 'Note', icon: Icons.note);
        break;
      default:
        addField(
          _c1,
          _getLabel1(),
          icon: _qrTypes.firstWhere(
            (e) => e['name'] == _selectedType,
            orElse: () => {'icon': Icons.text_fields},
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
