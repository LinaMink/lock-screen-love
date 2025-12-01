import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

class SessionService {
  static const String _loggerName = 'SessionService';

  // SharedPreferences keys
  static const String _keyCoupleId = 'session_couple_id';
  static const String _keyCoupleCode = 'session_couple_code';
  static const String _keyUserRole = 'session_user_role';
  static const String _keyCreatorName = 'session_creator_name';
  static const String _keyReaderCode = 'session_reader_code';
  static const String _keyLoggedInAt = 'session_logged_in_at';
  static const String _keyDeviceId = 'session_device_id';
  static const String _keyHasCompletedOnboarding =
      'session_onboarding_completed';

  // Išsaugoti sesijos informaciją
  static Future<void> saveSession({
    required String coupleId,
    required String coupleCode,
    required String userRole,
    required String creatorName,
    String? readerCode,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await Future.wait([
        prefs.setString(_keyCoupleId, coupleId),
        prefs.setString(_keyCoupleCode, coupleCode),
        prefs.setString(_keyUserRole, userRole),
        prefs.setString(_keyCreatorName, creatorName),
        if (readerCode != null) prefs.setString(_keyReaderCode, readerCode),
        prefs.setString(_keyLoggedInAt, DateTime.now().toIso8601String()),
      ]);

      developer.log('💾 Sesija išsaugota:', name: _loggerName);
      developer.log('   CoupleId: $coupleId', name: _loggerName);
      developer.log('   CoupleCode: $coupleCode', name: _loggerName);
      developer.log('   UserRole: $userRole', name: _loggerName);
      developer.log('   CreatorName: $creatorName', name: _loggerName);
    } catch (e) {
      developer.log(
        '❌ Klaida išsaugant sesiją: $e',
        name: _loggerName,
        level: 900,
      );
    }
  }

  // Gauti išsaugotą sesiją
  static Future<Map<String, String>?> getSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final coupleId = prefs.getString(_keyCoupleId);
      final coupleCode = prefs.getString(_keyCoupleCode);
      final userRole = prefs.getString(_keyUserRole);
      final creatorName = prefs.getString(_keyCreatorName);

      if (coupleId == null || coupleCode == null || userRole == null) {
        developer.log('ℹ️ Išsaugotos sesijos nėra', name: _loggerName);
        return null;
      }

      final session = {
        'coupleId': coupleId,
        'coupleCode': coupleCode,
        'userRole': userRole,
        'creatorName': creatorName ?? '',
        'readerCode': prefs.getString(_keyReaderCode) ?? '',
        'loggedInAt': prefs.getString(_keyLoggedInAt) ?? '',
      };

      developer.log('📖 Rasta išsaugota sesija:', name: _loggerName);
      developer.log('   CoupleId: $coupleId', name: _loggerName);
      developer.log('   UserRole: $userRole', name: _loggerName);

      return session;
    } catch (e) {
      developer.log(
        '❌ Klaida gaunant sesiją: $e',
        name: _loggerName,
        level: 900,
      );
      return null;
    }
  }

  // Patikrinti ar yra išsaugota sesija
  static Future<bool> hasSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final coupleId = prefs.getString(_keyCoupleId);
      final hasSession = coupleId != null && coupleId.isNotEmpty;

      developer.log(
        hasSession ? '✅ Yra išsaugota sesija' : 'ℹ️ Nėra išsaugotos sesijos',
        name: _loggerName,
      );

      return hasSession;
    } catch (e) {
      developer.log(
        '❌ Klaida tikrinant sesiją: $e',
        name: _loggerName,
        level: 900,
      );
      return false;
    }
  }

  // Išvalyti sesiją (logout)
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await Future.wait([
        prefs.remove(_keyCoupleId),
        prefs.remove(_keyCoupleCode),
        prefs.remove(_keyUserRole),
        prefs.remove(_keyCreatorName),
        prefs.remove(_keyReaderCode),
        prefs.remove(_keyLoggedInAt),
      ]);

      developer.log('🧹 Sesija išvalyta', name: _loggerName);
    } catch (e) {
      developer.log(
        '❌ Klaida valant sesiją: $e',
        name: _loggerName,
        level: 900,
      );
    }
  }

  // Išsaugoti onboarding būseną
  static Future<void> markOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHasCompletedOnboarding, true);
      developer.log('✅ Onboarding pažymėtas kaip baigtas', name: _loggerName);
    } catch (e) {
      developer.log(
        '❌ Klaida pažymint onboarding: $e',
        name: _loggerName,
        level: 900,
      );
    }
  }

  // Patikrinti ar onboarding baigtas
  static Future<bool> isOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool(_keyHasCompletedOnboarding) ?? false;

      developer.log(
        completed ? '✅ Onboarding jau baigtas' : 'ℹ️ Onboarding dar nebaigtas',
        name: _loggerName,
      );

      return completed;
    } catch (e) {
      developer.log(
        '❌ Klaida tikrinant onboarding: $e',
        name: _loggerName,
        level: 900,
      );
      return false;
    }
  }

  // Gauti sesijos informaciją
  static Future<Map<String, dynamic>> getSessionInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return {
        'hasSession': await hasSavedSession(),
        'coupleId': prefs.getString(_keyCoupleId),
        'userRole': prefs.getString(_keyUserRole),
        'creatorName': prefs.getString(_keyCreatorName),
        'loggedInAt': prefs.getString(_keyLoggedInAt),
        'onboardingCompleted': await isOnboardingCompleted(),
      };
    } catch (e) {
      developer.log(
        '❌ Klaida gaunant session info: $e',
        name: _loggerName,
        level: 900,
      );
      return {'hasSession': false};
    }
  }

  // Išsaugoti device ID
  static Future<void> saveDeviceId(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDeviceId, deviceId);
      developer.log('📱 Device ID išsaugotas: $deviceId', name: _loggerName);
    } catch (e) {
      developer.log(
        '❌ Klaida išsaugant device ID: $e',
        name: _loggerName,
        level: 900,
      );
    }
  }

  // Gauti device ID
  static Future<String?> getDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyDeviceId);
    } catch (e) {
      developer.log(
        '❌ Klaida gaunant device ID: $e',
        name: _loggerName,
        level: 900,
      );
      return null;
    }
  }

  // Generuoti unikalų device ID
  static Future<String> generateDeviceId() async {
    try {
      final existingId = await getDeviceId();
      if (existingId != null && existingId.isNotEmpty) {
        return existingId;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = timestamp % 1000000;
      final deviceId = 'device_${timestamp}_$random';

      await saveDeviceId(deviceId);
      developer.log('🔧 Sugeneruotas device ID: $deviceId', name: _loggerName);

      return deviceId;
    } catch (e) {
      developer.log(
        '❌ Klaida generuojant device ID: $e',
        name: _loggerName,
        level: 900,
      );
      return 'device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
}
