import 'package:flutter/material.dart';
import '../data/custom_messages.dart';
import '../data/messages.dart';

class CustomMessagesScreen extends StatefulWidget {
  const CustomMessagesScreen({super.key});

  @override
  State<CustomMessagesScreen> createState() => _CustomMessagesScreenState();
}

class _CustomMessagesScreenState extends State<CustomMessagesScreen> {
  final TextEditingController _messageController = TextEditingController();
  int _selectedDay = 1;
  Map<String, String> _customMessages = {};

  @override
  void initState() {
    super.initState();
    _loadCustomMessages();
  }

  Future<void> _loadCustomMessages() async {
    final messages = await CustomMessages.getAllCustomMessages();
    setState(() {
      _customMessages = messages;
    });
  }

  Future<void> _saveMessage() async {
    if (_messageController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Įrašyk tekstą!')));
      return;
    }

    // 🔥 DABAR TIK Į LOCAL STORAGE - ji automatiškai sinchronizuoja su Firebase
    await CustomMessages.saveCustomMessage(
      _selectedDay,
      _messageController.text,
    );
    _messageController.clear();
    await _loadCustomMessages();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Žinutė išsaugota ir nusiųsta partneriui!')),
    );
  }

  Future<void> _deleteMessage(int day) async {
    await CustomMessages.deleteCustomMessage(day);
    await _loadCustomMessages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mano Tekstai'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Forma pridėti naują tekstą
          Container(
            padding: EdgeInsets.all(20),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pridėti naują tekstą:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 15),

                // Dienos pasirinkimas
                Row(
                  children: [
                    Text('Diena: '),
                    SizedBox(width: 10),
                    DropdownButton<int>(
                      value: _selectedDay,
                      items: List.generate(365, (index) {
                        int day = index + 1;
                        return DropdownMenuItem(
                          value: day,
                          child: Text('$day'),
                        );
                      }),
                      onChanged: (value) {
                        setState(() {
                          _selectedDay = value!;
                        });
                      },
                    ),
                    SizedBox(width: 20),
                    Text(
                      'Default: "${DailyMessages.getMessageForDay(_selectedDay)}"',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),

                SizedBox(height: 10),

                // Teksto laukas
                TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Įrašyk savo tekstą...',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: 2,
                ),

                SizedBox(height: 10),

                // Išsaugoti mygtukas
                ElevatedButton.icon(
                  onPressed: _saveMessage,
                  icon: Icon(Icons.save),
                  label: Text('Išsaugoti'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Sąrašas custom tekstų
          Expanded(
            child: _customMessages.isEmpty
                ? Center(
                    child: Text(
                      'Dar nėra custom tekstų.\nPridėk pirmąjį! 💕',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _customMessages.length,
                    itemBuilder: (context, index) {
                      String dayStr = _customMessages.keys.elementAt(index);
                      String message = _customMessages[dayStr]!;
                      int day = int.parse(dayStr);

                      return Card(
                        margin: EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 5,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.pink,
                            child: Text(
                              '$day',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(message),
                          subtitle: Text('Diena $day'),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteMessage(day),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
