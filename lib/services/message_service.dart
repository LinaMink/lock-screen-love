import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import 'firebase_service.dart';
import 'user_service.dart';
import 'couple_service.dart'; // 🔥 PRIDĖTA

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

      // 🔥 PATIKRINTI PERMISSIONS
      final hasWritePermission = await CoupleService.hasPermission('write');
      if (!hasWritePermission) {
        developer.log(
          '❌ Vartotojas neturi teisių rašyti žinučių',
          name: _loggerName,
          level: 900,
        );
        return {
          'success': false,
          'error': 'Neturite teisių rašyti žinutes. Tik rašytojas gali rašyti.',
        };
      }

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

      // ✅ NAUJA TERMINOLOGIJA
      final creatorName =
          coupleData['creatorName'] as String? ??
          coupleData['wifeName'] as String? ??
          'Nenurodyta';
      final relationshipType =
          coupleData['relationshipType'] as String? ?? 'romantic';

      developer.log(
        '✅ Rasta pora: $creatorName (ID: $coupleId)',
        name: _loggerName,
      );
      developer.log('🤝 Ryšio tipas: $relationshipType', name: _loggerName);

      // Patikrinti ar jau yra žinutė šiai dienai
      final existingMessage = await _getExistingMessageForDay(
        coupleId,
        dayOfYear,
      );
      if (existingMessage != null) {
        developer.log(
          '⚠️ Jau yra žinutė šiai dienai, atnaujinama...',
          name: _loggerName,
          level: 900,
        );

        // Atnaujinti esamą žinutę
        await existingMessage.reference.update({
          'message': message,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': userId,
        });

        developer.log('✅ Esama žinutė atnaujinta', name: _loggerName);
      } else {
        // Sukurti naują žinutę
        developer.log(
          '💾 Išsaugome naują žinutę į Firebase...',
          name: _loggerName,
        );
        await FirebaseService.messagesCollection.add({
          'coupleId': coupleId,
          'dayOfYear': dayOfYear,
          'message': message,
          // ✅ NAUJI LAUKAI
          'creatorName': creatorName,
          'relationshipType': relationshipType,
          // ❌ SENI LAUKAI (atgaliniam sutartimumui)
          'wifeName': creatorName,

          'createdBy': userId,
          'createdAt': DateTime.now().toIso8601String(),
          'timestamp': FieldValue.serverTimestamp(),
        });

        developer.log('✅ Nauja žinutė sėkmingai išsaugota!', name: _loggerName);
      }

      developer.log(
        '📊 Išsaugota porai: $creatorName, dienai: $dayOfYear',
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

  // Patikrinti ar jau yra žinutė šiai dienai
  static Future<QueryDocumentSnapshot?> _getExistingMessageForDay(
    String coupleId,
    int dayOfYear,
  ) async {
    try {
      final query = await FirebaseService.messagesCollection
          .where('coupleId', isEqualTo: coupleId)
          .where('dayOfYear', isEqualTo: dayOfYear)
          .limit(1)
          .get();

      return query.docs.isNotEmpty ? query.docs.first : null;
    } catch (e) {
      developer.log(
        '⚠️ Klaida tikrinant esamą žinutę: $e',
        name: _loggerName,
        level: 900,
      );
      return null;
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

        // ✅ NAUJA TERMINOLOGIJA
        final creatorName =
            messageData['creatorName'] as String? ??
            messageData['wifeName'] as String? ??
            'Nenurodyta';

        developer.log('✅ Rasta žinutė dienai $dayOfYear', name: _loggerName);
        return {
          'success': true,
          'message': messageData['message'] as String? ?? '',
          'creatorName': creatorName,
          'relationshipType':
              messageData['relationshipType'] as String? ?? 'romantic',
          // ❌ SENI LAUKAI (atgaliniam sutartimumui)
          'wifeName': creatorName,
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

  // 🔥 IŠTRINTI ŽINUTĘ (su permission check)
  static Future<Map<String, dynamic>> deleteMessage(String messageId) async {
    try {
      developer.log('🗑️ Trinama žinutė ID: $messageId', name: _loggerName);

      // 🔥 PATIKRINTI PERMISSIONS
      final hasDeletePermission = await CoupleService.hasPermission('delete');
      if (!hasDeletePermission) {
        developer.log(
          '❌ Vartotojas neturi teisių trinti žinučių',
          name: _loggerName,
          level: 900,
        );
        return {
          'success': false,
          'error': 'Neturite teisių trinti žinučių. Tik rašytojas gali trinti.',
        };
      }

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

  // 🔥 GAUTI ŽINUČIŲ ISTORIJĄ
  static Future<List<Map<String, dynamic>>> getMessageHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      developer.log('📜 Gaunama žinučių istorija...', name: _loggerName);

      final userId = UserService.userId;
      final coupleId = await _getCoupleIdForUser(userId);

      if (coupleId == null) {
        return [];
      }

      final query = await FirebaseService.messagesCollection
          .where('coupleId', isEqualTo: coupleId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      final messages = query.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final creatorName =
            data['creatorName'] as String? ??
            data['wifeName'] as String? ??
            'Nenurodyta';

        return {
          'id': doc.id,
          'message': data['message'] as String? ?? '',
          'dayOfYear': data['dayOfYear'] as int? ?? 0,
          'creatorName': creatorName,
          'relationshipType': data['relationshipType'] as String? ?? 'romantic',
          'timestamp': data['timestamp'],
          'createdAt': data['createdAt'],
        };
      }).toList();

      developer.log('📊 Rasta ${messages.length} žinučių', name: _loggerName);
      return messages;
    } catch (e) {
      developer.log(
        '❌ Klaida gaunant žinučių istoriją: $e',
        name: _loggerName,
        level: 900,
      );
      return [];
    }
  }

  // 🔥 REDAGUOTI ŽINUTĘ (su permission check)
  static Future<Map<String, dynamic>> editMessage({
    required String messageId,
    required String newMessage,
  }) async {
    try {
      developer.log('✏️ Redaguojama žinutė ID: $messageId', name: _loggerName);

      // 🔥 PATIKRINTI PERMISSIONS
      final hasEditPermission = await CoupleService.hasPermission('edit');
      if (!hasEditPermission) {
        developer.log(
          '❌ Vartotojas neturi teisių redaguoti žinučių',
          name: _loggerName,
          level: 900,
        );
        return {
          'success': false,
          'error':
              'Neturite teisių redaguoti žinučių. Tik rašytojas gali redaguoti.',
        };
      }

      await FirebaseService.messagesCollection.doc(messageId).update({
        'message': newMessage,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': UserService.userId,
      });

      developer.log('✅ Žinutė sėkmingai redaguota', name: _loggerName);
      return {'success': true};
    } catch (e) {
      developer.log(
        '❌ Klaida redaguojant žinutę: $e',
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

  // 🔥 PATIKRINTI AR VARTOTOJAS GALI RAŠYTI
  static Future<bool> canUserWriteMessages() async {
    return await CoupleService.hasPermission('write');
  }

  // 🔥 PATIKRINTI AR VARTOTOJAS GALI TRINTI
  static Future<bool> canUserDeleteMessages() async {
    return await CoupleService.hasPermission('delete');
  }

  // 🔥 PATIKRINTI AR VARTOTOJAS GALI REDAGUOTI
  static Future<bool> canUserEditMessages() async {
    return await CoupleService.hasPermission('edit');
  }

  // 🔥 PATIKRINTI AR VARTOTOJAS YRA CREATOR
  static Future<bool> isUserCreator() async {
    try {
      final couple = await CoupleService.getCurrentCouple();
      if (couple == null) return false;

      final userRole = couple['userRole'] as String?;
      return userRole == 'creator';
    } catch (e) {
      developer.log(
        '❌ Klaida tikrinant rolę: $e',
        name: _loggerName,
        level: 900,
      );
      return false;
    }
  }

  // 🔥 GAUTI CREATOR NAME
  static Future<String> getCreatorName() async {
    try {
      final couple = await CoupleService.getCurrentCouple();
      if (couple == null) return 'Nenurodyta';

      return couple['creatorName'] as String? ?? 'Nenurodyta';
    } catch (e) {
      developer.log(
        '❌ Klaida gaunant creator name: $e',
        name: _loggerName,
        level: 900,
      );
      return 'Nenurodyta';
    }
  }

  // 🔥 GAUTI USER ROLE
  static Future<String> getUserRole() async {
    try {
      final couple = await CoupleService.getCurrentCouple();
      if (couple == null) return 'reader';

      return couple['userRole'] as String? ?? 'reader';
    } catch (e) {
      developer.log(
        '❌ Klaida gaunant user role: $e',
        name: _loggerName,
        level: 900,
      );
      return 'reader';
    }
  }
}
