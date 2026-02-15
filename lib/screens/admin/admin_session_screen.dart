import 'package:flutter/material.dart';
import '../../services/session_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminSessionsScreen extends StatelessWidget {
  final SessionService _service = SessionService();

  void _showCreateSessionDialog(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    DateTime? selectedDateTime;
    final capacityController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create New Session'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: capacityController,
                decoration: const InputDecoration(labelText: 'Capacity'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || int.tryParse(v) == null) {
                    return 'Enter valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                child: Text(selectedDateTime == null
                    ? 'Select Date & Time'
                    : selectedDateTime.toString()),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date == null) return;

                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time == null) return;

                  selectedDateTime =
                      DateTime(date.year, date.month, date.day, time.hour, time.minute);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('Create'),
            onPressed: () async {
              if (_formKey.currentState!.validate() && selectedDateTime != null) {
                await _service.createSession(
                  startsAt: selectedDateTime!,
                  capacity: int.parse(capacityController.text),
                );
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Sessions')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateSessionDialog(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('sessions')
            .orderBy('startsAt')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final sessions = snapshot.data!.docs;

          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (_, i) {
              final s = sessions[i];
              return ListTile(
                title: Text(DateFormat('EEE, dd MMM • HH:mm').format(s['startsAt'].toDate())),
                subtitle: Text(
                  'Capacity: ${s['capacity']} | Booked: ${s['bookedCount']}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.block),
                  onPressed: () => _service.deactivateSession(s.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
