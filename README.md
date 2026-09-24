# QR ToolKit

QR ToolKit is a Flutter-based mobile app for creating, scanning, and managing QR codes in one place. It includes a scanner for live QR detection, code generation for common formats, local history storage, and export/share actions.

## Features

- Scan QR codes using the device camera
- Detect and classify common QR data types such as URLs, Wi‑Fi, phone numbers, email, SMS, locations, and more
- Generate QR codes for:
  - Text
  - URL
  - Phone
  - Email
  - SMS
  - Wi‑Fi
  - Location
  - vCard
  - Events
  - UPI
  - Social profiles and messaging links
  - Maps and navigation links
- Save generated and scanned entries to local history
- Share QR codes directly
- Save QR images to the gallery
- Dark-themed Material 3 UI

## Screenshots

This project currently contains the app code and UI flow for:

- Home dashboard
- QR scanner screen
- QR generator screen
- History screen
- Splash screen

## Tech Stack

- Flutter
- Dart
- Hive for local persistence
- qr_code_scanner_plus for scanning
- qr_flutter for generating QR images
- geolocator for location access
- share_plus for sharing
- gal for saving to gallery
- url_launcher for deep links

## Project Structure

```text
.
├── android/
├── ios/
├── lib/
│   ├── features/
│   │   └── scanner/
│   ├── models/
│   ├── create_page.dart
│   ├── history_page.dart
│   ├── home_page.dart
│   ├── main.dart
│   ├── scan_page.dart
│   └── splash_page.dart
├── assets/
├── test/
├── .gitignore
├── analysis_options.yaml
├── pubspec.yaml
├── README.md
└── ...
```

## Getting Started

### Prerequisites

- Flutter SDK 3.13.2 or newer
- Android Studio / Xcode depending on target platform
- A physical device or emulator

### Install dependencies

```bash
git clone https://github.com/ayesh-chamodye/qrtoolkit.git
cd qrtoolkit
flutter pub get
```

### Run the app

```bash
flutter run
```

For a specific platform:

```bash
flutter run -d android
flutter run -d ios
```

## Development Notes

The app initializes Hive at startup and stores QR history inside a local `history` box. The scanner parses detected QR payloads into structured result types and presents the appropriate action (open URL, call, send email, copy text, and so on).

## License

This project currently does not include a license file. If you plan to distribute or publish it, consider adding an appropriate open-source license.

## Author

Developed by Ayesh.
