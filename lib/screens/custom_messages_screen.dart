import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../services/message_service.dart';
import '../services/couple_service.dart';

class CustomMessagesScreen extends StatefulWidget {
  const CustomMessagesScreen({super.key});

  @override
  State<CustomMessagesScreen> createState() => _CustomMessagesScreenState();
}

class _CustomMessagesScreenState extends State<CustomMessagesScreen> {
  final String _loggerName = 'CustomMessagesScreen';
  bool _isLoading = true;
  bool _canWrite = false;
  String _creatorName = '';

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      // Patikrinti ar gali rašyti
      _canWrite = await MessageService.canUserWriteMessages();

      // Gauti poros informaciją
      final couple = await CoupleService.getCurrentCouple();
      _creatorName = couple?['creatorName'] as String? ?? '';

      developer.log('🔑 Vartotojas gali rašyti: $_canWrite', name: _loggerName);
      developer.log('👤 Rašytojas: $_creatorName', name: _loggerName);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      developer.log(
        '❌ Klaida tikrinant permissions: $e',
        name: _loggerName,
        level: 1000,
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mano tekstai')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // 🔥 JEI NEGALI RAŠYTI - RODOME ERROR SCREEN
    if (!_canWrite) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mano tekstai')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, size: 100, color: Colors.grey),
              const SizedBox(height: 20),
              const Text(
                'Neturite prieigos 😔',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Tik rašytojas ($_creatorName) gali matyti šį ekraną',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Grįžti atgal'),
              ),
            ],
          ),
        ),
      );
    }

    // 🔥 JEI GALI RAŠYTI - RODOME NORMALŲ EKRANĄ
    return Scaffold(
      appBar: AppBar(title: const Text('Mano tekstai ✍️')),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    // Čia tavo esama custom messages logika
    return const Center(child: Text('Custom messages screen content'));
  }
}
