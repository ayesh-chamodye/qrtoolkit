enum QrType {
  url,
  phone,
  email,
  sms,
  wifi,
  contact,
  location,
  text,
}

class ScanResult {
  final QrType type;
  final String rawValue;

  ScanResult({
    required this.type,
    required this.rawValue,
  });
}
