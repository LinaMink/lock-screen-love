import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import 'firebase_service.dart';
import 'user_service.dart';

class MessageService {
  static const String _loggerName = 'MessageService';

  // Išsaugoti žinutę į Cloud
  static Future<Map<String, dynamic>> saveMessageToCloud(
    int dayOfYear,
    String message,
  ) async {
    try {
      developer.log('🔄 Pradedame išsaugoti žinutę...', name: _loggerName);
      developer.log('📅 Diena: $dayOfYear', name: _loggerName);
      developer.log(
        '💌 Žinutė: "${_truncateMessage(message)}"',
        name: _loggerName,
      );

      // 🔥 NAUDOJAME USER SERVICE
      final userId = UserService.userId;
      developer.log('👤 Naudojamas userId: $userId', name: _loggerName);

      // Rasti porą kurioje yra vartotojas
      developer.log('🔍 Ieškome poros...', name: _loggerName);
      final coupleQuery = await FirebaseService.couplesCollection
          .where('members.userId', arrayContains: userId)
          .limit(1)
          .get();

      developer.log(
        '📊 Rasta porų: ${coupleQuery.docs.length}',
        name: _loggerName,
      );

      if (coupleQuery.docs.isEmpty) {
        developer.log('❌ Nerasta pora!', name: _loggerName, level: 900);
        return {
          'success': false,
          'error': 'Nerasta pora. Pirmiausia prisijunk prie poros!',
        };
      }

      final coupleDoc = coupleQuery.docs.first;
      final coupleId = coupleDoc.id;
      final coupleData = coupleDoc.data() as Map<String, dynamic>;
      final wifeName = coupleData['wifeName'] ?? 'Nenurodyta';

      developer.log(
        '✅ Rasta pora: $wifeName (ID: $coupleId)',
        name: _loggerName,
      );

      // Išsaugoti žinutę
      developer.log('💾 Išsaugome žinutę į Firebase...', name: _loggerName);
      await FirebaseService.messagesCollection.add({
        'coupleId': coupleId,
        'dayOfYear': dayOfYear,
        'message': message,
        'wifeName': wifeName,
        'createdBy': userId,
        'createdAt': DateTime.now().toIso8601String(),
        'timestamp': FieldValue.serverTimestamp(), // 🔥 GERESNIS LAIKAS
      });

      developer.log('✅ Žinutė sėkmingai išsaugota!', name: _loggerName);
      developer.log(
        '📊 Išsaugota porai: $wifeName, dienai: $dayOfYear',
        name: _loggerName,
      );

      return {'success': true};
    } catch (e) {
      developer.log(
        '❌ Klaida išsaugant žinutę: $e',
        name: _loggerName,
        level: 1000,
      );
      return {'success': false, 'error': e.toString()};
    }
  }

  // 🔥 GAUTI ŽINUČIŲ STREAM'Ą
  static Stream<QuerySnapshot> getMessagesStream() {
    developer.log('🎧 Sukuriamas žinučių stream', name: _loggerName);

    try {
      final userId = UserService.userId;

      if (userId.isEmpty) {
        developer.log(
          '⚠️ UserId tuščias, grąžinamas tuščias stream',
          name: _loggerName,
          level: 900,
        );
        return const Stream.empty();
      }

      // 🔥 GAUTI ŽINUTES KONKRECIAI PORAI
      return FirebaseService.messagesCollection
          .where('coupleId', isEqualTo: _getCoupleIdForUser(userId))
          .orderBy('timestamp', descending: true)
          .snapshots();
    } catch (e) {
      developer.log(
        '❌ Klaida gaunant stream: $e',
        name: _loggerName,
        level: 1000,
      );
      return const Stream.empty();
    }
  }

  // 🔥 PAGALBINĖ FUNKCIJA GAUTI POROS ID
  static Future<String?> _getCoupleIdForUser(String userId) async {
    try {
      final coupleQuery = await FirebaseService.couplesCollection
          .where('members.userId', arrayContains: userId)
          .limit(1)
          .get();

      if (coupleQuery.docs.isNotEmpty) {
        return coupleQuery.docs.first.id;
      }
      return null;
    } catch (e) {
      developer.log(
        '❌ Klaida gaunant poros ID: $e',
        name: _loggerName,
        level: 900,
      );
      return null;
    }
  }

  // 🔥 GAUTI ŽINUTES KONKRECIAI DIENAI
  static Future<Map<String, dynamic>> getMessageForDay(int dayOfYear) async {
    try {
      developer.log('🔍 Ieškome žinutės dienai: $dayOfYear', name: _loggerName);

      final userId = UserService.userId;
      final coupleId = await _getCoupleIdForUser(userId);

      if (coupleId == null) {
        developer.log(
          '❌ Nerasta pora vartotojui',
          name: _loggerName,
          level: 900,
        );
        return {'success': false, 'error': 'Nerasta pora'};
      }

      final messageQuery = await FirebaseService.messagesCollection
          .where('coupleId', isEqualTo: coupleId)
          .where('dayOfYear', isEqualTo: dayOfYear)
          .limit(1)
          .get();

      if (messageQuery.docs.isNotEmpty) {
        final messageData =
            messageQuery.docs.first.data() as Map<String, dynamic>;
        developer.log('✅ Rasta žinutė dienai $dayOfYear', name: _loggerName);
        return {
          'success': true,
          'message': messageData['message'],
          'wifeName': messageData['wifeName'],
        };
      }

      developer.log('ℹ️ Nerasta žinutės dienai $dayOfYear', name: _loggerName);
      return {'success': false, 'error': 'Žinutė nerasta'};
    } catch (e) {
      developer.log(
        '❌ Klaida gaunant žinutę dienai: $e',
        name: _loggerName,
        level: 1000,
      );
      return {'success': false, 'error': e.toString()};
    }
  }

  // 🔥 IŠTRINTI ŽINUTĘ
  static Future<Map<String, dynamic>> deleteMessage(String messageId) async {
    try {
      developer.log('🗑️ Trinama žinutė ID: $messageId', name: _loggerName);

      await FirebaseService.messagesCollection.doc(messageId).delete();

      developer.log('✅ Žinutė sėkmingai ištrinta', name: _loggerName);
      return {'success': true};
    } catch (e) {
      developer.log(
        '❌ Klaida trinant žinutę: $e',
        name: _loggerName,
        level: 1000,
      );
      return {'success': false, 'error': e.toString()};
    }
  }

  // 🔥 PAGALBINĖ FUNKCIJA ŽINUTĖMS TRUNKAVIMUI
  static String _truncateMessage(String message, [int length = 50]) {
    if (message.length <= length) {
      return message;
    }
    return '${message.substring(0, length)}...';
  }
}
