import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';
import 'firebase_service.dart';
import 'dart:developer' as developer;
import '../services/session_service.dart';

class CoupleService {
  static const String _loggerName = 'CoupleService';

  static Future<Map<String, dynamic>> createCouple(String wifeName) async {
    developer.log(
      '👰 Kuriama nauja pora (SENAS METODAS)...',
      name: _loggerName,
    );

    // 🔥 DEBUG: Patikrinti userId
    final userId = UserService.userId;
    developer.log(
      '🔍 DEBUG: UserId prieš kuriant porą: $userId',
      name: _loggerName,
    );

    if (userId.isEmpty) {
      developer.log('❌ ERROR: Tuščias userId!', name: _loggerName, level: 1000);
      return {
        'success': false,
        'error':
            'Vartotojo ID nerastas. Bandykite iš naujo atidaryti aplikaciją.',
      };
    }

    // Iškviečiame naują metodą su default reikšmėmis
    return await createCoupleV2(
      creatorName: wifeName,
      relationshipType: 'romantic',
      permissions: ['write', 'read', 'edit', 'delete', 'manage'],
    );
  }

  // Prisijungti prie poros su kodu (senas metodas)
  static Future<Map<String, dynamic>> joinCouple(String code) async {
    developer.log(
      '🔗 Bandoma prisijungti prie poros (SENAS METODAS)...',
      name: _loggerName,
    );

    // Automatiškai nustatyti rolę pagal kodą
    final isWifeCode = code.contains('-W-');
    final role = isWifeCode ? 'creator' : 'reader';
    final roleDisplay = isWifeCode ? 'rašytojas' : 'skaitytojas';

    return await joinCoupleV2(
      code: code,
      userRole: role,
      userName: roleDisplay,
    );
  }

