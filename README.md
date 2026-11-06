# Spendo (Sanad)

Offline-first personal finance, vehicle logbook, and work accounting application built with Flutter, SQLite, and Firebase Realtime Database. Fully optimized for cross-platform data parity between iOS and Android.

---

## Overview

Spendo is designed for real-world daily financial tracking with zero latency and complete offline autonomy. All financial transactions, workplace shifts, debt ledgers, and vehicle maintenance entries are persisted locally in SQLite and synchronized bidirectionally across user devices whenever internet connectivity is available.

---

## Key Features

- **Bidirectional Cloud Sync**: Instant, non-blocking synchronization between Android and iOS devices using Firebase Realtime Database with conflict-free additive merging.
- **Apple Pay & Wallet Integration**: Automated transaction ingestion via iOS Shortcuts and custom deep links (`spendo://pay?amount=...&merchant=...`) or cloud webhook.
- **Invoice & Receipt OCR**: On-device text recognition (Vision framework on iOS, Google ML Kit on Android) for automatic total amount and merchant extraction.
- **Work & Salary Ledger**: Daily shift logs, hourly/daily wage calculations, overtime tracking, advances, and employer settlements.
- **Debt & Credit Tracking**: Clear separation between receivables and payables with contact-level transaction history.
- **Vehicle Maintenance & Fuel Tracker**: Odometer logging, fuel efficiency calculation (km/L and cost per km), test and insurance expiry alerts.
- **Biometric Security & Privacy**: Local biometric authentication (Face ID / Fingerprint) and secure credential isolation.

---

## Technical Architecture

```
lib/
├── core/
│   ├── database/          # SQLite database schema, migrations, and CRUD helpers
│   ├── network/           # HTTP clients and network listeners
│   ├── services/          # Firebase Realtime Database sync and auth linking
│   ├── theme/             # Design system, typography, and color tokens
│   └── utils/             # Formatters, date utilities, and validation
├── features/
│   ├── auth/              # Authentication and account linking screens
│   ├── home/              # Summary dashboard, timeline, and daily expense actions
│   ├── invoice/           # Invoice OCR, fiscal receipt processing, and camera capture
│   ├── people/            # Debtors, creditors, and contact management
│   ├── settings/          # Data export/import, sync preferences, and security settings
│   ├── vehicle/           # Vehicle odometer, fuel logs, and document trackers
│   └── work/              # Workplaces, shift entries, wage calculations, and reports
└── main.dart              # Application bootstrap and global lifecycle handlers
```

---

## Getting Started

### Prerequisites

- Flutter SDK (3.24+ recommended)
- Dart SDK (3.5+ recommended)
- Android Studio / Android SDK (API 34+)
- Xcode 15+ (for iOS builds)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yasenlafe972-tech/spendo-release.git
   cd spendo-release
   ```

2. Fetch project dependencies:
   ```bash
   flutter pub get
   ```

3. Run static analysis:
   ```bash
   flutter analyze
   ```

4. Build Debug APK (Android):
   ```bash
   flutter build apk --debug
   ```

5. Build Release APK (Android):
   ```bash
   flutter build apk --release
   ```

6. Build Unsigned iOS Archive (iOS):
   ```bash
   flutter build ios --release --no-codesign
   ```

---

## Continuous Integration & Releases

Automated builds are orchestrated via GitHub Actions:
- On every push to the `main` branch, `.github/workflows/build_ios_unsigned.yml` compiles the latest codebase on a macOS runner, packages the unsigned iOS payload (`Spendo.ipa`), and publishes a new release tag under GitHub Releases.

---

## License

Proprietary application. All rights reserved.
