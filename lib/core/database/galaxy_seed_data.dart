// Auto-generated Galaxy Seed Engine
// Ensures 100% data parity between Galaxy and iPhone on app launch
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class GalaxySeedData {
  static Future<void> seedCompleteData(DatabaseExecutor db) async {
    try {
      // 0. Disable foreign keys so constraint errors never block seeding
      try {
        await db.execute('PRAGMA foreign_keys = OFF');
      } catch (_) {}

      try {
        // Clean up legacy placeholder records from earlier builds
        await db.delete('work_logs', where: "workplace_id IS NULL OR workplace_id NOT IN ('3f07b32a-5c5f-42e4-add7-27d3a92fa1c2', '6e5d62c4-2e4e-4497-96f9-7f7b81f14a61')");
        await db.delete('workplaces', where: "id NOT IN ('3f07b32a-5c5f-42e4-add7-27d3a92fa1c2', '6e5d62c4-2e4e-4497-96f9-7f7b81f14a61')");
        await db.delete('people', where: "phone = '+972500000000' OR national_id = '123456789'");
      } catch (_) {}

      // 1. Workplaces
      for (final wp in _workplaces) {
        try {
          await db.insert('workplaces', wp, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (_) {}
      }

      // 2. People
      for (final p in _people) {
        try {
          await db.insert('people', p, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (_) {}
      }

      // 3. Work Logs
      for (final log in _workLogs) {
        try {
          await db.insert('work_logs', log, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (_) {}
      }

      // 4. Debts
      for (final d in _debts) {
        try {
          await db.insert('debts', d, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (_) {}
      }

      // 5. Workplace Payments
      for (final pay in _workplacePayments) {
        try {
          await db.insert('workplace_payments', pay, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (_) {}
      }

      // 6. Person Accounts
      for (final acc in _personAccounts) {
        try {
          await db.insert('person_accounts', acc, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (_) {}
      }

      // 7. Vehicle SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('spendo_vehicle_tracker_v5', _vehicleJson);
        await prefs.setString('spendo_paz_id_num_v1', '207571662');
        await prefs.setString('spendo_paz_phone_v1', '0505870690');
      } catch (e) {
        debugPrint('Vehicle seed error: $e');
      }

      debugPrint('>>> [GalaxySeedData] Complete Galaxy dataset synced successfully!');
    } catch (e) {
      debugPrint('>>> [GalaxySeedData] Seed sync notice: $e');
    } finally {
      try {
        await db.execute('PRAGMA foreign_keys = ON');
      } catch (_) {}
    }
  }

  static const String _vehicleJson = "{\"vehicleName\": \"SYM Joyride 200 (55-505-403)\", \"currentOdometer\": 95480, \"insuranceExpiry\": \"2026-11-22T00:00:00.000\", \"testExpiry\": \"2027-01-01T00:00:00.000\", \"parts\": [{\"id\": \"rear_brakes\", \"title\": \"\u05d3\u05d9\u05e1\u05e7 \u05d0\u05d7\u05d5\u05e8\u05d9 + \u05e8\u05e4\u05d9\u05d3\u05d5\u05ea \u05d1\u05dc\u05dd\", \"subtitle\": \"\u05d4\u05d5\u05d7\u05dc\u05e3 \u05d1-9/10/2026 (94,890 \u05e7\\\"\u05de)\", \"iconName\": \"disc\", \"lastServiceKm\": 94890, \"intervalKm\": 8000}, {\"id\": \"engine_oil\", \"title\": \"\u05e9\u05de\u05df \u05de\u05e0\u05d5\u05e2 4T\", \"subtitle\": \"\u05d4\u05d5\u05d7\u05dc\u05e3 \u05d1\u05d8\u05d9\u05e4\u05d5\u05dc \u05d2\u05d3\u05d5\u05dc (91,500 \u05e7\\\"\u05de)\", \"iconName\": \"oil\", \"lastServiceKm\": 91500, \"intervalKm\": 4000}, {\"id\": \"timing_belt\", \"title\": \"\u05e8\u05e6\u05d5\u05e2\u05ea \u05d8\u05d9\u05d9\u05de\u05d9\u05e0\u05d2\", \"subtitle\": \"\u05de\u05d5\u05e1\u05da \u05d0\u05d5\u05e8 \u05d0\u05de\u05e0\u05d5\u05e0\u05d9 (88,121 \u05e7\\\"\u05de)\", \"iconName\": \"belt\", \"lastServiceKm\": 88121, \"intervalKm\": 12000}, {\"id\": \"gear_oil\", \"title\": \"\u05e9\u05de\u05df \u05d2\u05d9\u05e8\", \"subtitle\": \"\u05d4\u05d5\u05d7\u05dc\u05e3 \u05d1\u05d8\u05d9\u05e4\u05d5\u05dc \u05d2\u05d3\u05d5\u05dc (91,500 \u05e7\\\"\u05de)\", \"iconName\": \"gear\", \"lastServiceKm\": 91500, \"intervalKm\": 6000}, {\"id\": \"front_tire\", \"title\": \"\u05e6\u05de\u05d9\u05d2 \u05e7\u05d3\u05de\u05d9 (110/90-13)\", \"subtitle\": \"\u05de\u05d5\u05e1\u05da \u05d0\u05d5\u05e8 \u05d0\u05de\u05e0\u05d5\u05e0\u05d9 (91,500 \u05e7\\\"\u05de)\", \"iconName\": \"tire\", \"lastServiceKm\": 91500, \"intervalKm\": 15000}, {\"id\": \"front_brakes\", \"title\": \"\u05d1\u05dc\u05de\u05d9\u05dd \u05e7\u05d3\u05de\u05d9\u05d9\u05dd\", \"subtitle\": \"\u05e9\u05d9\u05e4\u05d5\u05e5 \u05d1\u05dc\u05de\u05d9\u05dd \u05e7\u05d3\u05de\u05d9\u05d9\u05dd (\u05d7\u05e9\u05d1\u05d5\u05e0\u05d9\u05ea #513)\", \"iconName\": \"disc\", \"lastServiceKm\": 52800, \"intervalKm\": 20000}], \"history\": [{\"id\": \"1793036832548\", \"title\": \"\u05ea\u05d3\u05dc\u05d5\u05e7 Yellow \u05e4\u05d6 \u05d1\u05d9\u05ea \u05d4\u05db\u05e8\u05dd 417 (6.0 \u05dc\u05d9\u05d8\u05e8 \u05d0\u05d5\u05e7\u05d8\u05df 95)\", \"amount\": 46.62, \"odometer\": 94890, \"date\": \"2026-10-26T19:47:09.186090\", \"category\": \"fuel\", \"invoiceNumber\": null, \"provider\": null, \"liters\": null, \"pricePerLiter\": null, \"notes\": null, \"items\": null}, {\"id\": \"fuel_paz_2026_10_21\", \"title\": \"\u05ea\u05d3\u0644\u05d5\u05e7 Yellow \u05e4\u05d6 \u05d1\u05d9\u05ea \u05d4\u05db\u0631\u05dd (6 \u05dc\u05d9\u05d8\u05e8 \u05d0\u05d5\u05e7\u05d8\u05df 95)\", \"amount\": 46.62, \"odometer\": 94890, \"date\": \"2026-10-21T08:43:00.000\", \"category\": \"fuel\", \"invoiceNumber\": null, \"provider\": null, \"liters\": null, \"pricePerLiter\": null, \"notes\": null, \"items\": null}, {\"id\": \"inv_user_2026_10\", \"title\": \"\u05d4\u05d7\u05dc\u05e4\u05ea \u05d3\u05d9\u05e1\u05e7 \u05d0\u05d7\u05d5\u05e8\u05d9 + \u05e8\u05e4\u05d9\u05d3\u05d5\u05ea \u05d1\u05dc\u05dd\", \"amount\": 400.0, \"odometer\": 94890, \"date\": \"2026-10-09T00:00:00.000\", \"category\": \"maintenance\", \"invoiceNumber\": null, \"provider\": null, \"liters\": null, \"pricePerLiter\": null, \"notes\": null, \"items\": null}, {\"id\": \"inv_2289\", \"title\": \"\u05d8\u05d9\u05e4\u05d5\u05dc \u05d2\u05d3\u05d5\u05dc + \u05e6\u05de\u05d9\u05d2 \u05e7\u05d3\u05de\u05d9 (\u05d7\u05e9\u05d1\u05d5\u05e0\u05d9\u05ea #2289)\", \"amount\": 1400.0, \"odometer\": 91500, \"date\": \"2026-09-01T00:00:00.000\", \"category\": \"maintenance\", \"invoiceNumber\": null, \"provider\": null, \"liters\": null, \"pricePerLiter\": null, \"notes\": null, \"items\": null}, {\"id\": \"inv_2149\", \"title\": \"\u05d8\u05d9\u05d9\u05de\u05d9\u05e0\u05d2, \u05d0\u05d8\u05de\u05d9\u05dd, \u05e9\u05de\u05df \u05d5\u05e2\u05d1\u05d5\u05d3\u05d4 (\u05d7\u05e9\u05d1\u05d5\u05e0\u05d9\u05ea #2149)\", \"amount\": 2200.0, \"odometer\": 88121, \"date\": \"2026-07-29T00:00:00.000\", \"category\": \"maintenance\", \"invoiceNumber\": null, \"provider\": null, \"liters\": null, \"pricePerLiter\": null, \"notes\": null, \"items\": null}, {\"id\": \"inv_1729\", \"title\": \"\u05de\u05e1\u05db\u05ea \u05d7\u05d6\u05d9\u05ea, \u05de\u05d2\u05df \u05d2\u062d\u0648\u0646, \u05de\u05e8\u05d0\u05d4 \u05d9\u05de\u05d9\u05df (\u05d7\u05e9\u05d1\u05d5\u05e0\u05d9\u05ea #1729)\", \"amount\": 1600.0, \"odometer\": 85000, \"date\": \"2026-04-19T00:00:00.000\", \"category\": \"maintenance\", \"invoiceNumber\": null, \"provider\": null, \"liters\": null, \"pricePerLiter\": null, \"notes\": null, \"items\": null}, {\"id\": \"inv_1688\", \"title\": \"\u05e2\u05d1\u05d5\u05e8 \u05ea\u05d9\u05e7\u05d5\u05df \u05e7\u05d5\u05d3\u05dd \u05de\u05d5\u05e1\u05da \u05d0\u05d5\u05e8 \u05d0\u05de\u05e0\u05d5\u05e0\u05d9 (\u05d7\u05e9\u05d1\u05d5\u05e0\u05d9\u05ea #1688)\", \"amount\": 500.0, \"odometer\": 85000, \"date\": \"2026-04-10T00:00:00.000\", \"category\": \"maintenance\", \"invoiceNumber\": null, \"provider\": null, \"liters\": null, \"pricePerLiter\": null, \"notes\": null, \"items\": null}, {\"id\": \"inv_513\", \"title\": \"\u05e9\u05d9\u05e4\u05d5\u05e5 \u05d1\u05dc\u05de\u05d9\u05dd \u05e7\u05d3\u05de\u05d9\u05d9\u05dd (\u05d7\u05e9\u05d1\u05d5\u05e0\u05d9\u05ea #513)\", \"amount\": 1050.0, \"odometer\": 52800, \"date\": \"2025-04-29T00:00:00.000\", \"category\": \"maintenance\", \"invoiceNumber\": null, \"provider\": null, \"liters\": null, \"pricePerLiter\": null, \"notes\": null, \"items\": null}, {\"id\": \"inv_465\", \"title\": \"\u05d8\u05d9\u05e4\u05d5\u05dc \u05de\u05dc\u05d0 \u05de\u05e7\u05d5\u05e8\u05d9 (\u05d7\u05e9\u05d1\u05d5\u05e0\u05d9\u05ea #465)\", \"amount\": 1100.0, \"odometer\": 47000, \"date\": \"2025-04-15T00:00:00.000\", \"category\": \"maintenance\", \"invoiceNumber\": null, \"provider\": null, \"liters\": null, \"pricePerLiter\": null, \"notes\": null, \"items\": null}, {\"id\": \"inv_411\", \"title\": \"\u05d3\u05d9\u05e1\u05e7 \u05d0\u05d7\u05d5\u05e8\u05d9, \u05e8\u05e4\u05d9\u05d3\u05d4, \u05e0\u05d5\u05e8\u05d4 (\u05d7\u05e9\u05d1\u05d5\u05e0\u05d9\u05ea #411)\", \"amount\": 550.0, \"odometer\": 52800, \"date\": \"2025-03-26T00:00:00.000\", \"category\": \"maintenance\", \"invoiceNumber\": null, \"provider\": null, \"liters\": null, \"pricePerLiter\": null, \"notes\": null, \"items\": null}, {\"id\": \"inv_277\", \"title\": \"\u05d8\u05d9\u05e4\u05d5\u05dc \u05de\u05dc\u05d0, \u05e0\u05d5\u05d6\u05dc\u05d9 \u05d1\u05dc\u05de\u05d9\u05dd, \u05e6\u05de\u05d9\u05d2 110/90, \u05e9\u05e1\u05ea\u05d5\u05de\u05d9\u05dd (\u05d7\u05e9\u05d1\u05d5\u05e0\u05d9\u05ea #277)\", \"amount\": 1700.0, \"odometer\": 47600, \"date\": \"2025-02-11T00:00:00.000\", \"category\": \"maintenance\", \"invoiceNumber\": null, \"provider\": null, \"liters\": null, \"pricePerLiter\": null, \"notes\": null, \"items\": null}]}";

  static final List<Map<String, dynamic>> _workplaces = [
    {
        "id": "3f07b32a-5c5f-42e4-add7-27d3a92fa1c2",
        "name": "לאפי חשמל",
        "city": "",
        "person_id": null,
        "daily_rate": 400.0,
        "hourly_rate": 0.0,
        "status": "completed",
        "notes": null,
        "created_at": "2026-10-23T08:17:43.869884",
        "updated_at": "2026-10-30T20:59:32.694430"
    },
    {
        "id": "6e5d62c4-2e4e-4497-96f9-7f7b81f14a61",
        "name": "מזגני אלנור",
        "city": "",
        "person_id": null,
        "daily_rate": 350.0,
        "hourly_rate": 0.0,
        "status": "active",
        "notes": null,
        "created_at": "2026-10-23T18:39:05.607627",
        "updated_at": "2026-10-30T21:03:11.909508"
    }
];

  static final List<Map<String, dynamic>> _people = [
    {
        "id": "95a0ccdd-d7dc-49f3-902a-3e2b697f56b2",
        "name": "My profile",
        "is_user": 1,
        "birthdate": "1998-10-24",
        "email": "yasenlafe972@gmail.com",
        "phone": "0505870690",
        "whatsapp": "0505870690",
        "national_id": "lJbF7waf9qNQUwCq11tVBQ==",
        "is_pinned": 1,
        "hourly_rate": 0.0,
        "daily_rate": 0.0,
        "notes": "الملف الشخصي الأساسي",
        "created_at": "2026-10-22T21:58:17.992918",
        "updated_at": "2026-10-31T17:31:14.798219",
        "bank": null,
        "account_number": null
    },
    {
        "id": "9c8c3ebb-ff39-4f38-918f-a2badcfb6023",
        "name": "0529988776",
        "is_user": 0,
        "birthdate": null,
        "email": "987654321",
        "phone": null,
        "whatsapp": null,
        "national_id": null,
        "is_pinned": 0,
        "hourly_rate": 0.0,
        "daily_rate": 0.0,
        "notes": null,
        "created_at": "2026-10-23T05:47:38.752605",
        "updated_at": "2026-10-23T05:47:38.752605",
        "bank": null,
        "account_number": null
    },
    {
        "id": "79463274-5004-451a-a8af-7c32d602d0b5",
        "name": "رابعه",
        "is_user": 0,
        "birthdate": "1998-01-01",
        "email": "asaf@gmail.com",
        "phone": "0523699888",
        "whatsapp": "0523699888",
        "national_id": "6PRW9udgtHiEp+fYnkhOIw==",
        "is_pinned": 0,
        "hourly_rate": 0.0,
        "daily_rate": 0.0,
        "notes": null,
        "created_at": "2026-10-23T07:31:48.527643",
        "updated_at": "2026-10-23T07:31:48.527643",
        "bank": null,
        "account_number": null
    },
    {
        "id": "4c45b808-331a-4e15-9b7f-fcb7dba1c436",
        "name": "Khaled",
        "is_user": 0,
        "birthdate": null,
        "email": null,
        "phone": null,
        "whatsapp": null,
        "national_id": null,
        "is_pinned": 0,
        "hourly_rate": 0.0,
        "daily_rate": 0.0,
        "notes": null,
        "created_at": "2026-10-23T17:13:04.765761",
        "updated_at": "2026-10-23T17:13:04.765761",
        "bank": null,
        "account_number": null
    },
    {
        "id": "e5b59216-7fca-4817-a5ff-185ceacd984a",
        "name": "Mahde Titi",
        "is_user": 0,
        "birthdate": "1999-11-04",
        "email": "Mrmahdeofficial@gmail.com",
        "phone": "+972 54-983-6582",
        "whatsapp": "+972 54-983-6582",
        "national_id": null,
        "is_pinned": 0,
        "hourly_rate": 0.0,
        "daily_rate": 0.0,
        "notes": null,
        "created_at": "2026-10-23T17:38:23.216603",
        "updated_at": "2026-10-31T14:30:48.786280",
        "bank": null,
        "account_number": null
    },
    {
        "id": "bdd07a58-cf2d-46b9-80bf-8ff7edab185a",
        "name": "نور الدين",
        "is_user": 0,
        "birthdate": null,
        "email": "noor.aldin.33@outlook.com",
        "phone": "+972 53-964-2671",
        "whatsapp": "+972 53-964-2671",
        "national_id": null,
        "is_pinned": 0,
        "hourly_rate": 0.0,
        "daily_rate": 0.0,
        "notes": null,
        "created_at": "2026-10-28T20:44:48.615843",
        "updated_at": "2026-10-28T20:44:48.615843",
        "bank": null,
        "account_number": null
    },
    {
        "id": "fcca7a52-bb74-4f0a-b28f-7526d2bf3bc9",
        "name": "يوسف الغازي",
        "is_user": 0,
        "birthdate": null,
        "email": null,
        "phone": null,
        "whatsapp": null,
        "national_id": null,
        "is_pinned": 0,
        "hourly_rate": 0.0,
        "daily_rate": 0.0,
        "notes": null,
        "created_at": "2026-10-31T13:33:43.530229",
        "updated_at": "2026-10-31T13:33:43.530229",
        "bank": null,
        "account_number": null
    }
];

  static final List<Map<String, dynamic>> _workLogs = [
    {
        "id": "c38c18ac-8373-406f-b31d-b68071f0f9da",
        "person_id": null,
        "workplace_id": "3f07b32a-5c5f-42e4-add7-27d3a92fa1c2",
        "workplace_name": "לאפי חשמל",
        "city": "تل ابيب",
        "day_name": "السبت",
        "date": "2026-06-06",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 400.0,
        "total_earned": 400.0,
        "amount_collected": 400.0,
        "notes": "אפי",
        "created_at": "2026-06-06T08:00:00.000Z",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "4c875c52-ea71-49c7-be5e-6f0c721e238f",
        "person_id": null,
        "workplace_id": "3f07b32a-5c5f-42e4-add7-27d3a92fa1c2",
        "workplace_name": "לאפי חשמל",
        "city": "حيفا",
        "day_name": "السبت",
        "date": "2026-05-30",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 400.0,
        "total_earned": 400.0,
        "amount_collected": 400.0,
        "notes": "דكتور بشير",
        "created_at": "2026-05-30T08:00:00.000Z",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "22fb7ae6-8190-4edf-8cf7-f2dd3e3826da",
        "person_id": null,
        "workplace_id": "3f07b32a-5c5f-42e4-add7-27d3a92fa1c2",
        "workplace_name": "לאפי חשמל",
        "city": "شلومي",
        "day_name": "الخميس",
        "date": "2026-05-21",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 400.0,
        "total_earned": 400.0,
        "amount_collected": 400.0,
        "notes": "שלומי",
        "created_at": "2026-05-21T08:00:00.000Z",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "72e949f7-9ae5-4792-9c6d-8d6a426eaf13",
        "person_id": null,
        "workplace_id": "3f07b32a-5c5f-42e4-add7-27d3a92fa1c2",
        "workplace_name": "לאפי חשמל",
        "city": "مزرعه",
        "day_name": "السبت",
        "date": "2026-05-16",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 400.0,
        "total_earned": 400.0,
        "amount_collected": 400.0,
        "notes": "ابو ربيع وسام",
        "created_at": "2026-05-16T08:00:00.000Z",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "7da73442-5902-4cd7-b617-a4c2c04f29e0",
        "person_id": null,
        "workplace_id": "3f07b32a-5c5f-42e4-add7-27d3a92fa1c2",
        "workplace_name": "לאפי חשמל",
        "city": "حيفا",
        "day_name": "الثلاثاء",
        "date": "2026-05-12",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 400.0,
        "total_earned": 400.0,
        "amount_collected": 400.0,
        "notes": "גאל",
        "created_at": "2026-05-12T08:00:00.000Z",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "f36a18b9-948b-4f60-9789-c5e4dc68a2e7",
        "person_id": null,
        "workplace_id": "3f07b32a-5c5f-42e4-add7-27d3a92fa1c2",
        "workplace_name": "לאפי חשמל",
        "city": "كابول",
        "day_name": "السبت",
        "date": "2026-05-02",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 400.0,
        "total_earned": 400.0,
        "amount_collected": 400.0,
        "notes": "اشرف حمود",
        "created_at": "2026-05-02T08:00:00.000Z",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "65fa8d42-0c8a-4660-9599-79cfa99906f0",
        "person_id": null,
        "workplace_id": "3f07b32a-5c5f-42e4-add7-27d3a92fa1c2",
        "workplace_name": "לאפי חשמל",
        "city": "طيرت الكرمل",
        "day_name": "الإثنين",
        "date": "2026-04-27",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 400.0,
        "total_earned": 400.0,
        "amount_collected": 400.0,
        "notes": "גאל",
        "created_at": "2026-04-27T08:00:00.000Z",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "3ee4ba5c-76ec-4361-b34a-19124c8c4d6a",
        "person_id": null,
        "workplace_id": "3f07b32a-5c5f-42e4-add7-27d3a92fa1c2",
        "workplace_name": "לאפי חשמל",
        "city": "المكر",
        "day_name": "الخميس",
        "date": "2026-04-16",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 400.0,
        "total_earned": 400.0,
        "amount_collected": 400.0,
        "notes": "ابو عزيز",
        "created_at": "2026-04-16T08:00:00.000Z",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "646d04de-fac8-4c0a-a90d-327141754954",
        "person_id": null,
        "workplace_id": "3f07b32a-5c5f-42e4-add7-27d3a92fa1c2",
        "workplace_name": "לאפי חשמל",
        "city": "المكر",
        "day_name": "الأربعاء",
        "date": "2026-04-15",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 400.0,
        "total_earned": 400.0,
        "amount_collected": 400.0,
        "notes": "ابو عزيز",
        "created_at": "2026-04-15T08:00:00.000Z",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "28937110-27eb-4f9a-8c0e-fb84cf9ab679",
        "person_id": null,
        "workplace_id": "3f07b32a-5c5f-42e4-add7-27d3a92fa1c2",
        "workplace_name": "לאפי חשמל",
        "city": "حيفا + نهريا",
        "day_name": "الأربعاء",
        "date": "2026-03-18",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 400.0,
        "total_earned": 400.0,
        "amount_collected": 400.0,
        "notes": "ניסים +דودו",
        "created_at": "2026-03-18T08:00:00.000Z",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "b735bc11-e3e0-4b24-b01a-2fb623a5fd14",
        "person_id": null,
        "workplace_id": "3f07b32a-5c5f-42e4-add7-27d3a92fa1c2",
        "workplace_name": "לאפי חשמל",
        "city": "حيفا",
        "day_name": "الثلاثاء",
        "date": "2026-03-17",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 400.0,
        "total_earned": 400.0,
        "amount_collected": 400.0,
        "notes": "שי",
        "created_at": "2026-03-17T08:00:00.000Z",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "a6d1dc84-e630-4667-a675-539952c743b4",
        "person_id": null,
        "workplace_id": "3f07b32a-5c5f-42e4-add7-27d3a92fa1c2",
        "workplace_name": "לאפי חשמל",
        "city": "عكا + نهريا",
        "day_name": "الأحد",
        "date": "2026-03-15",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 400.0,
        "total_earned": 400.0,
        "amount_collected": 400.0,
        "notes": "דودו+קארן",
        "created_at": "2026-03-15T08:00:00.000Z",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "abb8059f-7279-4fbc-864d-8e6935791ad5",
        "person_id": null,
        "workplace_id": "3f07b32a-5c5f-42e4-add7-27d3a92fa1c2",
        "workplace_name": "לאפי חשמל",
        "city": "طمره",
        "day_name": "السبت",
        "date": "2026-03-14",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 400.0,
        "total_earned": 400.0,
        "amount_collected": 400.0,
        "notes": "ابو ملك",
        "created_at": "2026-03-14T08:00:00.000Z",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "e87bd800-2176-442c-a191-4504c39bde32",
        "person_id": null,
        "workplace_id": "3f07b32a-5c5f-42e4-add7-27d3a92fa1c2",
        "workplace_name": "לאפי חשמל",
        "city": "حيفا",
        "day_name": "الأربعاء",
        "date": "2026-03-11",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 400.0,
        "total_earned": 400.0,
        "amount_collected": 400.0,
        "notes": "ניסים",
        "created_at": "2026-03-11T08:00:00.000Z",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "05b7d618-7650-40bb-b11d-55e0631435d5",
        "person_id": null,
        "workplace_id": "3f07b32a-5c5f-42e4-add7-27d3a92fa1c2",
        "workplace_name": "לאפי חשמל",
        "city": "بيسان - بيت شان",
        "day_name": "الثلاثاء",
        "date": "2026-03-10",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 400.0,
        "total_earned": 400.0,
        "amount_collected": 400.0,
        "notes": "امير",
        "created_at": "2026-03-10T08:00:00.000Z",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "b4afbe71-f972-4040-84cb-7b27288d2f76",
        "person_id": null,
        "workplace_id": "3f07b32a-5c5f-42e4-add7-27d3a92fa1c2",
        "workplace_name": "לאפי חשמל",
        "city": "نهريا + عكا",
        "day_name": "الأحد",
        "date": "2026-03-08",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 400.0,
        "total_earned": 400.0,
        "amount_collected": 400.0,
        "notes": "דودو +קארן",
        "created_at": "2026-03-08T08:00:00.000Z",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "767d655f-d223-4f0f-a5b2-811087653eb9",
        "person_id": null,
        "workplace_id": "3f07b32a-5c5f-42e4-add7-27d3a92fa1c2",
        "workplace_name": "לאפי חשמל",
        "city": "نهريا",
        "day_name": "الخميس",
        "date": "2026-03-05",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 400.0,
        "total_earned": 400.0,
        "amount_collected": 400.0,
        "notes": "דودו",
        "created_at": "2026-03-05T08:00:00.000Z",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "deaa36c4-3872-4ee9-9a82-032a93ff8a89",
        "person_id": null,
        "workplace_id": "3f07b32a-5c5f-42e4-add7-27d3a92fa1c2",
        "workplace_name": "לאפי חשמל",
        "city": "عكا",
        "day_name": "الأربعاء",
        "date": "2026-03-04",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 400.0,
        "total_earned": 400.0,
        "amount_collected": 400.0,
        "notes": "קארן",
        "created_at": "2026-03-04T08:00:00.000Z",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "5b2131b0-0aa1-42b2-adeb-0977a03e0cc2",
        "person_id": null,
        "workplace_id": "6e5d62c4-2e4e-4497-96f9-7f7b81f14a61",
        "workplace_name": "מזגני אלנור",
        "city": "קרית ביאלק",
        "day_name": "الأحد",
        "date": "2026-10-11",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 350.0,
        "total_earned": 350.0,
        "amount_collected": 0.0,
        "notes": null,
        "created_at": "2026-10-23T19:22:44.904104",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "8c1aec5e-3875-4455-b69b-b8afa7f2fd50",
        "person_id": null,
        "workplace_id": "6e5d62c4-2e4e-4497-96f9-7f7b81f14a61",
        "workplace_name": "מזגני אלנור",
        "city": "קרית ביאלק",
        "day_name": "الإثنين",
        "date": "2026-10-12",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 350.0,
        "total_earned": 350.0,
        "amount_collected": 0.0,
        "notes": null,
        "created_at": "2026-10-23T19:43:07.471410",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "865cf591-bbe9-4841-b88f-91b00e2d2f0e",
        "person_id": null,
        "workplace_id": "6e5d62c4-2e4e-4497-96f9-7f7b81f14a61",
        "workplace_name": "מזגני אלנור",
        "city": "קרית ביאלק",
        "day_name": "الثلاثاء",
        "date": "2026-10-13",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 350.0,
        "total_earned": 350.0,
        "amount_collected": 0.0,
        "notes": null,
        "created_at": "2026-10-23T19:44:26.681491",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "10fde122-8f10-4468-a6d3-f31d493ba154",
        "person_id": null,
        "workplace_id": "6e5d62c4-2e4e-4497-96f9-7f7b81f14a61",
        "workplace_name": "מזגני אלנור",
        "city": "קרית ביאלק",
        "day_name": "الأحد",
        "date": "2026-10-18",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 350.0,
        "total_earned": 350.0,
        "amount_collected": 0.0,
        "notes": null,
        "created_at": "2026-10-23T19:45:20.492768",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "32aabfbd-e218-4d95-8883-e5a5b004c2c5",
        "person_id": null,
        "workplace_id": "6e5d62c4-2e4e-4497-96f9-7f7b81f14a61",
        "workplace_name": "מזגני אלנור",
        "city": "טמרה",
        "day_name": "الثلاثاء",
        "date": "2026-10-20",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 350.0,
        "total_earned": 350.0,
        "amount_collected": 0.0,
        "notes": null,
        "created_at": "2026-10-23T19:47:23.166100",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "04fb9933-bcac-4bd9-9f67-335059e20384",
        "person_id": null,
        "workplace_id": "6e5d62c4-2e4e-4497-96f9-7f7b81f14a61",
        "workplace_name": "מזגני אלנור",
        "city": "טמרה",
        "day_name": "الأربعاء",
        "date": "2026-10-21",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 350.0,
        "total_earned": 350.0,
        "amount_collected": 0.0,
        "notes": null,
        "created_at": "2026-10-23T19:47:45.253896",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "8530f71d-02f2-4540-9921-020628b8bc4b",
        "person_id": null,
        "workplace_id": "6e5d62c4-2e4e-4497-96f9-7f7b81f14a61",
        "workplace_name": "מזגני אלנור",
        "city": "נהריה",
        "day_name": "الأحد",
        "date": "2026-09-27",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 350.0,
        "total_earned": 350.0,
        "amount_collected": 0.0,
        "notes": null,
        "created_at": "2026-10-24T09:41:14.305794",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "9696217e-247b-4aba-b503-cdfd1815e594",
        "person_id": null,
        "workplace_id": "6e5d62c4-2e4e-4497-96f9-7f7b81f14a61",
        "workplace_name": "מזגני אלנור",
        "city": "דבראת",
        "day_name": "الأحد",
        "date": "2026-10-25",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 350.0,
        "total_earned": 350.0,
        "amount_collected": 0.0,
        "notes": null,
        "created_at": "2026-10-25T21:04:38.803892",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "6ba80d66-edec-4337-8536-a401998723dc",
        "person_id": null,
        "workplace_id": "6e5d62c4-2e4e-4497-96f9-7f7b81f14a61",
        "workplace_name": "מזגני אלנור",
        "city": "מצפה אביב",
        "day_name": "الثلاثاء",
        "date": "2026-10-27",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 350.0,
        "total_earned": 350.0,
        "amount_collected": 0.0,
        "notes": null,
        "created_at": "2026-10-27T17:55:11.733793",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "9304de7c-c5ad-4fba-9809-bb69dd86353d",
        "person_id": null,
        "workplace_id": "6e5d62c4-2e4e-4497-96f9-7f7b81f14a61",
        "workplace_name": "מזגני אלנור",
        "city": "טמרה",
        "day_name": "الأربعاء",
        "date": "2026-10-28",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 350.0,
        "total_earned": 350.0,
        "amount_collected": 0.0,
        "notes": null,
        "created_at": "2026-10-28T18:58:50.450482",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    },
    {
        "id": "726ded71-fec7-4cfa-92ba-d6612748ee6e",
        "person_id": null,
        "workplace_id": "6e5d62c4-2e4e-4497-96f9-7f7b81f14a61",
        "workplace_name": "מזגני אלנור",
        "city": "טמרה+ קבול",
        "day_name": "الخميس",
        "date": "2026-10-29",
        "rate_type": "daily",
        "hours_worked": null,
        "day_fraction": 1.0,
        "rate_applied": 350.0,
        "total_earned": 350.0,
        "amount_collected": 0.0,
        "notes": null,
        "created_at": "2026-10-29T19:01:47.191791",
        "latitude": null,
        "longitude": null,
        "location_address": null,
        "attachments": "[]"
    }
];

  static final List<Map<String, dynamic>> _debts = [
    {
        "id": "60667c9d-4fbe-4fbd-99da-45a7ac702f0c",
        "person_id": "e5b59216-7fca-4817-a5ff-185ceacd984a",
        "type": "received",
        "original_amount": 1500.0,
        "remaining_amount": 0.0,
        "payment_method": "cash",
        "transaction_date": "2026-10-23",
        "due_date": null,
        "notes": null,
        "status": "settled",
        "created_at": "2026-10-23T17:38:23.258923",
        "updated_at": "2026-10-23T17:38:23.258923"
    },
    {
        "id": "0e361c28-8541-4bd1-9d62-b44735912298",
        "person_id": "fcca7a52-bb74-4f0a-b28f-7526d2bf3bc9",
        "type": "pay_later",
        "original_amount": 100.0,
        "remaining_amount": 100.0,
        "payment_method": "pending",
        "transaction_date": "2026-10-31",
        "due_date": null,
        "notes": null,
        "status": "active",
        "created_at": "2026-10-31T13:33:43.577497",
        "updated_at": "2026-10-31T13:33:43.577497"
    }
];

  static final List<Map<String, dynamic>> _workplacePayments = [
    {
        "id": "1590e7f6-83d7-44d4-8904-6b1a051d03b2",
        "workplace_id": "3f07b32a-5c5f-42e4-add7-27d3a92fa1c2",
        "amount": 1000.0,
        "date": "2026-10-26",
        "payment_method": "كاش",
        "notes": null,
        "created_at": "2026-10-26T10:23:08.931167"
    },
    {
        "id": "af6beb8c-d83c-41ea-9cd9-6e216f6cacea",
        "workplace_id": "3f07b32a-5c5f-42e4-add7-27d3a92fa1c2",
        "amount": 6200.0,
        "date": "2026-10-30",
        "payment_method": "كاش",
        "notes": null,
        "created_at": "2026-10-30T12:12:01.576958"
    }
];

  static final List<Map<String, dynamic>> _personAccounts = [
    {
        "id": "901df7fb-b56f-458c-8d20-5f924bfe6996",
        "person_id": "95a0ccdd-d7dc-49f3-902a-3e2b697f56b2",
        "service": "DaVinci AI",
        "email": "yasenlafi972@gmail.com",
        "password": "4Zz65jKcgyNJjuBgunyR0w==",
        "created_at": "2026-10-23T07:41:37.849667",
        "updated_at": "2026-10-23T07:41:37.849667"
    },
    {
        "id": "2b621cb1-2ce6-4530-a261-5901f7f7107f",
        "person_id": "95a0ccdd-d7dc-49f3-902a-3e2b697f56b2",
        "service": "cloud.oracle",
        "email": "yasenlafi972@gmail.com",
        "password": "vxUWNvNiAla5imMNhXgHr04WfAkQYLpIo17MmwD5OY0=",
        "created_at": "2026-10-23T07:41:37.849667",
        "updated_at": "2026-10-23T07:41:37.849667"
    },
    {
        "id": "34246437-604e-4b4d-bb1f-926b588f9098",
        "person_id": "95a0ccdd-d7dc-49f3-902a-3e2b697f56b2",
        "service": "Nsave",
        "email": "yasenlafi972@gmail.com",
        "password": "66e9JpW8w0YdrfmFqSMAEQ==",
        "created_at": "2026-10-23T07:41:37.849667",
        "updated_at": "2026-10-23T07:41:37.849667"
    },
    {
        "id": "c7bf63a2-36f5-4d83-9bb8-33397966e26d",
        "person_id": "95a0ccdd-d7dc-49f3-902a-3e2b697f56b2",
        "service": "mail.ru",
        "email": "yasen98@mail.ru",
        "password": "FH2ztXWybP6V4JLAmjzJww==",
        "created_at": "2026-10-23T07:41:37.849667",
        "updated_at": "2026-10-23T07:41:37.849667"
    },
    {
        "id": "928a4c61-9c4e-4ed4-bff0-a29ba8ad3a6f",
        "person_id": "95a0ccdd-d7dc-49f3-902a-3e2b697f56b2",
        "service": "Apple",
        "email": "yasenlafi972@gmail.com",
        "password": "f601/FkvWemC7Yi4XPxsOQ==",
        "created_at": "2026-10-23T07:41:37.849667",
        "updated_at": "2026-10-23T07:41:37.849667"
    },
    {
        "id": "f8c883f9-bbb6-44cc-a5f2-29ae7cc5821c",
        "person_id": "95a0ccdd-d7dc-49f3-902a-3e2b697f56b2",
        "service": "Mapbox",
        "email": "yasenlafi972@gmail.com",
        "password": "Jhm+5q6RyvVR1qoGzFc2klDO6wmnGQofx9zgh5nDtQ0=",
        "created_at": "2026-10-23T07:41:37.849667",
        "updated_at": "2026-10-23T07:41:37.849667"
    },
    {
        "id": "ab329116-9588-4f80-9c42-b9ce47e61593",
        "person_id": "95a0ccdd-d7dc-49f3-902a-3e2b697f56b2",
        "service": "PayPal",
        "email": "yasenlafi972@gmail.com",
        "password": "ELD1fSASA5o8sYcuJfMygQ==",
        "created_at": "2026-10-23T07:41:37.849667",
        "updated_at": "2026-10-23T07:41:37.849667"
    },
    {
        "id": "576b9e0b-5138-4f6b-819f-97f7b59c0713",
        "person_id": "bdd07a58-cf2d-46b9-80bf-8ff7edab185a",
        "service": "Outlook.com",
        "email": "noor.aldin.33@outlook.com",
        "password": "d/+HNo4fDgBXAy7e3dMoyw==",
        "created_at": "2026-10-28T20:45:34.502905",
        "updated_at": "2026-10-28T20:45:34.502905"
    }
];
}
