import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  static const String _loggerName = 'UserService';

  static String _userId = '';
  static bool _isInitialized = false;
  static DateTime? _lastUpdated;

  // Inicializuoti UserService su Firebase Auth
  static Future<void> initialize() async {
    if (_isInitialized) {
      developer.log('ℹ️ UserService jau inicializuotas', name: _loggerName);
      return;
    }

    try {
      // Bandyti gauti Firebase Auth vartotoją
      final firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser != null) {
        _userId = firebaseUser.uid;
        developer.log(
          '✅ Naudojamas Firebase Auth userId: $_userId',
          name: _loggerName,
        );
      } else {
        // Jei nėra Firebase Auth vartotojo, sukurti anoniminį
        developer.log(
          '🔐 Nėra Firebase vartotojo, kuriamas anonimas...',
          name: _loggerName,
        );

        final userCredential = await FirebaseAuth.instance.signInAnonymously();
        _userId = userCredential.user?.uid ?? _generateDefaultUserId();

        developer.log(
          '✅ Sukurtas anoniminis vartotojas: $_userId',
          name: _loggerName,
        );
      }

      _isInitialized = true;
      _lastUpdated = DateTime.now();

      developer.log('🚀 UserService inicializuotas', name: _loggerName);
      developer.log('👤 UserId: $_userId', name: _loggerName);
    } catch (e) {
      developer.log(
        '❌ Klaida inicializuojant UserService: $e',
        name: _loggerName,
        level: 1000,
      );
      _userId = _generateDefaultUserId();
      _isInitialized = true;
    }
  }

  // Nustatyti userId
  static void setUserId(String userId) {
    final trimmedUserId = userId.trim();

    if (trimmedUserId.isEmpty) {
      developer.log(
        '⚠️ Bandymas nustatyti tuščią userId',
        name: _loggerName,
        level: 900,
      );
      return;
    }

    final previousUserId = _userId;
    _userId = trimmedUserId;
    _lastUpdated = DateTime.now();
    _isInitialized = true;

    developer.log('✅ UserId sėkmingai nustatytas', name: _loggerName);
    developer.log('📝 Senas: $previousUserId', name: _loggerName);
    developer.log('📝 Naujas: $_userId', name: _loggerName);
    developer.log('🕐 Atnaujinimo laikas: $_lastUpdated', name: _loggerName);

    _logUserIdInfo();
  }

  // user_service.dart - get userId
  static String get userId {
    if (!_isInitialized) {
      developer.log(
        '⚠️ UserService neinicializuotas, inicializuojama...',
        name: _loggerName,
        level: 900,
      );

      // 🔥 SVARBU: Inicializuoti su Firebase Auth
      try {
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          _userId = firebaseUser.uid;
        } else {
          // Sukurti naują anonimų vartotoją
          _initializeWithFirebase();
        }
      } catch (e) {
        _userId = _generateDefaultUserId();
      }

      _isInitialized = true;
    }

    if (_userId.isEmpty) {
      developer.log(
        '⚠️ userId tuščias, generuojamas default',
        name: _loggerName,
        level: 900,
      );
      _userId = _generateDefaultUserId();
    }

    return _userId;
  }

  // 🔥 NAUJAS: Inicializuoti su Firebase
  static Future<void> _initializeWithFirebase() async {
    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      _userId = userCredential.user?.uid ?? _generateDefaultUserId();
      developer.log('✅ Firebase Auth userId: $_userId', name: _loggerName);
    } catch (e) {
      _userId = _generateDefaultUserId();
      developer.log(
        '⚠️ Firebase Auth klaida, naudojamas default: $_userId',
        name: _loggerName,
        level: 900,
      );
    }
  }

  // Patikrinti ar userId nustatytas
  static bool get isUserIdSet {
    final isSet = _userId.isNotEmpty && _isInitialized;
    developer.log(
      _userId.isEmpty
          ? '❌ userId nėra nustatytas'
          : '✅ userId nustatytas: $_userId',
      name: _loggerName,
    );
    return isSet;
  }

  // Gauti vartotojo informaciją
  static Map<String, dynamic> getUserInfo() {
    return {
      'userId': _userId,
      'isInitialized': _isInitialized,
      'lastUpdated': _lastUpdated?.toIso8601String(),
      'userIdLength': _userId.length,
      'isDefault': _userId.startsWith('default_user_'),
    };
  }

  // Išvalyti userId (logout)
  static void clearUserId() {
    final oldUserId = _userId;
    _userId = '';
    _lastUpdated = DateTime.now();

    developer.log('🧹 UserId išvalytas', name: _loggerName);
    developer.log('📝 Senas userId: $oldUserId', name: _loggerName);
    developer.log('🕐 Valymo laikas: $_lastUpdated', name: _loggerName);
  }

  // Sugeneruoti numatytąjį userId
  static String _generateDefaultUserId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = timestamp % 10000;
    final defaultId = 'default_user_${timestamp}_$random';

    developer.log(
      '🔧 Sugeneruotas numatytasis userId: $defaultId',
      name: _loggerName,
    );
    return defaultId;
  }

  // Patikrinti userId formatą
  static bool validateUserId(String userId) {
    final trimmed = userId.trim();

    if (trimmed.isEmpty) {
      developer.log(
        '❌ userId negali būti tuščias',
        name: _loggerName,
        level: 900,
      );
      return false;
    }

    if (trimmed.length < 3) {
      developer.log(
        '❌ userId per trumpas (min 3 simboliai)',
        name: _loggerName,
        level: 900,
      );
      return false;
    }

    if (trimmed.length > 50) {
      developer.log(
        '❌ userId per ilgas (max 50 simbolių)',
        name: _loggerName,
        level: 900,
      );
      return false;
    }

    // Patikrinti ar yra neleistinų simbolių
    final regex = RegExp(r'^[a-zA-Z0-9_.-]+$');
    if (!regex.hasMatch(trimmed)) {
      developer.log(
        '❌ userId turi neleistinų simbolių',
        name: _loggerName,
        level: 900,
      );
      return false;
    }

    developer.log('✅ userId formatas tinkamas: $trimmed', name: _loggerName);
    return true;
  }

  // Gauti sutrumpintą userId (naudojimui loguose)
  static String get shortUserId {
    if (_userId.length <= 10) return _userId;
    return '${_userId.substring(0, 8)}...';
  }

  // Išspausdinti userId informaciją
  static void _logUserIdInfo() {
    developer.log('📋 UserId informacija:', name: _loggerName);
    developer.log('• userId: $_userId', name: _loggerName);
    developer.log('• ilgis: ${_userId.length}', name: _loggerName);
    developer.log('• inicializuotas: $_isInitialized', name: _loggerName);
    developer.log(
      '• paskutinis atnaujinimas: $_lastUpdated',
      name: _loggerName,
    );
    developer.log('• sutrumpintas: $shortUserId', name: _loggerName);
    developer.log(
      '• numatytasis: ${_userId.startsWith('default_user_')}',
      name: _loggerName,
    );
  }

  // Pakeisti userId (su patikrinimu)
  static Future<bool> changeUserId(String newUserId) async {
    developer.log('🔄 Bandoma pakeisti userId...', name: _loggerName);

    if (!validateUserId(newUserId)) {
      developer.log(
        '❌ Naujas userId netinkamas',
        name: _loggerName,
        level: 900,
      );
      return false;
    }

    final oldUserId = _userId;
    setUserId(newUserId);

    developer.log(
      '✅ userId pakeistas iš "$oldUserId" į "$newUserId"',
      name: _loggerName,
    );
    return true;
  }

  // Reset UserService (testavimui)
  static void reset() {
    developer.log('🔄 Resetinamas UserService...', name: _loggerName);
    clearUserId();
    _isInitialized = false;
    developer.log('✅ UserService resetintas', name: _loggerName);
  }
}
