import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:developer' as developer;

import 'data/messages.dart';
import 'data/custom_messages.dart';
import 'screens/custom_messages_screen.dart';
import 'services/firebase_service.dart';
import 'services/couple_service.dart';
import 'services/message_service.dart';
import 'services/session_service.dart';
import 'services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lock Screen Love',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _currentMessage = '';
  int _dayOfYear = 0;
  bool _isLoading = true;
  StreamSubscription? _messageSubscription;
  final String _loggerName = 'HomePage';
  Timer? _dayCheckTimer;
  String _userRole = 'unknown';
  String _creatorName = '';
  bool _canWriteMessages = false;

  // 🔥 NAUJAS: Auto-login būsena
  bool _isCheckingSession = false;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();

    // 🔥 NAUJAS: Inicializuoti UserService prieš viską
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await UserService.initialize();
      _initializeApp();
    });

    _dayCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkAndUpdateDay();
    });

    _startMessageListener();
  }

  // 🔥 NAUJAS: Įkelti vartotojo rolę ir permissions
  Future<void> _loadUserRole() async {
    try {
      developer.log('🎭 Įkeliama vartotojo rolė...', name: _loggerName);

      final couple = await CoupleService.getCurrentCouple();
      if (couple != null) {
        final newUserRole = couple['userRole'] as String? ?? 'reader';
        final newCreatorName = couple['creatorName'] as String? ?? '';

        // Tikrinti ar reikia atnaujinti state
        if (mounted &&
            (newUserRole != _userRole || newCreatorName != _creatorName)) {
          setState(() {
            _userRole = newUserRole;
            _creatorName = newCreatorName;
            _canWriteMessages = _userRole == 'creator';
          });

          developer.log('✅ Vartotojo rolė: $_userRole', name: _loggerName);
          developer.log('✅ Rašytojo vardas: $_creatorName', name: _loggerName);
          developer.log('✅ Gali rašyti: $_canWriteMessages', name: _loggerName);
        }
      } else {
        developer.log(
          'ℹ️ Poros nerasta, default rolė: reader',
          name: _loggerName,
        );
        if (mounted) {
          setState(() {
            _userRole = 'reader';
            _creatorName = '';
            _canWriteMessages = false;
          });
        }
      }
    } catch (e) {
      developer.log(
        '⚠️ Klaida įkeliant rolę: $e',
        name: _loggerName,
        level: 900,
      );
    }
  }

  Future<void> _loadTodayMessage() async {
    try {
      final now = DateTime.now();
      _dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
      String defaultMsg = DailyMessages.getTodayMessage();

      developer.log('📅 Šiandien diena: $_dayOfYear', name: _loggerName);

      _currentMessage = await CustomMessages.getMessageForDay(
        _dayOfYear,
        defaultMsg,
      );

      final messagePreview = _currentMessage.length > 50
          ? '${_currentMessage.substring(0, 50)}...'
          : _currentMessage;

      developer.log('💌 Įkelta žinutė: "$messagePreview"', name: _loggerName);
    } catch (e) {
      developer.log(
        '❌ Klaida įkeliant žinutę: $e',
        name: _loggerName,
        level: 1000,
      );
      _currentMessage = 'Klaida įkeliant žinutę';
    }
  }

  void _checkAndUpdateDay() {
    try {
      final now = DateTime.now();
      final currentDay = now.difference(DateTime(now.year, 1, 1)).inDays + 1;

      if (currentDay != _dayOfYear) {
        developer.log(
          '🔄 Diena pasikeitė: $_dayOfYear → $currentDay',
          name: _loggerName,
        );

        if (mounted) {
          setState(() {
            _dayOfYear = currentDay;
          });
          _loadTodayMessage();
          _updateWidget();
        }
      }
    } catch (e) {
      developer.log(
        '❌ Klaida tikrinant dieną: $e',
        name: _loggerName,
        level: 900,
      );
    }
  }

  Future<void> _updateWidget() async {
    try {
      final now = DateTime.now();
      final timeString =
          '${_formatNumber(now.hour)}:${_formatNumber(now.minute)}';

      await HomeWidget.saveWidgetData<String>('widget_time', timeString);
      await HomeWidget.saveWidgetData<String>(
        'widget_message',
        _currentMessage,
      );

      final bool? result = await HomeWidget.updateWidget(
        name: 'HomeWidgetProvider',
        androidName: 'HomeWidgetProvider',
      );

      if (result == true) {
        developer.log('✅ Widget atnaujintas: $timeString', name: _loggerName);
      } else if (result == false) {
        developer.log('⚠️ Nepavyko atnaujinti widget', name: _loggerName);
      } else {
        developer.log('ℹ️ Widget update grąžino null', name: _loggerName);
      }
    } catch (e) {
      developer.log(
        '❌ Klaida atnaujinant widget: $e',
        name: _loggerName,
        level: 900,
      );
    }
  }

  String _formatNumber(int number) {
    return number.toString().padLeft(2, '0');
  }

  Future<void> _changeMessage() async {
    developer.log('🔄 Keičiama žinutė', name: _loggerName);

    try {
      setState(() {
        _dayOfYear = (_dayOfYear % 365) + 1;
      });

      String defaultMsg = DailyMessages.getMessageForDay(_dayOfYear);
      _currentMessage = await CustomMessages.getMessageForDay(
        _dayOfYear,
        defaultMsg,
      );

      if (mounted) {
        setState(() {});
        await _updateWidget();
      }

      developer.log('✅ Žinutė pakeista į dieną $_dayOfYear', name: _loggerName);
    } catch (e) {
      developer.log(
        '❌ Klaida keičiant žinutę: $e',
        name: _loggerName,
        level: 900,
      );
    }
  }

  // Real-time žinučių listener
  void _startMessageListener() {
    developer.log('🎧 Pradedamas žinučių stream listeneris', name: _loggerName);

    _messageSubscription = MessageService.getMessagesStream().listen(
      (messagesSnapshot) {
        if (!mounted) return;

        developer.log(
          '📡 Gauta ${messagesSnapshot.docs.length} žinučių iš stream',
          name: _loggerName,
        );

        // Rasti žinutę šiandienai
        for (final doc in messagesSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final messageDay = data['dayOfYear'];
          final messageText = data['message'];

          if (messageDay == _dayOfYear) {
            developer.log(
              '✅ Radome žinutę šiandienai iš stream',
              name: _loggerName,
            );
            if (mounted) {
              setState(() {
                _currentMessage = messageText ?? _currentMessage;
              });
              _updateWidget();
            }
            break;
          }
        }
      },
      onError: (error) {
        developer.log(
          '❌ Message stream error: $error',
          name: _loggerName,
          level: 1000,
        );
      },
    );
  }

  Future<void> _initializeApp() async {
    developer.log('🚀 Inicijuojama programa', name: _loggerName);

    try {
      developer.log('🔄 Starting Firebase Auth...', name: _loggerName);
      final auth = FirebaseService.auth;
      developer.log('✅ Auth instance created', name: _loggerName);

      final userCredential = await auth.signInAnonymously();
      developer.log('✅ Anonymous login successful', name: _loggerName);
      developer.log(
        '✅ User ID: ${userCredential.user?.uid}',
        name: _loggerName,
      );
    } catch (e) {
      developer.log(
        '❌ Firebase Auth failed: $e',
        name: _loggerName,
        level: 1000,
      );

      if (e is FirebaseAuthException) {
        developer.log(
          '❌ Auth error code: ${e.code}',
          name: _loggerName,
          level: 1000,
        );
        developer.log(
          '❌ Auth error message: ${e.message}',
          name: _loggerName,
          level: 1000,
        );
      }
    }

    // 🔥 NAUJAS: Patikrinti ar reikia rodyti onboarding
    final onboardingCompleted = await SessionService.isOnboardingCompleted();
    if (!onboardingCompleted) {
      developer.log('🎯 Rodomas onboarding...', name: _loggerName);
      if (mounted) {
        setState(() {
          _showOnboarding = true;
        });
      }
      return;
    }

    // 🔥 NAUJAS: Bandyti auto-login
    await _tryAutoLogin();

    // Toliau įprasta logika
    await _loadTodayMessage();
    await _updateWidget();

    // 🔥 NAUJAS: Įkelti rolę po visko
    await _loadUserRole();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    developer.log('✅ Programa sėkmingai inicijuota', name: _loggerName);
  }

  // 🔥 NAUJAS: Auto-login funkcija
  Future<void> _tryAutoLogin() async {
    if (_isCheckingSession) return;

    setState(() {
      _isCheckingSession = true;
    });

    try {
      developer.log(
        '🔍 Tikrinama ar yra išsaugota sesija...',
        name: _loggerName,
      );

      final autoLoginResult = await CoupleService.autoLoginFromSession();

      if (autoLoginResult != null && autoLoginResult['success'] == true) {
        developer.log('✅ Auto-login sėkmingas!', name: _loggerName);

        // Įkelti vartotojo rolę
        await _loadUserRole();

        // Pranešti vartotojui
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                autoLoginResult['message'] as String? ??
                    'Automatiškai prisijungta',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        developer.log(
          'ℹ️ Auto-login nepavyko arba nėra sesijos',
          name: _loggerName,
        );
      }
    } catch (e) {
      developer.log('❌ Klaida auto-login: $e', name: _loggerName, level: 900);
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingSession = false;
        });
      }
    }
  }

  // 1. Porų dialogo pakeitimai:
  void _showCoupleDialog() {
    if (!mounted) return;

    developer.log('👫 Rodomas porų dialogas', name: _loggerName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Poros nustatymai'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add, color: Colors.pink),
              title: const Text('Sukurti naują porą'),
              subtitle: const Text('Būsi rašytojas - galėsi rašyti žinutes'),
              onTap: () {
                Navigator.pop(context);
                if (mounted) {
                  _showCreateCoupleDialog();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.login, color: Colors.blue),
              title: const Text('Prisijungti prie poros'),
              subtitle: const Text(
                'Būsi skaitytojas - galėsi skaityti žinutes',
              ),
              onTap: () {
                Navigator.pop(context);
                if (mounted) {
                  _showJoinCoupleDialog();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // 2. Sukurti porą dialogas:
  void _showCreateCoupleDialog() {
    if (!mounted) return;

    developer.log('✍️ Rodomas sukurti porą dialogas', name: _loggerName);

    final creatorNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sukurti naują porą'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Įrašyk savo vardą:'),
            const SizedBox(height: 10),
            TextField(
              controller: creatorNameController,
              decoration: const InputDecoration(
                hintText: 'Tavo vardas',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Atšaukti'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (creatorNameController.text.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Įrašyk savo vardą!')),
                  );
                }
                return;
              }

              developer.log('🔄 Kuriama pora...', name: _loggerName);

              if (mounted) {
                setState(() {
                  _isLoading = true;
                });
              }

              final result = await CoupleService.createCouple(
                creatorNameController.text,
              );

              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }

              if (context.mounted) {
                Navigator.pop(context);
              }

              if (result['success'] == true) {
                developer.log('✅ Porą sukurta sėkmingai', name: _loggerName);
                if (mounted) {
                  _showCoupleCreatedDialog(result);
                }
              } else {
                developer.log(
                  '❌ Klaida kuriant porą: ${result['error']}',
                  name: _loggerName,
                  level: 900,
                );

                if (mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Klaida: ${result['error']}'),
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              }
            },
            child: const Text('Sukurti'),
          ),
        ],
      ),
    );
  }

  // 3. Porą sukurta sėkmės dialogas:
  void _showCoupleCreatedDialog(Map<String, dynamic> result) {
    if (!mounted) return;

    developer.log('🎉 Rodomas sėkmės dialogas', name: _loggerName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Porą sukurta sėkmingai! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tavo kodai:'),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✍️ Rašymo kodas:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    result['creatorCode'] ?? '',
                    style: const TextStyle(fontSize: 16, color: Colors.pink),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '👀 Skaitymo kodas:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    result['readerCode'] ?? '',
                    style: const TextStyle(fontSize: 16, color: Colors.blue),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              '🔹 Duok RAŠYMO kodą sau (rašyti žinutes)\n'
              '🔹 Duok SKAITYMO kodą partneriui (skaityti žinutes)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Supratau'),
          ),
        ],
      ),
    );
  }

  void _showJoinCoupleDialog() {
    if (!mounted) return;

    developer.log(
      '🔗 Rodomas prisijungti prie poros dialogas',
      name: _loggerName,
    );

    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Prisijungti prie poros'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Įrašyk gautą kodą:'),
            const SizedBox(height: 10),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                hintText: 'PVZ: LIN-C-555 arba LIN-R-572',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Jei gavai RAŠYMO kodą (-C-) - galėsi rašyti žinutes\n'
              'Jei gavai SKAITYMO kodą (-R-) - galėsi skaityti žinutes',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Atšaukti'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (codeController.text.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Įrašyk kodą!')));
                }
                return;
              }

              developer.log(
                '🔄 Bandoma prisijungti prie poros...',
                name: _loggerName,
              );

              final userId = UserService.userId;
              developer.log('✅ Dabartinis UserId: $userId', name: _loggerName);

              final result = await CoupleService.joinCouple(
                codeController.text,
              );

              if (context.mounted) {
                Navigator.pop(context);
              }

              if (result['success'] == true) {
                developer.log(
                  '✅ Sėkmingai prisijungta prie poros',
                  name: _loggerName,
                );

                // 🔥 NAUJAS: Atnaujinti rolę po prisijungimo
                await _loadUserRole();

                if (mounted) {
                  _showJoinSuccessDialog(result);
                }
              } else {
                developer.log(
                  '❌ Klaida prisijungiant: ${result['error']}',
                  name: _loggerName,
                  level: 900,
                );

                if (mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Klaida: ${result['error']}')),
                  );
                }
              }
            },
            child: const Text('Prisijungti'),
          ),
        ],
      ),
    );
  }

  // 5. Prisijungimo sėkmės dialogas:
  void _showJoinSuccessDialog(Map<String, dynamic> result) {
    if (!mounted) return;

    final role = result['role'] == 'creator' ? 'Rašytojas' : 'Skaitytojas';
    final creatorName = result['creatorName'] ?? 'Nenurodyta';
    final roleDisplay = result['roleDisplay'] ?? role;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sveikiname! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sėkmingai prisijungei prie poros!'),
            const SizedBox(height: 10),
            Text('👫 Poros vardas: $creatorName'),
            Text('🎭 Tavo rolė: $roleDisplay'),
            const SizedBox(height: 15),
            Text(
              result['role'] == 'creator'
                  ? '🔹 Dabar gali rašyti žinutes!\n🔹 Jos automatiškai atsiras partnerio widget\'e'
                  : '🔹 Dabar gali skaityti žinutes!\n🔹 Jos automatiškai atsiras tavo widget\'e',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Puiku!'),
          ),
        ],
      ),
    );
  }

  // 🔥 NAUJAS: Logout dialogas
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atsijungti'),
        content: const Text(
          'Ar tikrai norite atsijungti? '
          'Jums reikės vėl įvesti kodą kitą kartą.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Atšaukti'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Atsijungti'),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // 1. Išvalyti sesiją
      await SessionService.clearSession();

      // 2. Išvalyti lokalius duomenis
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('custom_messages');

      // 3. 🔥 NAUJAS: Sukurti naują anoniminį vartotoją Firebase
      try {
        await FirebaseAuth.instance.signOut(); // Atsijungti nuo seno
        await FirebaseAuth.instance.signInAnonymously(); // Prisijungti nauju
        await UserService.initialize(); // Atnaujinti UserService

        developer.log(
          '✅ Sukurtas naujas anoniminis vartotojas',
          name: _loggerName,
        );
      } catch (e) {
        developer.log(
          '⚠️ Klaida kurtant naują vartotoją: $e',
          name: _loggerName,
          level: 900,
        );
      }

      // 4. Resetinti būseną
      setState(() {
        _userRole = 'unknown';
        _creatorName = '';
        _canWriteMessages = false;
        _currentMessage = '';
        _dayOfYear =
            DateTime.now()
                .difference(DateTime(DateTime.now().year, 1, 1))
                .inDays +
            1;
      });

      // 5. Įkelti default žinutę
      await _loadTodayMessage();
      await _updateWidget();

      developer.log('✅ Sėkmingai atsijungta', name: _loggerName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sėkmingai atsijungta'),
            duration: Duration(seconds: 2),
          ),
        );

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      developer.log(
        '❌ Klaida atsijungiant: $e',
        name: _loggerName,
        level: 1000,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Klaida atsijungiant: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    developer.log('♻️ Atlaisvinami resursai', name: _loggerName);
    _dayCheckTimer?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }

  // 🔥 NAUJAS: Onboarding screen
  Widget _buildOnboardingScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite, size: 100, color: Colors.pink),
              const SizedBox(height: 30),
              const Text(
                'Sveiki atvykę į Lock Screen Love! 💕',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'Čia galite rašyti ir dalintis meilės žinutėmis\n'
                'su artimaisiais tiesiai ant užrakto ekrano.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await SessionService.markOnboardingCompleted();
                    if (mounted) {
                      setState(() {
                        _showOnboarding = false;
                        _isLoading = false;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Pradėti naudotis'),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _showCoupleDialog,
                child: const Text('Jau turiu porą? Prisijungti'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 NAUJAS: Onboarding screen
    if (_showOnboarding) {
      return _buildOnboardingScreen();
    }

    // Loading screen su auto-login indikatoriumi
    if (_isLoading || _isCheckingSession) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                _isCheckingSession
                    ? 'Tikrinama prisijungimas... 🔍'
                    : 'Kraunamos meilės žinutės... 💕',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                'Diena: $_dayOfYear',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (_isCheckingSession) ...[
                const SizedBox(height: 10),
                const Text(
                  '(Automatinis prisijungimas)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: _buildAppBarTitle(),
        actions: _buildAppBarActions(),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildRoleIcon(),
              const SizedBox(height: 30),
              _buildWelcomeText(),
              const SizedBox(height: 20),
              const Text(
                'Dabartinė žinutė:',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              _buildMessageCard(),
              const SizedBox(height: 10),
              Text(
                'Diena: $_dayOfYear / 365',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              _buildChangeMessageButton(),
              const SizedBox(height: 40),
              _buildWidgetInstructions(),
            ],
          ),
        ),
      ),
    );
  }

  // 🔥 Role icon
  Widget _buildRoleIcon() {
    if (_userRole == 'creator') {
      return const Icon(Icons.edit, size: 100, color: Colors.pink);
    } else if (_userRole == 'reader') {
      return const Icon(Icons.visibility, size: 100, color: Colors.blue);
    }
    return const Icon(Icons.favorite, size: 100, color: Colors.pink);
  }

  // 🔥 Welcome text pagal rolę
  Widget _buildWelcomeText() {
    if (_userRole == 'creator') {
      return Column(
        children: [
          const Text(
            'Sveiki, Rašytojau! ✍️',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          if (_creatorName.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              'Jūsų pora: $_creatorName',
              style: const TextStyle(fontSize: 16, color: Colors.deepPurple),
            ),
          ],
        ],
      );
    } else if (_userRole == 'reader') {
      return Column(
        children: [
          const Text(
            'Sveiki, Skaitytojau! 👀',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          if (_creatorName.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              'Rašytojas: $_creatorName',
              style: const TextStyle(fontSize: 16, color: Colors.deepPurple),
            ),
          ],
        ],
      );
    }

    return const Text(
      'Widget sukonfigūruotas!',
      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    );
  }

  // 🔥 Message card
  Widget _buildMessageCard() {
    final isCreator = _userRole == 'creator';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCreator ? Colors.pink.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isCreator ? Colors.pink.shade100 : Colors.blue.shade100,
        ),
      ),
      child: Column(
        children: [
          Text(
            _currentMessage,
            style: TextStyle(
              fontSize: 20,
              color: isCreator ? Colors.pink : Colors.blue,
            ),
            textAlign: TextAlign.center,
          ),
          if (_userRole == 'reader' && _creatorName.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '~ $_creatorName',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 🔥 Change message button tik rašytojams
  Widget _buildChangeMessageButton() {
    // Tik rašytojai gali keisti žinutes
    if (!_canWriteMessages) {
      return Container(); // Nieko nerodome
    }

    return ElevatedButton.icon(
      onPressed: _changeMessage,
      icon: const Icon(Icons.refresh),
      label: const Text('Keisti žinutę'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
      ),
    );
  }

  // 🔥 Widget instructions pagal rolę
  Widget _buildWidgetInstructions() {
    final instructions = <Widget>[];

    if (_userRole == 'creator') {
      instructions.addAll([
        const Text(
          '📱 Kaip pridėti widget:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          '1. Ilgai spausk lock/home screen',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const Text(
          '2. Pasirink "Widgets"',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const Text(
          '3. Rask "Lock Screen Love"',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 15),
        const Text(
          '✍️ Jūs kaip rašytojas matysite žinutes widget\'e',
          style: TextStyle(fontSize: 12, color: Colors.pink),
        ),
      ]);
    } else if (_userRole == 'reader') {
      instructions.addAll([
        const Text(
          '📱 Kaip pridėti widget:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          '1. Ilgai spausk lock/home screen',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const Text(
          '2. Pasirink "Widgets"',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const Text(
          '3. Rask "Lock Screen Love"',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 15),
        Text(
          '👀 Jūs kaip skaitytojas matysite žinutes iš $_creatorName',
          style: const TextStyle(fontSize: 12, color: Colors.blue),
        ),
      ]);
    } else {
      instructions.addAll([
        const Text(
          '📱 Kaip pridėti widget:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          '1. Ilgai spausk lock/home screen',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const Text(
          '2. Pasirink "Widgets"',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const Text(
          '3. Rask "Lock Screen Love"',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ]);
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: instructions),
    );
  }

  // 🔥 AppBar title pagal rolę
  Widget _buildAppBarTitle() {
    if (_userRole == 'creator') {
      return const Text('Lock Screen Love ✍️');
    } else if (_userRole == 'reader') {
      return const Text('Lock Screen Love 👀');
    }
    return const Text('Lock Screen Love');
  }

  // 🔥 AppBar actions pagal permissions
  List<Widget> _buildAppBarActions() {
    final actions = <Widget>[];

    // "Mano tekstai" mygtukas tik rašytojams
    if (_canWriteMessages) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.edit),
          tooltip: 'Mano tekstai',
          onPressed: () async {
            developer.log(
              '📝 Atidaromas custom žinučių ekranas',
              name: _loggerName,
            );

            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CustomMessagesScreen(),
              ),
            );

            if (mounted) {
              await _loadTodayMessage();
              setState(() {});
              await _updateWidget();
            }
          },
        ),
      );
    }

    // "Poros nustatymai" mygtukas visiems
    actions.add(
      IconButton(
        icon: const Icon(Icons.group),
        tooltip: 'Poros nustatymai',
        onPressed: _showCoupleDialog,
      ),
    );

    // 🔥 NAUJAS: Logout mygtukas (tik jei yra sesija)
    if (_userRole != 'unknown') {
      actions.add(
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Atsijungti',
          onPressed: _showLogoutDialog,
        ),
      );
    }

    return actions;
  }
}