  static Future<Map<String, dynamic>> createCoupleV2({
    required String creatorName,
    String relationshipType = 'romantic',
    List<String> permissions = const [
      'write',
      'read',
      'edit',
      'delete',
      'manage',
    ],
  }) async {
    try {
      developer.log(
        '✍️ Kuriama nauja pora (NAUJAS METODAS)...',
        name: _loggerName,
      );
      developer.log('👤 Rašytojo vardas: $creatorName', name: _loggerName);
      developer.log('🤝 Ryšio tipas: $relationshipType', name: _loggerName);
      developer.log('🔑 Leidimai: $permissions', name: _loggerName);

      final coupleId = DateTime.now().millisecondsSinceEpoch.toString();

      // Sugeneruoti naujus kodus
      final creatorCode = _generateCreatorCode(creatorName);
      final readerCode = _generateReaderCode(creatorName);

      // Taip pat sugeneruoti senus kodus atgaliniam sutartimumui
      final wifeCode = creatorCode;
      final husbandCode = readerCode;

      developer.log('🆔 Poros ID: $coupleId', name: _loggerName);
      developer.log('🔐 Rašymo kodas: $creatorCode', name: _loggerName);
      developer.log('📖 Skaitymo kodas: $readerCode', name: _loggerName);

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

      // 🔥 NAUJAS: Sukurti timestamp string
      final now = DateTime.now().toIso8601String();

      // Sukurti porą Firestore (su abiem versijomis laukų)
      developer.log('💾 Išsaugoma pora į Firebase...', name: _loggerName);

      await FirebaseService.couplesCollection.doc(coupleId).set({
        // ✅ NAUJI LAUKAI
        'creatorName': creatorName,
        'creatorCode': creatorCode,
        'readerCode': readerCode,
        'relationshipType': relationshipType,

        // ❌ SENI LAUKAI (atgaliniam sutartimumui)
        'wifeName': creatorName,
        'wifeCode': wifeCode,
        'husbandCode': husbandCode,

        // ✅ BENDRI LAUKAI
        'createdAt': FieldValue.serverTimestamp(), // 🔥 Šis OK, nes ne masyve
        'lastUpdated': FieldValue.serverTimestamp(), // 🔥 Šis OK
        'active': true,
        'version': 2,

        'members': [
          {
            'userId': userId,
            'role': 'creator',
            'role_legacy': 'wife',
            'permissions': permissions,
            'joinedAt': now, // 🔥 Pakeista: string vietoj serverTimestamp()
            'name': creatorName,
          },
        ],
      });

      // Išsaugoti lokaliai
      await _saveCoupleLocally(coupleId, creatorCode, 'creator');

      developer.log('✅ Porą sėkmingai sukurta!', name: _loggerName);

      return {
        'success': true,
        'coupleId': coupleId,
        // ✅ NAUJI REZULTATAI
        'creatorName': creatorName,
        'creatorCode': creatorCode,
        'readerCode': readerCode,
        'relationshipType': relationshipType,
        // ❌ SENI REZULTATAI (atgaliniam sutartimumui)
        'wifeName': creatorName,
        'wifeCode': wifeCode,
        'husbandCode': husbandCode,
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

  // Prisijungti prie poros (naujas metodas)
  static Future<Map<String, dynamic>> joinCoupleV2({
    required String code,
    required String userRole, // 'creator' arba 'reader'
    String userName = '',
  }) async {
    try {
      developer.log(
        '🔗 Bandoma prisijungti prie poros (NAUJAS METODAS)...',
        name: _loggerName,
      );
      developer.log('🔑 Įvestas kodas: $code', name: _loggerName);
      developer.log('🎭 Pasirinkta rolė: $userRole', name: _loggerName);

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

      // Ieškoti poros pagal naujus IR senus kodus
      developer.log('🔍 Ieškoma poros pagal kodą...', name: _loggerName);

      // Bandyti rasti pagal naujus kodus
      var query = await FirebaseService.couplesCollection
          .where('creatorCode', isEqualTo: code.trim())
          .limit(1)
          .get();

      String role = 'creator';
      String roleDisplay = 'Rašytojas';
      String roleLegacy = 'wife';

      if (query.docs.isEmpty) {
        // Bandyti rasti pagal skaitymo kodą
        query = await FirebaseService.couplesCollection
            .where('readerCode', isEqualTo: code.trim())
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          role = 'reader';
          roleDisplay = 'Skaitytojas';
          roleLegacy = 'husband';
        }
      }

      // Jei nerasta su naujais kodais, bandyti su senais
      if (query.docs.isEmpty) {
        developer.log(
          '⚠️ Naujais kodais nerasta, tikrinama senus kodus...',
          name: _loggerName,
          level: 900,
        );

        query = await FirebaseService.couplesCollection
            .where('wifeCode', isEqualTo: code.trim())
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          role = 'creator';
          roleDisplay = 'Rašytojas';
          roleLegacy = 'wife';
        } else {
          query = await FirebaseService.couplesCollection
              .where('husbandCode', isEqualTo: code.trim())
              .limit(1)
              .get();

          if (query.docs.isNotEmpty) {
            role = 'reader';
            roleDisplay = 'Skaitytojas';
            roleLegacy = 'husband';
          }
        }
      }

      developer.log('📊 Rasta porų: ${query.docs.length}', name: _loggerName);

      if (query.docs.isEmpty) {
        developer.log('❌ Neteisingas kodas', name: _loggerName, level: 900);
        return {'success': false, 'error': 'Neteisingas kodas'};
      }

      final coupleDoc = query.docs.first;
      final coupleId = coupleDoc.id;
      final data = coupleDoc.data() as Map<String, dynamic>? ?? {};

      // Gauti vardą iš naujų arba senų laukų
      final creatorName =
          data['creatorName'] as String? ??
          data['wifeName'] as String? ??
          'Nenurodyta';
      final relationshipType =
          data['relationshipType'] as String? ?? 'romantic';
      final members = data['members'] as List<dynamic>? ?? [];

      developer.log('✅ Rasta pora: $creatorName', name: _loggerName);
      developer.log('🆔 Poros ID: $coupleId', name: _loggerName);
      developer.log('🎭 Rolė: $roleDisplay', name: _loggerName);
      developer.log('🤝 Ryšio tipas: $relationshipType', name: _loggerName);

      // Patikrinti ar vartotojas jau yra poroje
      final alreadyMember = members.any(
        (member) =>
            member is Map<String, dynamic> && member['userId'] == userId,
      );

      if (alreadyMember) {
        developer.log('ℹ️ Vartotojas jau yra šioje poroje', name: _loggerName);
      } else {
        // Nustatyti permissions pagal rolę
        final List<String> permissions = role == 'creator'
            ? ['write', 'read', 'edit', 'delete', 'manage']
            : ['read', 'react'];

        // Pridėti vartotoją į porą
        developer.log('👥 Pridedamas vartotojas į porą...', name: _loggerName);

        await FirebaseService.couplesCollection.doc(coupleId).update({
          'members': FieldValue.arrayUnion([
            {
              'userId': userId,
              'role': role,
              'role_legacy': roleLegacy,
              'permissions': permissions,
              'joinedAt': FieldValue.serverTimestamp(),
              'name': userName.isNotEmpty ? userName : roleDisplay,
            },
          ]),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        developer.log(
          '✅ Vartotojas sėkmingai pridėtas į porą',
          name: _loggerName,
        );
      }

      // Išsaugoti lokaliai
      await _saveCoupleLocally(coupleId, code, role);

      developer.log('🎉 Sėkmingai prisijungta prie poros!', name: _loggerName);

      return {
        'success': true,
        'coupleId': coupleId,
        // ✅ NAUJI REZULTATAI
        'role': role,
        'roleDisplay': roleDisplay,
        'creatorName': creatorName,
        'relationshipType': relationshipType,
        // ❌ SENI REZULTATAI (atgaliniam sutartimumui)
        'role_legacy': roleLegacy,
        'wifeName': creatorName,
        'message':
            'Sėkmingai prisijungei kaip $roleDisplay prie poros "$creatorName"',
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

  // ========== 🔧 PAGALBINĖS FUNKCIJOS ==========

  // Sugeneruoti rašymo kodą
  static String _generateCreatorCode(String name) {
    final cleanName = name.trim();
    final prefix = cleanName.length >= 3
        ? cleanName.substring(0, 3).toUpperCase()
        : cleanName.toUpperCase().padRight(3, 'X');

    final random = DateTime.now().millisecond % 1000;
    final code =
        '$prefix-C-${random.toString().padLeft(3, '0')}'; // C = Creator

    developer.log('🔠 Sugeneruotas rašymo kodas: $code', name: _loggerName);
    return code;
  }

  // Sugeneruoti skaitymo kodą
  static String _generateReaderCode(String name) {
    final cleanName = name.trim();
    final prefix = cleanName.length >= 3
        ? cleanName.substring(0, 3).toUpperCase()
        : cleanName.toUpperCase().padRight(3, 'X');

    final random =
        (DateTime.now().millisecond * 37) % 1000; // Skirtingas random
    final code = '$prefix-R-${random.toString().padLeft(3, '0')}'; // R = Reader

    developer.log('🔠 Sugeneruotas skaitymo kodas: $code', name: _loggerName);
    return code;
  }

  static Future<void> _saveCoupleLocally(
    String coupleId,
    String code,
    String role,
  ) async {
    try {
      // Gauti papildomą informaciją
      final couple = await getCurrentCouple();
      final creatorName = couple?['creatorName'] as String? ?? '';
      final readerCode = couple?['readerCode'] as String? ?? '';

      // Išsaugoti sesiją
      await SessionService.saveSession(
        coupleId: coupleId,
        coupleCode: code,
        userRole: role,
        creatorName: creatorName,
        readerCode: readerCode,
      );

      developer.log(
        '💾 Poros informacija išsaugota sesijoje',
        name: _loggerName,
      );
    } catch (e) {
      developer.log(
        '⚠️ Klaida išsaugant sesiją: $e',
        name: _loggerName,
        level: 900,
      );
    }
  }

  // ========== 📊 KITI METODAI (atnaujinti) ==========

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

        // Naudoti naują arba seną vardą
        final name = data['creatorName'] ?? data['wifeName'] ?? 'Nenurodyta';

        developer.log('✅ Rasta pora vartotojui: $name', name: _loggerName);

        return {'id': coupleDoc.id, ...data};
      }

      developer.log('ℹ️ Poros nerasta vartotojui', name: _loggerName);
      return null;
    } catch (e) {
      developer.log('❌ Klaida gaunant porą: $e', name: _loggerName, level: 900);
      return null;
    }
  }

  // Gauti dabartinę porą (naujas metodas su permissionais)
  static Future<Map<String, dynamic>?> getCurrentCouple() async {
    try {
      final userId = UserService.userId;
      developer.log(
        '🔍 Ieškoma dabartinės poros vartotojui: $userId',
        name: _loggerName,
      );

      final query = await FirebaseService.couplesCollection
          .where('members.userId', arrayContains: userId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final coupleDoc = query.docs.first;
        final data = coupleDoc.data() as Map<String, dynamic>;

        // Rasti vartotojo informaciją
        final members = data['members'] as List<dynamic>? ?? [];

        // Saugus firstWhere su orElse
        Map<String, dynamic>? userMember;
        for (final member in members) {
          if (member is Map<String, dynamic> && member['userId'] == userId) {
            userMember = member;
            break;
          }
        }

        final userRole = userMember?['role'] as String? ?? 'reader';
        final userPermissions =
            userMember?['permissions'] as List<dynamic>? ?? [];

        // Gauti vardą
        final creatorName =
            data['creatorName'] as String? ?? data['wifeName'] as String? ?? '';

        developer.log('✅ Rasta pora: $creatorName', name: _loggerName);
        developer.log('🎭 Vartotojo rolė: $userRole', name: _loggerName);
        developer.log(
          '🔑 Vartotojo permissions: $userPermissions',
          name: _loggerName,
        );

        final result = {
          'id': coupleDoc.id,
          'creatorName': creatorName,
          'creatorCode':
              data['creatorCode'] as String? ??
              data['wifeCode'] as String? ??
              '',
          'readerCode':
              data['readerCode'] as String? ??
              data['husbandCode'] as String? ??
              '',
          'relationshipType': data['relationshipType'] as String? ?? 'romantic',
          'userRole': userRole,
          'userPermissions': List<String>.from(userPermissions.cast<String>()),
        };

        // Pridėti likusius duomenis
        data.forEach((key, value) {
          if (!result.containsKey(key)) {
            result[key] = value;
          }
        });

        return result;
      }

      developer.log('ℹ️ Poros nerasta vartotojui', name: _loggerName);
      return null;
    } catch (e) {
      developer.log('❌ Klaida gaunant porą: $e', name: _loggerName, level: 900);
      return null;
    }
  }

  // Ištrinti porą (atnaujintas - tik creator'iams)
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

      // Patikrinti ar vartotojas yra creator (arba wife senoje sistemoje)
      bool isCreator = false;
      for (final member in members) {
        if (member is Map<String, dynamic> && member['userId'] == userId) {
          final role = member['role'] as String?;
          final roleLegacy = member['role_legacy'] as String?;
          if (role == 'creator' || roleLegacy == 'wife') {
            isCreator = true;
            break;
          }
        }
      }

      if (!isCreator) {
        developer.log(
          '❌ Tik rašytojas gali ištrinti porą',
          name: _loggerName,
          level: 900,
        );
        return {'success': false, 'error': 'Tik rašytojas gali ištrinti porą'};
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
            'userId': member['userId'] as String? ?? '',
            'role':
                member['role'] as String? ??
                member['role_legacy'] as String? ??
                '',
            'permissions': member['permissions'] as List<dynamic>? ?? [],
            'name': member['name'] as String? ?? '',
            'joinedAt': member['joinedAt'],
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

  // ========== 🎯 NAUDINGOS FUNKCIJOS ==========

  // Patikrinti ar vartotojas turi leidimą
  static Future<bool> hasPermission(String permission) async {
    final couple = await getCurrentCouple();
    if (couple == null) return false;

    final permissions = couple['userPermissions'] as List<String>? ?? [];
    return permissions.contains(permission);
  }

  // Gauti vartotojo rolę
  static Future<String?> getUserRole() async {
    final couple = await getCurrentCouple();
    return couple?['userRole'] as String?;
  }

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
        case 'invalid-argument':
          return 'Netinkami duomenys. Serverio klaida.'; // 🔥 NAUJAS
        default:
          return 'Duomenų bazės klaida: ${error.message}';
      }
    }

    // 🔥 NAUJAS: Tikrinti konkretų error message
    if (error.toString().contains('serverTimestamp()')) {
      return 'Serverio laiko klaida. Bandykite dar kartą.';
    }

    return error.toString();
  }

  // 🔥 NAUJAS: Auto-login iš sesijos
  static Future<Map<String, dynamic>?> autoLoginFromSession() async {
    try {
      developer.log('🔐 Bandoma auto-login iš sesijos...', name: _loggerName);

      final session = await SessionService.getSavedSession();
      if (session == null) {
        developer.log('ℹ️ Nėra išsaugotos sesijos', name: _loggerName);
        return null;
      }

      final coupleId = session['coupleId']!;
      final coupleCode = session['coupleCode']!;
      final userRole = session['userRole']!;
      final creatorName = session['creatorName']!;

      developer.log('✅ Rasta sesija porai: $creatorName', name: _loggerName);

      // Patikrinti ar pora vis dar egzistuoja Firestore
      final coupleDoc = await FirebaseService.couplesCollection
          .doc(coupleId)
          .get();

      if (!coupleDoc.exists) {
        developer.log(
          '❌ Poros nebėra Firestore',
          name: _loggerName,
          level: 900,
        );
        await SessionService.clearSession();
        return null;
      }

      // Patikrinti ar vartotojas vis dar yra poroje
      final data = coupleDoc.data() as Map<String, dynamic>;
      final members = data['members'] as List<dynamic>? ?? [];
      final userId = UserService.userId;

      final isStillMember = members.any(
        (member) =>
            member is Map<String, dynamic> && member['userId'] == userId,
      );

      if (!isStillMember) {
        developer.log(
          '❌ Vartotojas nebėra poroje',
          name: _loggerName,
          level: 900,
        );
        await SessionService.clearSession();
        return null;
      }

      developer.log('✅ Auto-login sėkmingas!', name: _loggerName);

      return {
        'success': true,
        'coupleId': coupleId,
        'coupleCode': coupleCode,
        'userRole': userRole,
        'creatorName': creatorName,
        'message': 'Automatiškai prisijungta prie poros "$creatorName"',
      };
    } catch (e) {
      developer.log('❌ Klaida auto-login: $e', name: _loggerName, level: 1000);
      return null;
    }
  }
}
