import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:async';
import 'data/messages.dart';
import 'data/custom_messages.dart';
import 'screens/custom_messages_screen.dart';
import 'services/firebase_service.dart';
import 'services/couple_service.dart';
import 'services/message_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/user_service.dart';
import 'dart:developer' as developer;

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

  @override
  void initState() {
    super.initState();
    _initializeApp();

    _dayCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkAndUpdateDay();
    });

    _startMessageListener();
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

  @override
  void dispose() {
    developer.log('♻️ Atlaisvinami resursai', name: _loggerName);
    _dayCheckTimer?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
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

    await _loadTodayMessage();
    await _updateWidget();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    developer.log('✅ Programa sėkmingai inicijuota', name: _loggerName);
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

      // ✅ Teisingas būdas patikrinti
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

  // 🔥 Porų funkcijos
  void _showCoupleDialog() {
    if (!mounted) return;

    developer.log('👫 Rodomas porų dialogas', name: _loggerName);

    final currentContext = context; // Išsaugome context

    showDialog(
      context: currentContext,
      builder: (context) => AlertDialog(
        title: const Text('Poros nustatymai'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add, color: Colors.pink),
              title: const Text('Sukurti naują porą'),
              subtitle: const Text('Būsi žmona - galėsi rašyti žinutes'),
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
              subtitle: const Text('Būsi vyras - galėsi skaityti žinutes'),
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

  void _showCreateCoupleDialog() {
    if (!mounted) return;

    developer.log('👰 Rodomas sukurti porą dialogas', name: _loggerName);

    final wifeNameController = TextEditingController();
    final currentContext = context; // Išsaugome context

    showDialog(
      context: currentContext,
      builder: (context) => AlertDialog(
        title: const Text('Sukurti naują porą'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Įrašyk savo vardą:'),
            const SizedBox(height: 10),
            TextField(
              controller: wifeNameController,
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
              if (wifeNameController.text.isEmpty) {
                // Naudojame dialog context, o ne state context
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
                wifeNameController.text,
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

  void _showCoupleCreatedDialog(Map<String, dynamic> result) {
    if (!mounted) return;

    developer.log('🎉 Rodomas sėkmės dialogas', name: _loggerName);

    final currentContext = context; // Išsaugome context

    showDialog(
      context: currentContext,
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
                color: Colors.pink.shade50, // Panaudojame .shade50 vietoj [50]
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '👩 Žmonos kodas (rašymui):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    result['wifeCode'] ?? '',
                    style: const TextStyle(fontSize: 16, color: Colors.pink),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '👨 Vyro kodas (skaitymui):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    result['husbandCode'] ?? '',
                    style: const TextStyle(fontSize: 16, color: Colors.blue),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              '🔹 Duok ŽMONOS kodą sau (rašyti žinutes)\n'
              '🔹 Duok VYRO kodą partneriui (skaityti žinutes)',
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
    final currentContext = context; // Išsaugome context

    showDialog(
      context: currentContext,
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
                hintText: 'PVZ: LINA-W-123',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Jei gavai ŽMONOS kodą - galėsi rašyti žinutes\n'
              'Jei gavai VYRO kodą - galėsi skaityti žinutes',
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

              UserService.setUserId('fixed_user_lina');
              developer.log('✅ UserId nustatytas', name: _loggerName);

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

  void _showJoinSuccessDialog(Map<String, dynamic> result) {
    if (!mounted) return;

    final role = result['role'] == 'wife' ? 'Žmona' : 'Vyras';
    final wifeName = result['wifeName'] ?? 'Nenurodyta';
    final currentContext = context; // Išsaugome context

    showDialog(
      context: currentContext,
      builder: (context) => AlertDialog(
        title: const Text('Sveikiname! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sėkmingai prisijungei prie poros!'),
            const SizedBox(height: 10),
            Text('👫 Poros vardas: $wifeName'),
            Text('🎭 Tavo rolė: $role'),
            const SizedBox(height: 15),
            Text(
              result['role'] == 'wife'
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text('Kraunamos meilės žinutės... 💕'),
              const SizedBox(height: 10),
              Text(
                'Diena: $_dayOfYear',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Lock Screen Love Widget'),
        actions: [
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
          IconButton(
            icon: const Icon(Icons.group),
            tooltip: 'Poros nustatymai',
            onPressed: _showCoupleDialog,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite, size: 100, color: Colors.pink),
              const SizedBox(height: 30),
              const Text(
                'Widget sukonfigūruotas!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                'Dabartinė žinutė:',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50, // Panaudojame .shade50
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.deepPurple.shade100,
                  ), // Panaudojame .shade100
                ),
                child: Text(
                  _currentMessage,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.deepPurple,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Diena: $_dayOfYear / 365',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _changeMessage,
                icon: const Icon(Icons.refresh),
                label: const Text('Keisti žinutę'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50, // Panaudojame .shade50
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Column(
                  children: [
                    Text(
                      'Pridėk widget į ekraną:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '1. Ilgai spausk lock/home screen',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '2. Pasirink "Widgets"',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '3. Rask "Lock Screen Love"',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
