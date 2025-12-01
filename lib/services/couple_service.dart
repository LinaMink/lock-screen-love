import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';
import 'firebase_service.dart';
import 'dart:developer' as developer;

class CoupleService {
  static const String _loggerName = 'CoupleService';

  // Sukurti naują porą
  static Future<Map<String, dynamic>> createCouple(String wifeName) async {
    try {
      developer.log('👰 Kuriama nauja pora...', name: _loggerName);
      developer.log('👩 Žmonos vardas: $wifeName', name: _loggerName);

      final coupleId = DateTime.now().millisecondsSinceEpoch.toString();
      final wifeCode = _generateCode(wifeName, 'W');
      final husbandCode = _generateCode(wifeName, 'H');

      developer.log('🆔 Poros ID: $coupleId', name: _loggerName);
      developer.log('🔐 Žmonos kodas: $wifeCode', name: _loggerName);
      developer.log('🔑 Vyro kodas: $husbandCode', name: _loggerName);

      // Gauti vartotojo ID
      final userId = UserService.userId;
      if (userId.isEmpty) {
        developer.log(
          '❌ Tuščias userId, negalima sukurti poros',
          name: _loggerName,
          level: 1000,
        );
        return {'success': false, 'error': 'Nėra vartotojo ID'};
      }

      developer.log('👤 Vartotojo ID: $userId', name: _loggerName);

      // Sukurti porą Firestore
      developer.log('💾 Išsaugoma pora į Firebase...', name: _loggerName);

      await FirebaseService.couplesCollection.doc(coupleId).set({
        'wifeName': wifeName,
        'wifeCode': wifeCode,
        'husbandCode': husbandCode,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'members': [
          {
            'userId': userId,
            'role': 'wife',
            'joinedAt': FieldValue.serverTimestamp(),
            'name': wifeName,
          },
        ],
        'active': true,
      });

      developer.log('✅ Porą sėkmingai sukurta!', name: _loggerName);

      return {
        'success': true,
        'coupleId': coupleId,
        'wifeCode': wifeCode,
        'husbandCode': husbandCode,
        'wifeName': wifeName,
      };
    } catch (e) {
      developer.log(
        '❌ Klaida kuriant porą: $e',
        name: _loggerName,
        level: 1000,
      );
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Prisijungti prie poros su kodu
  static Future<Map<String, dynamic>> joinCouple(String code) async {
    try {
      developer.log('🔗 Bandoma prisijungti prie poros...', name: _loggerName);
      developer.log('🔑 Įvestas kodas: $code', name: _loggerName);

      // 🔥 NAUDOJAME USER SERVICE
      final userId = UserService.userId;
      if (userId.isEmpty) {
        developer.log(
          '❌ Tuščias userId, negalima prisijungti prie poros',
          name: _loggerName,
          level: 1000,
        );
        return {'success': false, 'error': 'Nėra vartotojo ID'};
      }

      developer.log('👤 Vartotojo ID: $userId', name: _loggerName);

      // Ieškoti poros pagal žmonos kodą
      developer.log('🔍 Ieškoma poros pagal kodą...', name: _loggerName);

      var query = await FirebaseService.couplesCollection
          .where('wifeCode', isEqualTo: code.trim())
          .limit(1)
          .get();

      String role = 'wife';
      String roleDisplay = 'žmona';

      if (query.docs.isEmpty) {
        developer.log(
          '⚠️ Žmonos kodu nerasta, tikrinama vyro kodą...',
          name: _loggerName,
          level: 900,
        );

        query = await FirebaseService.couplesCollection
            .where('husbandCode', isEqualTo: code.trim())
            .limit(1)
            .get();
        role = 'husband';
        roleDisplay = 'vyras';
      }

      developer.log('📊 Rasta porų: ${query.docs.length}', name: _loggerName);

      if (query.docs.isEmpty) {
        developer.log('❌ Neteisingas kodas', name: _loggerName, level: 900);
        return {'success': false, 'error': 'Neteisingas kodas'};
      }

      final coupleDoc = query.docs.first;
      final coupleId = coupleDoc.id;
      final data = coupleDoc.data() as Map<String, dynamic>? ?? {};
      final wifeName = data['wifeName'] as String? ?? 'Nenurodyta';
      final members = data['members'] as List<dynamic>? ?? [];

      developer.log('✅ Rasta pora: $wifeName', name: _loggerName);
      developer.log('🆔 Poros ID: $coupleId', name: _loggerName);
      developer.log('🎭 Rolė: $roleDisplay', name: _loggerName);

      // Patikrinti ar vartotojas jau yra poroje
      final alreadyMember = members.any(
        (member) =>
            member is Map<String, dynamic> && member['userId'] == userId,
      );

      if (alreadyMember) {
        developer.log('ℹ️ Vartotojas jau yra šioje poroje', name: _loggerName);
      } else {
        // Pridėti vartotoją į porą
        developer.log('👥 Pridedamas vartotojas į porą...', name: _loggerName);

        await FirebaseService.couplesCollection.doc(coupleId).update({
          'members': FieldValue.arrayUnion([
            {
              'userId': userId,
              'role': role,
              'joinedAt': FieldValue.serverTimestamp(),
              'name': role == 'wife' ? wifeName : 'Vyras',
            },
          ]),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        developer.log(
          '✅ Vartotojas sėkmingai pridėtas į porą',
          name: _loggerName,
        );
      }

      developer.log('🎉 Sėkmingai prisijungta prie poros!', name: _loggerName);

      return {
        'success': true,
        'coupleId': coupleId,
        'role': role,
        'roleDisplay': roleDisplay,
        'wifeName': wifeName,
        'message':
            'Sėkmingai prisijungei kaip $roleDisplay prie poros "$wifeName"',
      };
    } catch (e) {
      developer.log(
        '❌ Klaida prisijungiant prie poros: $e',
        name: _loggerName,
        level: 1000,
      );
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Gauti poros informaciją pagal vartotojo ID
  static Future<Map<String, dynamic>?> getCoupleByUserId(String userId) async {
    try {
      developer.log(
        '🔍 Ieškoma poros pagal vartotojo ID: $userId',
        name: _loggerName,
      );

      final query = await FirebaseService.couplesCollection
          .where('members.userId', arrayContains: userId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final coupleDoc = query.docs.first;
        final data = coupleDoc.data() as Map<String, dynamic>;

        developer.log(
          '✅ Rasta pora vartotojui: ${data['wifeName']}',
          name: _loggerName,
        );

        return {'id': coupleDoc.id, ...data};
      }

      developer.log('ℹ️ Poros nerasta vartotojui', name: _loggerName);
      return null;
    } catch (e) {
      developer.log('❌ Klaida gaunant porą: $e', name: _loggerName, level: 900);
      return null;
    }
  }

  // Ištrinti porą (tik žmonai)
  static Future<Map<String, dynamic>> deleteCouple(
    String coupleId,
    String userId,
  ) async {
    try {
      developer.log('🗑️ Bandoma ištrinti porą: $coupleId', name: _loggerName);

      final coupleDoc = await FirebaseService.couplesCollection
          .doc(coupleId)
          .get();
      if (!coupleDoc.exists) {
        developer.log('❌ Poros nėra', name: _loggerName, level: 900);
        return {'success': false, 'error': 'Poros nėra'};
      }

      final data = coupleDoc.data() as Map<String, dynamic>;
      final members = data['members'] as List<dynamic>? ?? [];

      // Patikrinti ar vartotojas yra žmona
      final isWife = members.any(
        (member) =>
            member is Map<String, dynamic> &&
            member['userId'] == userId &&
            member['role'] == 'wife',
      );

      if (!isWife) {
        developer.log(
          '❌ Tik žmona gali ištrinti porą',
          name: _loggerName,
          level: 900,
        );
        return {'success': false, 'error': 'Tik žmona gali ištrinti porą'};
      }

      await FirebaseService.couplesCollection.doc(coupleId).delete();
      developer.log('✅ Porą sėkmingai ištrinta', name: _loggerName);

      return {'success': true, 'message': 'Porą sėkmingai ištrinta'};
    } catch (e) {
      developer.log(
        '❌ Klaida trinant porą: $e',
        name: _loggerName,
        level: 1000,
      );
      return {'success': false, 'error': _getErrorMessage(e)};
    }
  }

  // Pagalbinė funkcija kodų generavimui
  static String _generateCode(String name, String type) {
    final cleanName = name.trim();
    final prefix = cleanName.length >= 3
        ? cleanName.substring(0, 3).toUpperCase()
        : cleanName.toUpperCase().padRight(3, 'X');

    final random = DateTime.now().millisecond % 1000;
    final code =
        '$prefix-${type.toUpperCase()}-${random.toString().padLeft(3, '0')}';

    developer.log('🔠 Sugeneruotas kodas: $code', name: _loggerName);
    return code;
  }

  // Gauti žmogui suprantamą klaidos žinutę
  static String _getErrorMessage(dynamic error) {
    if (error is FirebaseException) {
      developer.log('🔥 Firebase klaida: ${error.code}', name: _loggerName);

      switch (error.code) {
        case 'permission-denied':
          return 'Neturite teisių šiam veiksmui';
        case 'not-found':
          return 'Poros nerasta';
        case 'already-exists':
          return 'Porą jau egzistuoja';
        case 'unavailable':
          return 'Serveris nepasiekiamas. Patikrinkite interneto ryšį';
        default:
          return 'Duomenų bazės klaida: ${error.message}';
      }
    }
    return error.toString();
  }

  // Gauti poros narius
  static Future<List<Map<String, dynamic>>> getCoupleMembers(
    String coupleId,
  ) async {
    try {
      developer.log('👥 Gaunami poros nariai: $coupleId', name: _loggerName);

      final coupleDoc = await FirebaseService.couplesCollection
          .doc(coupleId)
          .get();
      if (!coupleDoc.exists) {
        return [];
      }

      final data = coupleDoc.data() as Map<String, dynamic>;
      final members = data['members'] as List<dynamic>? ?? [];

      developer.log('📊 Rasta narių: ${members.length}', name: _loggerName);

      return members.map((member) {
        if (member is Map<String, dynamic>) {
          return {
            'userId': member['userId'] ?? '',
            'role': member['role'] ?? '',
            'name': member['name'] ?? '',
            'joinedAt': member['joinedAt'] ?? '',
          };
        }
        return {'error': 'Invalid member data'};
      }).toList();
    } catch (e) {
      developer.log(
        '❌ Klaida gaunant poros narius: $e',
        name: _loggerName,
        level: 900,
      );
      return [];
    }
  }
}
