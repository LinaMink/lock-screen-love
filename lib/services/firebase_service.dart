import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

class FirebaseService {
  static bool _initialized = false;
  static const String _loggerName = 'FirebaseService';

  // Inicializuoti Firebase
  static Future<void> initialize() async {
    try {
      developer.log('🔄 Inicializuojamas Firebase...', name: _loggerName);
      await Firebase.initializeApp();
      _initialized = true;
      developer.log('✅ Firebase sėkmingai inicializuotas', name: _loggerName);

      // Patikrinti ar Firebase veikia
      await _testFirebaseConnection();
    } catch (e) {
      developer.log(
        '❌ Firebase inicializavimo klaida: $e',
        name: _loggerName,
        level: 1000,
      );
      rethrow; // Leidžiame klaidai plisti toliau
    }
  }

  // Testuoti Firebase ryšį
  static Future<void> _testFirebaseConnection() async {
    try {
      developer.log('🔗 Testuojamas Firebase ryšys...', name: _loggerName);

      // Patikrinti ar Firestore veikia
      await firestore.collection('test').limit(1).get();
      developer.log('✅ Firestore veikia', name: _loggerName);

      // Patikrinti ar Auth veikia
      final authInstance = auth;
      developer.log('✅ Auth veikia', name: _loggerName);
      developer.log('📱 Auth app: ${authInstance.app.name}', name: _loggerName);
    } catch (e) {
      developer.log(
        '⚠️ Firebase ryšio testavimo klaida: $e',
        name: _loggerName,
        level: 900,
      );
    }
  }

  // Anonymous login
  static Future<UserCredential?> signInAnonymously() async {
    if (!_initialized) {
      developer.log(
        '❌ Firebase neinicializuotas anoniminiam prisijungimui',
        name: _loggerName,
        level: 1000,
      );
      return null;
    }

    try {
      developer.log(
        '👤 Pradedamas anonominis prisijungimas...',
        name: _loggerName,
      );
      final result = await FirebaseAuth.instance.signInAnonymously();

      developer.log('✅ Anonominis prisijungimas sėkmingas', name: _loggerName);
      developer.log('🆔 User ID: ${result.user?.uid}', name: _loggerName);
      developer.log('📧 Email: ${result.user?.email}', name: _loggerName);
      developer.log(
        '🔐 Anonymous: ${result.user?.isAnonymous}',
        name: _loggerName,
      );
      developer.log(
        '🕐 Created: ${result.user?.metadata.creationTime}',
        name: _loggerName,
      );

      return result;
    } catch (e) {
      developer.log(
        '❌ Anonominio prisijungimo klaida: $e',
        name: _loggerName,
        level: 1000,
      );

      if (e is FirebaseAuthException) {
        developer.log(
          '❌ Auth klaidos kodas: ${e.code}',
          name: _loggerName,
          level: 1000,
        );
        developer.log(
          '❌ Auth klaidos žinutė: ${e.message}',
          name: _loggerName,
          level: 1000,
        );
      }

      return null;
    }
  }

  // Gauti Firestore instance
  static FirebaseFirestore get firestore {
    if (!_initialized) {
      developer.log(
        '❌ Firebase neinicializuotas, negalima gauti Firestore',
        name: _loggerName,
        level: 1000,
      );
      throw Exception(
        'Firebase not initialized. Call FirebaseService.initialize() first.',
      );
    }

    try {
      final instance = FirebaseFirestore.instance;
      developer.log('📊 Firestore instance gautas', name: _loggerName);
      developer.log('📁 App: ${instance.app.name}', name: _loggerName);
      return instance;
    } catch (e) {
      developer.log(
        '❌ Klaida gaunant Firestore instance: $e',
        name: _loggerName,
        level: 1000,
      );
      rethrow;
    }
  }

  // Gauti Auth instance
  static FirebaseAuth get auth {
    if (!_initialized) {
      developer.log(
        '❌ Firebase neinicializuotas, negalima gauti Auth',
        name: _loggerName,
        level: 1000,
      );
      throw Exception(
        'Firebase not initialized. Call FirebaseService.initialize() first.',
      );
    }

    try {
      final instance = FirebaseAuth.instance;
      developer.log('🔐 Auth instance gautas', name: _loggerName);
      developer.log(
        '👥 Current user: ${instance.currentUser?.uid ?? "none"}',
        name: _loggerName,
      );
      return instance;
    } catch (e) {
      developer.log(
        '❌ Klaida gaunant Auth instance: $e',
        name: _loggerName,
        level: 1000,
      );
      rethrow;
    }
  }

  // Gauti current user
  static User? get currentUser {
    if (!_initialized) {
      developer.log(
        '⚠️ Firebase neinicializuotas, negalima gauti current user',
        name: _loggerName,
        level: 900,
      );
      return null;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        developer.log('👤 Current user rastas: ${user.uid}', name: _loggerName);
      } else {
        developer.log('👤 Current user nerastas', name: _loggerName);
      }
      return user;
    } catch (e) {
      developer.log(
        '❌ Klaida gaunant current user: $e',
        name: _loggerName,
        level: 900,
      );
      return null;
    }
  }

  // Firestore kolekcijos
  static CollectionReference get couplesCollection {
    developer.log('👫 Gaunama couples kolekcija', name: _loggerName);
    return firestore.collection('couples');
  }

  static CollectionReference get messagesCollection {
    developer.log('💌 Gaunama messages kolekcija', name: _loggerName);
    return firestore.collection('messages');
  }

  // Patikrinti ar Firebase inicializuotas
  static bool get isInitialized {
    developer.log(
      _initialized
          ? '✅ Firebase inicializuotas'
          : '⚠️ Firebase neinicializuotas',
      name: _loggerName,
    );
    return _initialized;
  }

  // Išloginti vartotoją
  static Future<void> signOut() async {
    try {
      developer.log(
        '🚪 Pradedamas vartotojo išloginimas...',
        name: _loggerName,
      );
      await FirebaseAuth.instance.signOut();
      developer.log('✅ Vartotojas sėkmingai išlogintas', name: _loggerName);
    } catch (e) {
      developer.log(
        '❌ Klaida išloginant vartotoją: $e',
        name: _loggerName,
        level: 900,
      );
    }
  }

  // Gauti konfigūracijos informaciją
  static void logConfiguration() {
    developer.log('📋 Firebase konfigūracija:', name: _loggerName);
    developer.log('• Inicializuotas: $_initialized', name: _loggerName);
    developer.log(
      '• Current user ID: ${currentUser?.uid ?? "none"}',
      name: _loggerName,
    );
    developer.log('• App name: ${auth.app.name}', name: _loggerName);
    developer.log('• Firestore app: ${firestore.app.name}', name: _loggerName);
  }
}
