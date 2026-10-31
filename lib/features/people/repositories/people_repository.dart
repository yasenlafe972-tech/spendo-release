import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/security/security_service.dart';
import '../../../core/services/firebase_backup_service.dart';
import '../models/person_model.dart';
import '../models/person_account_model.dart';

class PeopleRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final SecurityService _security = SecurityService.instance;

  /// Fetches all people ordered by pinned status (descending), user status (descending), and name
  Future<List<PersonModel>> getAllPeople() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'people',
      orderBy: 'is_pinned DESC, is_user DESC, name ASC',
    );

    return maps.map((map) {
      final person = PersonModel.fromMap(map);
      // Decrypt nationalId if present and encrypted
      if (person.nationalId != null && person.nationalId!.isNotEmpty) {
        final decryptedId = _security.decrypt(person.nationalId!);
        return person.copyWith(nationalId: decryptedId);
      }
      return person;
    }).toList();
  }

  /// Inserts a new person, encrypting the national ID
  Future<void> addPerson(PersonModel person) async {
    final db = await _dbHelper.database;
    String? encryptedId;
    if (person.nationalId != null && person.nationalId!.isNotEmpty) {
      encryptedId = _security.encrypt(person.nationalId!);
    }

    final personToSave = person.copyWith(nationalId: encryptedId);
    await db.insert(
      'people',
      personToSave.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    FirebaseBackupService.instance.scheduleAutoBackup();
  }

  /// Updates existing person
  Future<void> updatePerson(PersonModel person) async {
    final db = await _dbHelper.database;
    String? encryptedId;
    if (person.nationalId != null && person.nationalId!.isNotEmpty) {
      encryptedId = _security.encrypt(person.nationalId!);
    }

    final personToSave = person.copyWith(
      nationalId: encryptedId,
      updatedAt: DateTime.now(),
    );

    await db.update(
      'people',
      personToSave.toMap(),
      where: 'id = ?',
      whereArgs: [person.id],
    );
    FirebaseBackupService.instance.scheduleAutoBackup();
  }

  /// Toggles pinned state
  Future<void> togglePin(String id, bool currentStatus) async {
    final db = await _dbHelper.database;
    await db.update(
      'people',
      {
        'is_pinned': currentStatus ? 0 : 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes a person and cascades to their work logs and payments
  Future<void> deletePerson(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'people',
      where: 'id = ?',
      whereArgs: [id],
    );
    FirebaseBackupService.instance.scheduleAutoBackup();
  }

  // ==========================================
  // ACCOUNTS & PASSWORDS (قسم الإيميلات والحسابات)
  // ==========================================

  /// Fetches all accounts belonging to a person, with decrypted passwords
  Future<List<PersonAccountModel>> getAccountsForPerson(String personId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'person_accounts',
      where: 'person_id = ?',
      whereArgs: [personId],
      orderBy: 'service ASC, created_at DESC',
    );

    return maps.map((map) {
      final account = PersonAccountModel.fromMap(map);
      final decryptedPassword = _security.decrypt(account.password);
      return account.copyWith(password: decryptedPassword);
    }).toList();
  }

  /// Returns total accounts count for a specific person
  Future<int> getAccountCountForPerson(String personId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM person_accounts WHERE person_id = ?',
      [personId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Returns a map of personId -> accountCount for all people in one query
  Future<Map<String, int>> getAllAccountCounts() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT person_id, COUNT(*) as cnt FROM person_accounts GROUP BY person_id',
    );
    final map = <String, int>{};
    for (final row in result) {
      final pid = row['person_id'] as String;
      final cnt = (row['cnt'] as num).toInt();
      map[pid] = cnt;
    }
    return map;
  }

  /// Adds a new account for a person, encrypting the password at rest
  Future<void> addAccount(PersonAccountModel account) async {
    final db = await _dbHelper.database;
    final encryptedPassword = _security.encrypt(account.password);
    final accountToSave = account.copyWith(password: encryptedPassword);
    await db.insert(
      'person_accounts',
      accountToSave.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Updates an account, re-encrypting the password
  Future<void> updateAccount(PersonAccountModel account) async {
    final db = await _dbHelper.database;
    final encryptedPassword = _security.encrypt(account.password);
    final accountToSave = account.copyWith(
      password: encryptedPassword,
      updatedAt: DateTime.now(),
    );
    await db.update(
      'person_accounts',
      accountToSave.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  /// Deletes an account by id
  Future<void> deleteAccount(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'person_accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

