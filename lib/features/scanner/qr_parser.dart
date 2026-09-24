import 'scan_result.dart';

class QrParser {
  static ScanResult parse(String value) {
    final lower = value.toLowerCase();

    if (lower.startsWith('http://') ||
        lower.startsWith('https://')) {
      return ScanResult(
        type: QrType.url,
        rawValue: value,
      );
    }

    if (lower.startsWith('tel:')) {
      return ScanResult(
        type: QrType.phone,
        rawValue: value,
      );
    }

    if (lower.startsWith('mailto:')) {
      return ScanResult(
        type: QrType.email,
        rawValue: value,
      );
    }

    if (lower.startsWith('sms:') ||
        lower.startsWith('smsto:')) {
      return ScanResult(
        type: QrType.sms,
        rawValue: value,
      );
    }

    if (lower.startsWith('wifi:')) {
      return ScanResult(
        type: QrType.wifi,
        rawValue: value,
      );
    }

    if (lower.startsWith('geo:')) {
      return ScanResult(
        type: QrType.location,
        rawValue: value,
      );
    }

    return ScanResult(
      type: QrType.text,
      rawValue: value,
    );
  }
}
