import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/message_service.dart';
import '../services/couple_service.dart';
import 'dart:developer' as developer;
import '../services/firebase_service.dart';

class CustomMessages {
  static const String _key = 'custom_messages';
  static const String _loggerName = 'CustomMessages';

  // Išsaugo custom tekstą tam tikrai dienai
  static Future<void> saveCustomMessage(int dayOfYear, String message) async {
    try {
      // 🔥 PATIKRINTI AR GALIMA RAŠYTI
      final canWrite = await MessageService.canUserWriteMessages();
      if (!canWrite) {
        developer.log(
          '❌ Vartotojas neturi teisių rašyti žinučių',
          name: _loggerName,
          level: 900,
        );
        throw Exception(
          'Neturite teisių rašyti žinučių. Tik rašytojas gali rašyti.',
        );
      }

      final prefs = await SharedPreferences.getInstance();

      // Gauname esamus custom tekstus
      Map<String, String> customMessages = await getAllCustomMessages();

      // Pridedame/atnaujiname
      customMessages[dayOfYear.toString()] = message;

      // Išsaugome
      await prefs.setString(_key, json.encode(customMessages));

      developer.log(
        '✅ Custom žinutė išsaugota vietinėje duomenų bazėje',
        name: _loggerName,
      );

      // 🔥 AUTOMATIŠKAI IŠSAUGOME Į FIREBASE
      await _syncWithFirebase(dayOfYear, message);
    } catch (e) {
      developer.log(
        '❌ Klaida išsaugant žinutę: $e',
        name: _loggerName,
        level: 1000,
      );
      rethrow;
    }
  }

  // Sinchronizacija su Firebase
  static Future<void> _syncWithFirebase(int dayOfYear, String message) async {
    try {
      final cloudResult = await MessageService.saveMessageToCloud(
        dayOfYear,
        message,
      );

      if (cloudResult['success'] == true) {
        developer.log(
          '✅ Žinutė sėkmingai sinchronizuota su Firebase',
          name: _loggerName,
        );
      } else {
        developer.log(
          '⚠️ Nepavyko sinchronizuoti su Firebase: ${cloudResult['error']}',
          name: _loggerName,
          level: 900,
        );
      }
    } catch (e) {
      developer.log(
        '⚠️ Klaida sinchronizuojant su Firebase: $e',
        name: _loggerName,
        level: 900,
      );
      // Neprarodome klaidos, nes vietinis išsaugojimas jau pavyko
    }
  }

  // Gauna custom tekstą tam tikrai dienai (jei yra)
  static Future<String?> getCustomMessage(int dayOfYear) async {
    try {
      Map<String, String> customMessages = await getAllCustomMessages();
      final message = customMessages[dayOfYear.toString()];

      if (message != null) {
        developer.log(
          '📖 Rasta custom žinutė dienai $dayOfYear',
          name: _loggerName,
        );
      }

      return message;
    } catch (e) {
      developer.log(
        '❌ Klaida gaunant custom žinutę: $e',
        name: _loggerName,
        level: 1000,
      );
      return null;
    }
  }

  // Gauna visus custom tekstus
  static Future<Map<String, String>> getAllCustomMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? data = prefs.getString(_key);

      if (data == null) {
        developer.log('📁 Custom žinučių nėra', name: _loggerName);
        return {};
      }

      Map<String, dynamic> decoded = json.decode(data);
      final result = decoded.map(
        (key, value) => MapEntry(key, value.toString()),
      );

      developer.log(
        '📊 Rasta ${result.length} custom žinučių',
        name: _loggerName,
      );

      return result;
    } catch (e) {
      developer.log(
        '❌ Klaida dekoduojant custom žinutes: $e',
        name: _loggerName,
        level: 1000,
      );
      return {};
    }
  }

  // Ištrina custom tekstą
  static Future<void> deleteCustomMessage(int dayOfYear) async {
    try {
      // 🔥 PATIKRINTI AR GALIMA TRINTI
      final canDelete = await MessageService.canUserDeleteMessages();
      if (!canDelete) {
        developer.log(
          '❌ Vartotojas neturi teisių trinti žinučių',
          name: _loggerName,
          level: 900,
        );
        throw Exception(
          'Neturite teisių trinti žinučių. Tik rašytojas gali trinti.',
        );
      }

      final prefs = await SharedPreferences.getInstance();
      Map<String, String> customMessages = await getAllCustomMessages();

      final hadMessage = customMessages.containsKey(dayOfYear.toString());
      customMessages.remove(dayOfYear.toString());

      await prefs.setString(_key, json.encode(customMessages));

      if (hadMessage) {
        developer.log(
          '🗑️ Ištrinta custom žinutė dienai $dayOfYear',
          name: _loggerName,
        );

        // 🔥 IŠTRINTI IŠ FIREBASE JEI YRA
        await _deleteFromFirebase(dayOfYear);
      }
    } catch (e) {
      developer.log(
        '❌ Klaida trinant žinutę: $e',
        name: _loggerName,
        level: 1000,
      );
      rethrow;
    }
  }

  // Ištrinti iš Firebase
  static Future<void> _deleteFromFirebase(int dayOfYear) async {
    try {
      // Gauti dabartinę porą
      final couple = await CoupleService.getCurrentCouple();
      if (couple == null) {
        developer.log(
          'ℹ️ Poros nerasta, negalima trinti iš Firebase',
          name: _loggerName,
        );
        return;
      }

      final coupleId = couple['id'] as String?;
      if (coupleId == null || coupleId.isEmpty) {
        developer.log('ℹ️ Netinkamas coupleId', name: _loggerName);
        return;
      }

      // Rasti žinutę dienai
      final query = await FirebaseService.messagesCollection
          .where('coupleId', isEqualTo: coupleId)
          .where('dayOfYear', isEqualTo: dayOfYear)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.delete();
        developer.log(
          '✅ Žinutė ištrinta iš Firebase dienai $dayOfYear',
          name: _loggerName,
        );
      } else {
        developer.log(
          'ℹ️ Firebase žinutės nerasta dienai $dayOfYear',
          name: _loggerName,
        );
      }
    } catch (e) {
      developer.log(
        '⚠️ Klaida trinant iš Firebase: $e',
        name: _loggerName,
        level: 900,
      );
      // Neprarodome klaidos, nes vietinis trynimas jau pavyko
    }
  }

  // Gauna tekstą dienai (custom arba default)
  static Future<String> getMessageForDay(
    int dayOfYear,
    String defaultMessage,
  ) async {
    try {
      String? customMsg = await getCustomMessage(dayOfYear);
      final result = customMsg ?? defaultMessage;

      developer.log(
        '📝 Grąžinta ${customMsg != null ? 'custom' : 'default'} žinutė dienai $dayOfYear',
        name: _loggerName,
      );

      return result;
    } catch (e) {
      developer.log(
        '❌ Klaida gaunant žinutę dienai: $e',
        name: _loggerName,
        level: 1000,
      );
      return defaultMessage;
    }
  }

  // 🔥 NAUJAS: Patikrinti ar vartotojas turi rašymo teises
  static Future<bool> canUserWriteMessages() async {
    return await MessageService.canUserWriteMessages();
  }

  // 🔥 NAUJAS: Patikrinti ar vartotojas turi trynimo teises
  static Future<bool> canUserDeleteMessages() async {
    return await MessageService.canUserDeleteMessages();
  }
}
