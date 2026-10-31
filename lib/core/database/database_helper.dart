import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../security/security_service.dart';
import '../utils/arabic_date_helper.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sanad_master.db');

    return await openDatabase(
      path,
      version: 9,
      onConfigure: (db) async {
        // Enforce SQLite Foreign Key constraints
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onOpen: (db) async {
        // Auto-reconcile and link any legacy/orphaned work logs to workplace/employer
        try {
          await _linkOrphanedWorkLogs(db);
        } catch (_) {}
        try {
          await _seedLafiElectricalLogs(db);
        } catch (_) {}
      },
      onCreate: (db, version) async {
        // 1. People table (Contacts, Contractors, Employers, Self)
        await db.execute('''
          CREATE TABLE people (
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

        // 2. Workplaces table (ورش العمل والمشاريع)
        await db.execute('''
          CREATE TABLE workplaces (
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

        // 3. Work logs table (Job site sessions for workers with Workplace and City)
        await db.execute('''
          CREATE TABLE work_logs (
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

        // Indices for fast Master-Detail employer/workplace filtering and date sorting
        await db.execute('CREATE INDEX IF NOT EXISTS idx_work_logs_workplace_id ON work_logs(workplace_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_work_logs_date ON work_logs(date)');

        // 3.1 Workplace Payments table (سجل دفعات المقاولين والمشغلين على الحساب)
        await db.execute('''
          CREATE TABLE workplace_payments (
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
        await db.execute('CREATE INDEX IF NOT EXISTS idx_workplace_payments_workplace_id ON workplace_payments(workplace_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_workplace_payments_date ON workplace_payments(date)');

        // 4. Work Collections table (المقبوضات العامة للورشات والمشاريع)
        await db.execute('''
          CREATE TABLE payments (
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

        // 5. Personal Debts & Loans table (سلف وديون الأشخاص - مفصولة كلياً عن الشغل)
        await db.execute('''
          CREATE TABLE debts (
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

        // 6. Debt Installments/Repayments (سجل دفعات سداد الديون الجزئية)
        await db.execute('''
          CREATE TABLE debt_payments (
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

        // 7. Secure Vault items (Passwords, Sensitive Notes, Bank details)
        await db.execute('''
          CREATE TABLE vault_items (
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

        // 8. Person Accounts & Passwords table (قسم الإيميلات والحسابات لكل شخص)
        await db.execute('''
          CREATE TABLE person_accounts (
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
        await db.execute('CREATE INDEX IF NOT EXISTS idx_person_accounts_person_id ON person_accounts(person_id)');

        // Seed initial "You" user profile with sample matching user's card
        final defaultId = const Uuid().v4();
        final now = DateTime.now().toIso8601String();
        await db.insert('people', {
          'id': defaultId,
          'name': 'لافي',
          'is_user': 1,
          'birthdate': '1998-10-24',
          'email': 'yasenlafi972@gmail.com',
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

        // Seed sample accounts for default user
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

  /// يدرج سجلات أيام العمل الـ 18 لـ "לאפי חשמל" من سجل التدقيق المالي
  static Future<void> _seedLafiElectricalLogs(DatabaseExecutor db) async {
    final wpQuery = await db.query(
      'workplaces',
      where: 'name = ?',
      whereArgs: ['לאפי חשמל'],
      limit: 1,
    );
    String wpId;
    if (wpQuery.isNotEmpty) {
      wpId = wpQuery.first['id'] as String;
      // ضمان مسح أي بلد قديم غير مطلوب للمشغل
      await db.update(
        'workplaces',
        {'city': ''},
        where: 'id = ?',
        whereArgs: [wpId],
      );
    } else {
      wpId = const Uuid().v4();
      final now = DateTime.now().toIso8601String();
      await db.insert('workplaces', {
        'id': wpId,
        'name': 'לאפי חשמל',
        'city': '',
        'daily_rate': 400.0,
        'hourly_rate': 0.0,
        'status': 'active',
        'notes': 'LAFI Electrical',
        'created_at': now,
        'updated_at': now,
      });
    }

    final entries = [
      {'date': '2026-06-06', 'notes': 'אפי', 'city': 'تل ابيب'},
      {'date': '2026-05-30', 'notes': 'דكتور بشير', 'city': 'حيفا'},
      {'date': '2026-05-21', 'notes': 'שלומי', 'city': 'شلومي'},
      {'date': '2026-05-16', 'notes': 'ابو ربيع وسام', 'city': 'مزرعه'},
      {'date': '2026-05-12', 'notes': 'גאל', 'city': 'حيفا'},
      {'date': '2026-05-02', 'notes': 'اشرف حمود', 'city': 'كابول'},
      {'date': '2026-04-27', 'notes': 'גאל', 'city': 'طيرت الكرمل'},
      {'date': '2026-04-16', 'notes': 'ابو عزيز', 'city': 'المكر'},
      {'date': '2026-04-15', 'notes': 'ابو عزيز', 'city': 'المكر'},
      {'date': '2026-03-18', 'notes': 'ניסים +דودו', 'city': 'حيفا + نهريا'},
      {'date': '2026-03-17', 'notes': 'שי', 'city': 'حيفا'},
      {'date': '2026-03-15', 'notes': 'דودו+קארן', 'city': 'عكا + نهريا'},
      {'date': '2026-03-14', 'notes': 'ابو ملك', 'city': 'طمره'},
      {'date': '2026-03-11', 'notes': 'ניסים', 'city': 'حيفا'},
      {'date': '2026-03-10', 'notes': 'امير', 'city': 'بيسان - بيت شان'},
      {'date': '2026-03-08', 'notes': 'דودو +קארן', 'city': 'نهريا + عكا'},
      {'date': '2026-03-05', 'notes': 'דودו', 'city': 'نهريا'},
      {'date': '2026-03-04', 'notes': 'קארן', 'city': 'عكا'},
    ];

    for (final e in entries) {
      final date = e['date']!;
      final notes = e['notes']!;
      final city = e['city']!;
      final existing = await db.query(
        'work_logs',
        where: 'workplace_id = ? AND date = ?',
        whereArgs: [wpId, date],
        limit: 1,
      );
      if (existing.isEmpty) {
        final dayName = ArabicDateHelper.getWeekdayFromDateString(date);
        await db.insert('work_logs', {
          'id': const Uuid().v4(),
          'person_id': null,
          'workplace_id': wpId,
          'workplace_name': 'לאפי חשמל',
          'city': city,
          'day_name': dayName,
          'date': date,
          'rate_type': 'daily',
          'hours_worked': null,
          'day_fraction': 1.0,
          'rate_applied': 400.0,
          'total_earned': 400.0,
          'amount_collected': 400.0,
          'notes': notes,
          'created_at': '${date}T08:00:00.000Z',
        });
      }
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

  /// Imports all application tables from a cloud backup Map inside a secure transaction
  Future<void> importAllTables(Map<String, dynamic> tablesData) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final entry in tablesData.entries) {
        final table = entry.key;
        final rows = entry.value;
        if (rows is List) {
          for (final row in rows) {
            if (row is Map) {
              final map = Map<String, dynamic>.from(row);
              await txn.insert(
                table,
                map,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        }
      }
    });
  }
}
