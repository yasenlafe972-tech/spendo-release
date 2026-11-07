import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../security/security_service.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();

  /// Global signal to immediately trigger UI screens to reload when restore or import completes
  static final ValueNotifier<int> dataVersionNotifier = ValueNotifier<int>(0);

  static void notifyDataChanged() {
    dataVersionNotifier.value++;
  }

  static Database? _database;
  static const int _databaseVersion = 11;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Ensures all 9 core tables and indices exist safely (self-heals partial DBs on iOS/Android)
  static Future<void> _ensureSchemaIntegrity(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS people (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        is_user INTEGER NOT NULL DEFAULT 0,
        birthdate TEXT,
        email TEXT,
        phone TEXT,
        whatsapp TEXT,
        national_id TEXT,
        bank TEXT,
        account_number TEXT,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        hourly_rate REAL DEFAULT 0.0,
        daily_rate REAL DEFAULT 0.0,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS workplaces (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        city TEXT NOT NULL DEFAULT '',
        person_id TEXT,
        daily_rate REAL NOT NULL DEFAULT 0.0,
        hourly_rate REAL NOT NULL DEFAULT 0.0,
        status TEXT NOT NULL DEFAULT 'active',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS work_logs (
        id TEXT PRIMARY KEY,
        person_id TEXT,
        workplace_id TEXT,
        workplace_name TEXT NOT NULL,
        city TEXT NOT NULL DEFAULT '',
        day_name TEXT NOT NULL DEFAULT '',
        date TEXT NOT NULL,
        rate_type TEXT NOT NULL,
        hours_worked REAL,
        day_fraction REAL DEFAULT 1.0,
        rate_applied REAL NOT NULL,
        total_earned REAL NOT NULL,
        amount_collected REAL NOT NULL DEFAULT 0.0,
        notes TEXT,
        latitude REAL,
        longitude REAL,
        location_address TEXT,
        attachments TEXT DEFAULT '[]',
        created_at TEXT NOT NULL,
        FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE SET NULL,
        FOREIGN KEY (workplace_id) REFERENCES workplaces(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS workplace_payments (
        id TEXT PRIMARY KEY,
        workplace_id TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        payment_method TEXT NOT NULL DEFAULT 'كاش',
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (workplace_id) REFERENCES workplaces(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id TEXT PRIMARY KEY,
        person_id TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        type TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS debts (
        id TEXT PRIMARY KEY,
        person_id TEXT NOT NULL,
        type TEXT NOT NULL,
        original_amount REAL NOT NULL,
        remaining_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        transaction_date TEXT NOT NULL,
        due_date TEXT,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS debt_payments (
        id TEXT PRIMARY KEY,
        debt_id TEXT NOT NULL,
        amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        payment_date TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (debt_id) REFERENCES debts(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS vault_items (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        username TEXT,
        encrypted_password TEXT,
        encrypted_secret_data TEXT,
        url TEXT,
        notes TEXT,
        latitude REAL,
        longitude REAL,
        location_address TEXT,
        attachments TEXT DEFAULT '[]',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS person_accounts (
        id TEXT PRIMARY KEY,
        person_id TEXT NOT NULL,
        service TEXT NOT NULL,
        email TEXT NOT NULL,
        password TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE CASCADE
      )
    ''');

    // Indices created safely AFTER all tables exist
    const indices = [
      'CREATE INDEX IF NOT EXISTS idx_work_logs_workplace_id ON work_logs(workplace_id)',
      'CREATE INDEX IF NOT EXISTS idx_work_logs_date ON work_logs(date)',
      'CREATE INDEX IF NOT EXISTS idx_work_logs_person_id ON work_logs(person_id)',
      'CREATE INDEX IF NOT EXISTS idx_work_logs_wp_date ON work_logs(workplace_id, date DESC)',
      'CREATE INDEX IF NOT EXISTS idx_workplaces_person_id ON workplaces(person_id)',
      'CREATE INDEX IF NOT EXISTS idx_debts_person_id ON debts(person_id)',
      'CREATE INDEX IF NOT EXISTS idx_debts_tx_date ON debts(transaction_date DESC)',
      'CREATE INDEX IF NOT EXISTS idx_debt_payments_debt_id ON debt_payments(debt_id)',
      'CREATE INDEX IF NOT EXISTS idx_payments_person_id ON payments(person_id)',
      'CREATE INDEX IF NOT EXISTS idx_people_is_user ON people(is_user)',
      'CREATE INDEX IF NOT EXISTS idx_workplace_payments_workplace_id ON workplace_payments(workplace_id)',
      'CREATE INDEX IF NOT EXISTS idx_workplace_payments_date ON workplace_payments(date)',
      'CREATE INDEX IF NOT EXISTS idx_person_accounts_person_id ON person_accounts(person_id)',
    ];
    for (final sql in indices) {
      try {
        await db.execute(sql);
      } catch (_) {}
    }

    // Ensure default user profile exists if people table has no user
    try {
      final existingUser = await db.query('people', where: 'is_user = 1', limit: 1);
      if (existingUser.isEmpty) {
        final defaultId = const Uuid().v4();
        final now = DateTime.now().toIso8601String();
        await db.insert('people', {
          'id': defaultId,
          'name': 'لافي',
          'is_user': 1,
          'birthdate': '1998-10-24',
          'email': 'yasenlafe972@gmail.com',
          'phone': '+972500000000',
          'whatsapp': '+972500000000',
          'national_id': '123456789',
          'is_pinned': 1,
          'hourly_rate': 0.0,
          'daily_rate': 0.0,
          'notes': 'الملف الشخصي الأساسي',
          'created_at': now,
          'updated_at': now,
        });
      }
    } catch (_) {}
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sanad_master.db');

    return await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        // Use rawQuery wrapped in try/catch because PRAGMA busy_timeout returns a row on iOS sqflite_darwin
        try {
          await db.rawQuery('PRAGMA foreign_keys = ON;');
        } catch (_) {}
        try {
          await db.rawQuery('PRAGMA busy_timeout = 5000;');
        } catch (_) {}
      },
      onOpen: (db) async {
        // Enable Write-Ahead Logging (WAL) and ensure schema integrity on every open
        try {
          await db.rawQuery('PRAGMA journal_mode = WAL;');
          await db.rawQuery('PRAGMA synchronous = NORMAL;');
        } catch (_) {}
        try {
          await _ensureSchemaIntegrity(db);
        } catch (e) {
          debugPrint('Schema integrity check notice: $e');
        }
      },
      onCreate: (db, version) async {
        await _ensureSchemaIntegrity(db);

        try {
          final existingUser = await db.query('people', where: 'is_user = 1', limit: 1);
          if (existingUser.isNotEmpty) {
            final defaultId = existingUser.first['id'] as String;
            final now = DateTime.now().toIso8601String();
            final sampleAccounts = [
              {'service': 'DaVinci AI', 'email': 'yasenlafe972@gmail.com', 'password': 'DaVinci#9982!'},
              {'service': 'cloud.oracle', 'email': 'yasenlafe972@gmail.com', 'password': 'OracleCloud_2026'},
              {'service': 'Nsave', 'email': 'yasenlafe972@gmail.com', 'password': '9482'},
              {'service': 'mail.ru', 'email': 'yasen98@mail.ru', 'password': 'MailRu_Pass98!'},
              {'service': 'Apple', 'email': 'yasenlafe972@gmail.com', 'password': 'AppleID#1998_Sp'},
              {'service': 'Mapbox', 'email': 'yasenlafe972@gmail.com', 'password': 'Mapbox#DevToken!'},
              {'service': 'Amazon Prime', 'email': 'yasenlafe972@gmail.com', 'password': 'Amazon_Prime26'},
              {'service': 'PayPal', 'email': 'yasenlafe972@gmail.com', 'password': 'PayPalSecure#98'},
            ];
            for (final item in sampleAccounts) {
              final encryptedPass = SecurityService.instance.encrypt(item['password']!);
              await db.insert('person_accounts', {
                'id': const Uuid().v4(),
                'person_id': defaultId,
                'service': item['service'],
                'email': item['email'],
                'password': encryptedPass,
                'created_at': now,
                'updated_at': now,
              });
            }
          }
        } catch (_) {}
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute("ALTER TABLE work_logs ADD COLUMN city TEXT NOT NULL DEFAULT ''");
          } catch (_) {}
          try {
            await db.execute("ALTER TABLE work_logs ADD COLUMN amount_collected REAL NOT NULL DEFAULT 0.0");
          } catch (_) {}

          await db.execute('''
            CREATE TABLE IF NOT EXISTS debts (
              id TEXT PRIMARY KEY,
              person_id TEXT NOT NULL,
              type TEXT NOT NULL,
              original_amount REAL NOT NULL,
              remaining_amount REAL NOT NULL,
              payment_method TEXT NOT NULL,
              transaction_date TEXT NOT NULL,
              due_date TEXT,
              notes TEXT,
              status TEXT NOT NULL DEFAULT 'active',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE CASCADE
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS debt_payments (
              id TEXT PRIMARY KEY,
              debt_id TEXT NOT NULL,
              amount REAL NOT NULL,
              payment_method TEXT NOT NULL,
              payment_date TEXT NOT NULL,
              notes TEXT,
              created_at TEXT NOT NULL,
              FOREIGN KEY (debt_id) REFERENCES debts(id) ON DELETE CASCADE
            )
          ''');
        }

        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS workplaces (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              city TEXT NOT NULL DEFAULT '',
              person_id TEXT,
              daily_rate REAL NOT NULL DEFAULT 0.0,
              hourly_rate REAL NOT NULL DEFAULT 0.0,
              status TEXT NOT NULL DEFAULT 'active',
              notes TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE SET NULL
            )
          ''');

          try {
            await db.execute("ALTER TABLE work_logs ADD COLUMN workplace_id TEXT");
          } catch (_) {}
          try {
            await db.execute("ALTER TABLE work_logs ADD COLUMN day_name TEXT NOT NULL DEFAULT ''");
          } catch (_) {}
        }

        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS work_logs_v4 (
              id TEXT PRIMARY KEY,
              person_id TEXT,
              workplace_id TEXT,
              workplace_name TEXT NOT NULL,
              city TEXT NOT NULL DEFAULT '',
              day_name TEXT NOT NULL DEFAULT '',
              date TEXT NOT NULL,
              rate_type TEXT NOT NULL,
              hours_worked REAL,
              day_fraction REAL DEFAULT 1.0,
              rate_applied REAL NOT NULL,
              total_earned REAL NOT NULL,
              amount_collected REAL NOT NULL DEFAULT 0.0,
              notes TEXT,
              created_at TEXT NOT NULL,
              FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE SET NULL,
              FOREIGN KEY (workplace_id) REFERENCES workplaces(id) ON DELETE SET NULL
            )
          ''');

          try {
            await db.execute('''
              INSERT INTO work_logs_v4 (
                id, person_id, workplace_id, workplace_name, city, day_name, date,
                rate_type, hours_worked, day_fraction, rate_applied, total_earned,
                amount_collected, notes, created_at
              )
              SELECT 
                id, person_id, workplace_id, workplace_name, city, day_name, date,
                rate_type, hours_worked, day_fraction, rate_applied, total_earned,
                amount_collected, notes, created_at
              FROM work_logs
            ''');
          } catch (_) {
            try {
              await db.execute('INSERT INTO work_logs_v4 SELECT * FROM work_logs');
            } catch (_) {}
          }

          await db.execute('DROP TABLE IF EXISTS work_logs');
          await db.execute('ALTER TABLE work_logs_v4 RENAME TO work_logs');
        }

        if (oldVersion < 5) {
          try {
            await db.execute('CREATE INDEX IF NOT EXISTS idx_work_logs_workplace_id ON work_logs(workplace_id)');
          } catch (_) {}
          try {
            await db.execute('CREATE INDEX IF NOT EXISTS idx_work_logs_date ON work_logs(date)');
          } catch (_) {}

          try {
            await _linkOrphanedWorkLogs(db);
          } catch (_) {}
        }

        if (oldVersion < 6) {
          try {
            await db.execute("ALTER TABLE people ADD COLUMN bank TEXT");
          } catch (_) {}
          try {
            await db.execute("ALTER TABLE people ADD COLUMN account_number TEXT");
          } catch (_) {}
        }

        if (oldVersion < 7) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS person_accounts (
              id TEXT PRIMARY KEY,
              person_id TEXT NOT NULL,
              service TEXT NOT NULL,
              email TEXT NOT NULL,
              password TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE CASCADE
            )
          ''');
          try {
            await db.execute('CREATE INDEX IF NOT EXISTS idx_person_accounts_person_id ON person_accounts(person_id)');
          } catch (_) {}

          try {
            final you = await db.query('people', where: 'is_user = 1', limit: 1);
            if (you.isNotEmpty) {
              final youId = you.first['id'] as String;
              final existingAccounts = await db.query('person_accounts', where: 'person_id = ?', whereArgs: [youId]);
              if (existingAccounts.isEmpty) {
                final sampleAccounts = [
                  {'service': 'DaVinci AI', 'email': 'yasenlafi972@gmail.com', 'password': 'DaVinci#9982!'},
                  {'service': 'cloud.oracle', 'email': 'yasenlafi972@gmail.com', 'password': 'OracleCloud_2026'},
                  {'service': 'Nsave', 'email': 'yasenlafi972@gmail.com', 'password': '9482'},
                  {'service': 'mail.ru', 'email': 'yasen98@mail.ru', 'password': 'MailRu_Pass98!'},
                  {'service': 'Apple', 'email': 'yasenlafi972@gmail.com', 'password': 'AppleID#1998_Sp'},
                  {'service': 'Mapbox', 'email': 'yasenlafi972@gmail.com', 'password': 'Mapbox#DevToken!'},
                  {'service': 'Amazon Prime', 'email': 'yasenlafi972@gmail.com', 'password': 'Amazon_Prime26'},
                  {'service': 'PayPal', 'email': 'yasenlafi972@gmail.com', 'password': 'PayPalSecure#98'},
                ];
                final nowStr = DateTime.now().toIso8601String();
                for (final item in sampleAccounts) {
                  final encryptedPass = SecurityService.instance.encrypt(item['password']!);
                  await db.insert('person_accounts', {
                    'id': const Uuid().v4(),
                    'person_id': youId,
                    'service': item['service'],
                    'email': item['email'],
                    'password': encryptedPass,
                    'created_at': nowStr,
                    'updated_at': nowStr,
                  });
                }
              }
            }
          } catch (_) {}
        }

        if (oldVersion < 8) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS workplace_payments (
              id TEXT PRIMARY KEY,
              workplace_id TEXT NOT NULL,
              amount REAL NOT NULL,
              date TEXT NOT NULL,
              payment_method TEXT NOT NULL DEFAULT 'كاش',
              notes TEXT,
              created_at TEXT NOT NULL,
              FOREIGN KEY (workplace_id) REFERENCES workplaces(id) ON DELETE CASCADE
            )
          ''');
          try {
            await db.execute('CREATE INDEX IF NOT EXISTS idx_workplace_payments_workplace_id ON workplace_payments(workplace_id)');
          } catch (_) {}
          try {
            await db.execute('CREATE INDEX IF NOT EXISTS idx_workplace_payments_date ON workplace_payments(date)');
          } catch (_) {}
        }

        if (oldVersion < 9) {
          try {
            await db.execute('ALTER TABLE work_logs ADD COLUMN latitude REAL');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE work_logs ADD COLUMN longitude REAL');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE work_logs ADD COLUMN location_address TEXT');
          } catch (_) {}
          try {
            await db.execute("ALTER TABLE work_logs ADD COLUMN attachments TEXT DEFAULT '[]'");
          } catch (_) {}
        }

        if (oldVersion < 10) {
          try {
            await db.execute('CREATE INDEX IF NOT EXISTS idx_work_logs_person_id ON work_logs(person_id)');
          } catch (_) {}
          try {
            await db.execute('CREATE INDEX IF NOT EXISTS idx_work_logs_wp_date ON work_logs(workplace_id, date DESC)');
          } catch (_) {}
          try {
            await db.execute('CREATE INDEX IF NOT EXISTS idx_workplaces_person_id ON workplaces(person_id)');
          } catch (_) {}
          try {
            await db.execute('CREATE INDEX IF NOT EXISTS idx_debts_person_id ON debts(person_id)');
          } catch (_) {}
          try {
            await db.execute('CREATE INDEX IF NOT EXISTS idx_debts_tx_date ON debts(transaction_date DESC)');
          } catch (_) {}
          try {
            await db.execute('CREATE INDEX IF NOT EXISTS idx_debt_payments_debt_id ON debt_payments(debt_id)');
          } catch (_) {}
          try {
            await db.execute('CREATE INDEX IF NOT EXISTS idx_payments_person_id ON payments(person_id)');
          } catch (_) {}
          try {
            await db.execute('CREATE INDEX IF NOT EXISTS idx_people_is_user ON people(is_user)');
          } catch (_) {}

          // Ensure all tables and indices exist on all legacy upgrade paths
          try {
            await _ensureSchemaIntegrity(db);
          } catch (_) {}
        }

        if (oldVersion < 11) {
          try {
            await _ensureSchemaIntegrity(db);
          } catch (_) {}
        }
      },
    );
  }

  /// يضمن ربط أي سجل قديم في work_logs بالورشة / المشغل المطابق بالاسم أو إنشاء ورشة له تلقائياً
  static Future<void> _linkOrphanedWorkLogs(DatabaseExecutor db) async {
    final unlinked = await db.rawQuery('''
      SELECT DISTINCT workplace_name, city, person_id 
      FROM work_logs 
      WHERE workplace_id IS NULL OR workplace_id = ''
    ''');

    for (final row in unlinked) {
      final wpName = (row['workplace_name'] as String?)?.trim();
      if (wpName == null || wpName.isEmpty) continue;
      final city = (row['city'] as String?) ?? '';
      final personId = row['person_id'] as String?;

      // البحث عن ورشة مطابقة بنفس الاسم
      final existing = await db.query(
        'workplaces',
        where: 'name = ?',
        whereArgs: [wpName],
        limit: 1,
      );

      String wpId;
      if (existing.isNotEmpty) {
        wpId = existing.first['id'] as String;
      } else {
        wpId = const Uuid().v4();
        final now = DateTime.now().toIso8601String();
        await db.insert('workplaces', {
          'id': wpId,
          'name': wpName,
          'city': city,
          'person_id': personId,
          'daily_rate': 0.0,
          'hourly_rate': 0.0,
          'status': 'active',
          'notes': 'تم إنشاؤها تلقائياً لربط سجلات العمل السابقة',
          'created_at': now,
          'updated_at': now,
        });
      }

      // تحديث كافة السجلات المرتبطة بهذا الاسم لترتبط بمعرف الورشة
      await db.update(
        'work_logs',
        {'workplace_id': wpId},
        where: 'workplace_name = ? AND (workplace_id IS NULL OR workplace_id = \'\')',
        whereArgs: [wpName],
      );
    }
  }

  // =================== FIREBASE CLOUD BACKUP & RESTORE ===================

  /// Exports all application tables into a clean serializable Map
  Future<Map<String, List<Map<String, dynamic>>>> exportAllTables() async {
    final db = await database;
    final Map<String, List<Map<String, dynamic>>> data = {};
    const tables = [
      'people',
      'person_accounts',
      'workplaces',
      'workplace_payments',
      'work_logs',
      'payments',
      'debts',
      'debt_payments',
      'vault_items',
    ];

    for (final table in tables) {
      try {
        final rows = await db.query(table);
        data[table] = rows.map((r) => Map<String, dynamic>.from(r)).toList();
      } catch (_) {
        data[table] = [];
      }
    }
    return data;
  }

  /// Safe parsing & sanitization helper for SQLite column types
  static Map<String, dynamic> _sanitizeRowForTable(
    String table,
    Map<String, dynamic> rawRow,
    Set<String> validColumns,
  ) {
    final Map<String, dynamic> sanitized = {};

    for (final entry in rawRow.entries) {
      final key = entry.key;
      // Skip fields that do not exist as valid columns in the local SQLite table
      if (!validColumns.contains(key)) continue;

      dynamic val = entry.value;
      if (val == null) {
        sanitized[key] = null;
        continue;
      }

      // 1. Handle Timestamp / DateTime objects (Firestore Timestamp, DateTime)
      if (val is DateTime) {
        val = val.toIso8601String();
      } else if (val.runtimeType.toString() == 'Timestamp' ||
          (val is Map && val.containsKey('_seconds'))) {
        try {
          if (val is Map && val.containsKey('_seconds')) {
            final secs = (val['_seconds'] as num).toInt();
            val = DateTime.fromMillisecondsSinceEpoch(secs * 1000).toIso8601String();
          } else {
            val = (val as dynamic).toDate().toIso8601String();
          }
        } catch (_) {
          val = DateTime.now().toIso8601String();
        }
      }

      // 2. Handle Booleans (SQLite expects 1 or 0 for INTEGER)
      if (val is bool) {
        val = val ? 1 : 0;
      }

      // 3. Handle Collections / Lists / Maps (e.g. attachments in work_logs)
      if (val is List || val is Map) {
        try {
          val = jsonEncode(val);
        } catch (_) {
          val = '[]';
        }
      }

      // 4. Handle Numeric conversions safely (num -> double or int based on column)
      if (val is num) {
        if (key == 'is_user' || key == 'is_pinned') {
          val = val.toInt();
        } else if (key == 'day_fraction' ||
            key == 'rate_applied' ||
            key == 'total_earned' ||
            key == 'amount_collected' ||
            key == 'hourly_rate' ||
            key == 'daily_rate' ||
            key == 'amount' ||
            key == 'original_amount' ||
            key == 'remaining_amount' ||
            key == 'latitude' ||
            key == 'longitude') {
          val = val.toDouble();
        }
      }

      // 5. Standardize work_logs date format to yyyy-MM-dd
      if (key == 'date' && val is String && val.contains('T')) {
        val = val.split('T').first;
      }

      sanitized[key] = val;
    }

    return sanitized;
  }

  /// Imports all application tables from a cloud backup Map inside a secure transaction
  Future<void> importAllTables(Map<String, dynamic> tablesData) async {
    final db = await database;

    const orderedTables = [
      'people',
      'workplaces',
      'work_logs',
      'debts',
      'debt_payments',
      'workplace_payments',
      'person_accounts',
      'payments',
      'vault_items',
    ];

    // 1. Temporarily disable foreign keys OUTSIDE before starting the transaction
    // (In SQLite, PRAGMA foreign_keys is a no-op and ignored if called inside a transaction)
    try {
      await db.rawQuery('PRAGMA foreign_keys = OFF');
    } catch (_) {}

    try {
      await _ensureSchemaIntegrity(db);
    } catch (_) {}

    try {
      await db.transaction((txn) async {
        // 2. Non-destructive smart upsert (preserves existing valid data and avoids overwriting unchanged records)

        // 3. Populate target tables in dependency order with safe per-record parsing
        for (final table in orderedTables) {
          if (!tablesData.containsKey(table)) continue;
          final rawRows = tablesData[table];
          if (rawRows is! List) continue;

          // Fetch local schema columns for this table
          final tableInfo = await txn.rawQuery('PRAGMA table_info("$table")');
          final validColumns = tableInfo.map((c) => c['name'] as String).toSet();

          for (final rawRow in rawRows) {
            if (rawRow is! Map) continue;
            try {
              final sanitized = _sanitizeRowForTable(
                table,
                Map<String, dynamic>.from(rawRow),
                validColumns,
              );
              await txn.insert(
                table,
                sanitized,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } catch (rowErr) {
              debugPrint('>>> [Restore] Skipped row in $table: $rowErr - Data: $rawRow');
            }
          }
        }
      });
    } finally {
      // Always re-enable foreign keys OUTSIDE after transaction completes
      try {
        await db.rawQuery('PRAGMA foreign_keys = ON');
      } catch (_) {}
    }

    // Notify all UI listeners across the app that data has been completely updated
    notifyDataChanged();
  }
}
