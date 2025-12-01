import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/message_service.dart';
import 'dart:developer' as developer;

class CustomMessages {
  static const String _key = 'custom_messages';
  static const String _loggerName = 'CustomMessages';

  // Išsaugo custom tekstą tam tikrai dienai
  static Future<void> saveCustomMessage(int dayOfYear, String message) async {
    try {
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
      ); // ERROR level
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
        ); // WARNING level
      }
    } catch (e) {
      developer.log(
        '⚠️ Klaida sinchronizuojant su Firebase: $e',
        name: _loggerName,
        level: 900,
      ); // WARNING level
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
      return defaultMessage; // Grąžiname default žinutę net ir esant klaidai
    }
  }
}
