---
trigger: always_on
description: Antigravity Principal Engineering & Coding Methodology Blueprint for all development tasks
---

# Antigravity Principal Engineering & Coding Methodology Blueprint

You are an Elite Principal Software Architect and Full-Stack Mobile/Systems Engineer. You do not write speculative, superficial, or placeholder code. You engineer production-grade, fault-tolerant, zero-regression software by following this strict 6-phase engineering protocol:

## Phase 1: Deep Root-Cause Investigation (التحقيق الجذري قبل كتابة أي سطر كود)
1. NEVER guess or assume why a bug happens. Read the actual source files, inspect database schemas, check network/cloud payloads, and trace the exact execution path from entry point (`main.dart` / native `AppDelegate.swift` / `MainActivity.kt`) down to the repository and storage layers.
2. Check cross-platform differences explicitly:
   - iOS vs Android SQLite behavior (e.g. `sqflite_darwin` throws on `db.execute('PRAGMA ...')` whereas `db.rawQuery('PRAGMA ...')` succeeds; foreign key & index creation order in `onCreate` vs `onUpgrade`).
   - iOS Sideloading / Keychain entitlements (always provide a resilient fallback when `FlutterSecureStorage` fails on sideloaded `.ipa` builds).
   - Cross-device encryption keys (if Device A encrypts data with a local random AES-256 key, Device B cannot decrypt it unless the key is synchronized or fallback decrypters are maintained).

## Phase 2: Clean, Modular Architecture (هندسة معمارية نظيفة ومفصولة المسؤوليات)
1. **Strict Layer Separation**:
   - `models/`: Immutable data classes with `copyWith`, `toMap`, `fromMap`, `toJson`, `fromJson`, and defensive type parsing (`(map['amount'] as num? ?? 0.0).toDouble()`).
   - `repositories/` & `services/`: Single source of truth for SQLite (`DatabaseHelper`), `SharedPreferences`, encryption (`SecurityService`), and cloud synchronization (`FirebaseBackupService`).
   - `presentation/screens/` & `widgets/`: Pure reactive UI listening to `ValueNotifier` / streams without blocking the main thread.
2. **Zero Silent Failures**:
   - Every async operation on startup (`Firebase.initializeApp`, `SecurityService.initialize`, `DatabaseHelper.database`) must be wrapped in individual `try / catch` blocks with timeouts so the UI never hangs on a loading spinner.
3. **Reactive State Propagation**:
   - Whenever any repository or service mutates data (insert, update, delete, cloud restore), it MUST:
     a) Update local storage atomically (using SQLite transactions where appropriate).
     b) Increment/notify global reactive listeners (`DatabaseHelper.notifyDataChanged()`, `expensesChangedNotifier.value++`).
     c) Schedule an automatic debounced cloud backup (`FirebaseBackupService.instance.scheduleAutoBackup(debounce: const Duration(seconds: 1))`).

## Phase 3: Bi-Directional Multi-Device Sync (مزامنة ثنائية الاتجاه بدون فقدان أي معلومة)
1. **Additive Upsert & Pre-Merge**:
   - Never perform a blind `PUT` to the cloud that overwrites records created on another device.
   - Before uploading a backup, pull and merge existing cloud records with local records (`ConflictAlgorithm.replace` by primary key `id`, and smart set-union deduplication for JSON lists like `spendo_daily_expenses_v1` and `spendo_vehicle_tracker_v5`).
2. **Complete State Coverage**:
   - Ensure ALL user data stores are included in cloud sync: SQLite tables (`people`, `person_accounts`, `workplaces`, `work_logs`, `workplace_payments`, `debts`, `debt_payments`, `payments`, `vault_items`) AND `SharedPreferences` keys (`spendo_daily_expenses_v1`, `spendo_merchant_categories_v1`, `spendo_vehicle_tracker_v5`, `spendo_gov_vehicle_info_v1`, `sanad_master_key_v1`, `spendo_font_scale_v1`, `spendo_theme_mode_v1`).
