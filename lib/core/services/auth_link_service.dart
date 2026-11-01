import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:sanad_app/core/database/database_helper.dart';
import 'package:sanad_app/core/services/firebase_backup_service.dart';

/// Service to securely link, store, and authenticate account credentials
/// both in Firebase Auth and locally in FlutterSecureStorage + SQLite.
class AuthLinkService {
  AuthLinkService._();

  static const String _keyEmail = 'spendo_linked_account_email';
  static const String _keyPassword = 'spendo_linked_account_password';
  static const String _keyIsLoggedIn = 'spendo_linked_account_logged_in';
  static const String _keySessionActive = 'spendo_auth_session_active_v2';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Checks if an account is currently linked and logged in
  static Future<bool> isAccountLoggedIn() async {
    try {
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser != null) return true;
    } catch (_) {}

    try {
      final sessionActive = await _storage.read(key: _keySessionActive);
      if (sessionActive == 'true') return true;
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final prefSession = prefs.getString(_keySessionActive);
      if (prefSession == 'true') return true;
    } catch (_) {}

    return false;
  }

  /// Gets the currently linked email
  static Future<String> getLinkedEmail() async {
    try {
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser?.email != null && fbUser!.email!.isNotEmpty) {
        return fbUser.email!;
      }
    } catch (_) {}
    try {
      final savedEmail = await _storage.read(key: _keyEmail);
      if (savedEmail != null && savedEmail.isNotEmpty) {
        return savedEmail;
      }
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefEmail = prefs.getString(_keyEmail);
      if (prefEmail != null && prefEmail.isNotEmpty) {
        return prefEmail;
      }
    } catch (_) {}
    return '';
  }

  /// Verifies credentials for offline/secure authentication
  static Future<bool> verifyCredentials(String identifier, String password) async {
    final cleanId = identifier.trim().toLowerCase();
    final cleanPw = password.trim();

    final targetEmail = (await getLinkedEmail()).trim().toLowerCase();
    if (targetEmail.isEmpty) return false;

    String? savedPw;
    try {
      savedPw = await _storage.read(key: _keyPassword);
    } catch (_) {}

    if (savedPw == null || savedPw.isEmpty) return false;

    // Match full email or username before @
    final targetPrefix = targetEmail.split('@').first;
    final matchesEmail = (cleanId == targetEmail || cleanId == targetPrefix);
    final matchesPassword = (cleanPw == savedPw);

    if (matchesEmail && matchesPassword) {
      await markLoggedIn(true);
      return true;
    }
    return false;
  }

  /// Marks the current local session as logged in or logged out
  static Future<void> markLoggedIn(bool loggedIn) async {
    try {
      await _storage.write(key: _keySessionActive, value: loggedIn ? 'true' : 'false');
      await _storage.write(key: _keyIsLoggedIn, value: loggedIn ? 'true' : 'false');
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySessionActive, loggedIn ? 'true' : 'false');
      await prefs.setString(_keyIsLoggedIn, loggedIn ? 'true' : 'false');
    } catch (_) {}
  }

  /// Performs full logout (Firebase Auth + Secure Storage)
  static Future<void> performLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    try {
      await _storage.write(key: _keySessionActive, value: 'false');
      await _storage.write(key: _keyIsLoggedIn, value: 'false');
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySessionActive, 'false');
      await prefs.setString(_keyIsLoggedIn, 'false');
    } catch (_) {}
  }

  /// Links the current account with designated credentials
  static Future<User?> linkAccount({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    // 1. Store credentials securely
    try {
      await _storage.write(key: _keyEmail, value: cleanEmail);
      await _storage.write(key: _keyPassword, value: cleanPassword);
    } catch (_) {}

    // 2. Remember in SharedPreferences for UI prefill
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('remembered_auth_identifier', cleanEmail);
    } catch (_) {}

    // 3. Update local SQLite user profile
    try {
      final db = await DatabaseHelper.instance.database;
      final userRows = await db.query(
        'people',
        where: 'is_user = 1',
        limit: 1,
      );

      final nowIso = DateTime.now().toIso8601String();
      if (userRows.isNotEmpty) {
        await db.update(
          'people',
          {
            'email': cleanEmail,
            'updated_at': nowIso,
          },
          where: 'is_user = 1',
        );
        debugPrint('>>> [AuthLink] Updated local profile email to $cleanEmail');
      } else {
        await db.insert('people', {
          'id': const Uuid().v4(),
          'name': 'لافي',
          'email': cleanEmail,
          'is_user': 1,
          'created_at': nowIso,
          'updated_at': nowIso,
        });
        debugPrint('>>> [AuthLink] Created local profile for $cleanEmail');
      }
    } catch (dbErr) {
      debugPrint('>>> [AuthLink] SQLite update error: $dbErr');
    }

    // 4. Attempt Firebase Auth authentication in background
    User? user;
    try {
      final auth = FirebaseAuth.instance;
      user = auth.currentUser;

      if (user != null && user.email?.toLowerCase() == cleanEmail.toLowerCase()) {
        debugPrint('>>> [AuthLink] Already authenticated in Firebase: ${user.email} (${user.uid})');
      } else {
        debugPrint('>>> [AuthLink] Signing in with $cleanEmail...');
        try {
          final cred = await auth.signInWithEmailAndPassword(
            email: cleanEmail,
            password: cleanPassword,
          );
          user = cred.user;
          debugPrint('>>> [AuthLink] Firebase sign-in successful: ${user?.uid}');
        } on FirebaseAuthException catch (signInErr) {
          debugPrint('>>> [AuthLink] Firebase sign-in notice: ${signInErr.code} - ${signInErr.message}');
          // If user doesn't exist, create it in Firebase Auth
          if (signInErr.code == 'user-not-found' ||
              signInErr.code == 'invalid-credential' ||
              signInErr.code == 'wrong-password') {
            try {
              debugPrint('>>> [AuthLink] Creating user $cleanEmail in Firebase Auth...');
              final cred = await auth.createUserWithEmailAndPassword(
                email: cleanEmail,
                password: cleanPassword,
              );
              user = cred.user;
              await user?.updateDisplayName('لافي');
              debugPrint('>>> [AuthLink] Firebase user created successfully: ${user?.uid}');
            } on FirebaseAuthException catch (createErr) {
              debugPrint('>>> [AuthLink] Firebase create user error: ${createErr.code}');
              if (createErr.code == 'email-already-in-use') {
                try {
                  final cred = await auth.signInWithEmailAndPassword(
                    email: cleanEmail,
                    password: cleanPassword,
                  );
                  user = cred.user;
                } catch (_) {}
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('>>> [AuthLink] Firebase Auth handling: $e');
    }

    // 5. Trigger cloud backup sync
    try {
      FirebaseBackupService.instance.scheduleAutoBackup(debounce: const Duration(seconds: 2));
    } catch (_) {}

    return user;
  }

  /// Updates the user's password both in Secure Storage and Firebase Auth
  static Future<Map<String, dynamic>> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final cleanCurrent = currentPassword.trim();
    final cleanNew = newPassword.trim();

    if (cleanNew.length < 6) {
      return {'success': false, 'error': 'كلمة المرور الجديدة يجب أن تكون 6 خانات على الأقل'};
    }

    // 1. Verify current password
    final savedPw = await _storage.read(key: _keyPassword);
    if (savedPw == null || cleanCurrent != savedPw) {
      return {'success': false, 'error': 'كلمة المرور الحالية غير صحيحة'};
    }

    // 2. Update Firebase Auth if logged in
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser != null) {
      try {
        final email = fbUser.email ?? await getLinkedEmail();
        final cred = EmailAuthProvider.credential(email: email, password: cleanCurrent);
        await fbUser.reauthenticateWithCredential(cred);
        await fbUser.updatePassword(cleanNew);
        debugPrint('>>> [AuthLink] Firebase password updated successfully');
      } on FirebaseAuthException catch (e) {
        debugPrint('>>> [AuthLink] Firebase updatePassword error: ${e.code} - ${e.message}');
        if (e.code == 'requires-recent-login') {
          try {
            final email = fbUser.email ?? await getLinkedEmail();
            await fbUser.reauthenticateWithCredential(
              EmailAuthProvider.credential(email: email, password: cleanCurrent),
            );
            await fbUser.updatePassword(cleanNew);
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('>>> [AuthLink] Update password error: $e');
      }
    }

    // 3. Update local Secure Storage
    try {
      await _storage.write(key: _keyPassword, value: cleanNew);
    } catch (_) {}

    return {'success': true, 'message': 'تم تغيير كلمة المرور بنجاح'};
  }

  /// Sends password reset email
  static Future<bool> sendPasswordResetEmail([String? targetEmail]) async {
    try {
      final email = targetEmail?.trim() ?? await getLinkedEmail();
      if (email.isNotEmpty) {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        return true;
      }
    } catch (e) {
      debugPrint('>>> [AuthLink] sendPasswordResetEmail error: $e');
    }
    return false;
  }
}