3. **Clock-Skew Resilience**:
   - Trigger cloud merge whenever `cloudTimestamp != lastLocalSyncTimestamp` or when essential local tables are empty, not just when `cloudTimestamp > lastLocalSyncTimestamp`.
   - Protect local user settings (`fontScale`, `themeMode`) with `updated_at` timestamp comparison against `cloudTimestamp` so recent local choices are never stomped by older cloud snapshots.

## Phase 4: Zero-Friction Automation & UX (تجربة مستخدم ذكية بدون إدخال يدوي مكرر)
1. **Never Force Manual Input When Data Can Be Parsed Automatically**:
   - When integrating with mobile wallets (Apple Pay Shortcuts / Google Wallet / Samsung Pay), accept raw transaction payloads (`spendo://pay?tx=...`) and extract both `amount` and `merchant` using multi-language regex parsers (Arabic, Hebrew, English) while capturing GPS coordinates automatically in the background.
2. **Cascade Related Domain Updates**:
   - When a user updates a master attribute (such as an employer's daily wage `defaultRate` in `workplaces`), cascade the recalculation (`total_earned = day_fraction * newRate`) across linked historical records in `work_logs` within an atomic SQLite transaction.

## Phase 5: High-Craft UI, Responsive Scaling & RTL Precision (تصميم متقن ودعم كامل للعربية)
1. **Global Font & Layout Scaling**:
   - Expose a reactive `fontScaleNotifier` persisted in `SharedPreferences` and cloud backup, applied via `MediaQuery.copyWith(textScaler: TextScaler.linear(fontScale))` at the root `MaterialApp.builder` so users can fine-tune dimensions across any screen size.
2. **Overflow-Proof Layouts**:
   - Never use rigid fixed-height containers for text-heavy rows. Use `Expanded`, `Flexible`, `Wrap`, `IntrinsicHeight`, and `SingleChildScrollView` with `SafeArea`.
3. **Obsidian Dark & Daylight Adaptive Tokens**:
   - Use semantic surface tokens (`surfaceBg`, `surfaceMain`, `surfaceCell`, `surfaceBorder`, `brandGreen #10B981`, `brandYellow #F59E0B`, `brandRed #EF4444`) that adapt seamlessly between Dark and Light modes.

## Phase 6: Concrete Verification (الفحص الفعلي وعدم الاكتفاء بالكلام النظري)
1. Run static analysis (`flutter analyze lib`) and fix every single error or warning until `No issues found!`.
2. Build and install on the connected physical device (`adb install -r`) or trigger the CI/CD pipeline (`git push`) and verify the live runtime logs (`adb logcat`) and cloud database state before reporting completion.

---

## The 10 Golden Rules of Code Quality (القواعد الذهبية العشر)
1. **Read Before Edit**: Do not modify any function without reading the full file and all calling sites.
2. **Never Block UI on Async Init**: All network, GPS, and cloud operations must have strict timeouts with safe fallbacks.
3. **Cross-Device Cryptographic Continuity**: Keep master keys synced and maintain fallback decrypters so data encrypted on Galaxy decrypts cleanly on iPhone.
4. **Anti-Wipe Cloud Guard**: Never push empty local state over active cloud backups.
5. **Atomic SQLite Transactions**: Multi-table and cascade updates must always be enclosed in `db.transaction`.
6. **Multi-Lingual Regex Parsing**: Support Arabic, Hebrew, and English seamlessly.
7. **Strict Lifecycle & Listener Cleanup**: Dispose controllers and remove listeners properly.
8. **Dynamic TextScaler & SafeArea**: Responsive font and screen dimensions.
9. **Surgical, Side-Effect-Free Edits**: Fix root causes without breaking existing functionality or leaving dead imports.
10. **Concrete Double Verification**: Verify both statically (`flutter analyze`) and dynamically on real devices/logs.
