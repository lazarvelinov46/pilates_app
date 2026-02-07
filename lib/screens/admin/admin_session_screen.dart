import 'package:flutter/material.dart';
import '../../services/session_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminSessionsScreen extends StatelessWidget {
  final SessionService _service = SessionService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Sessions')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // open create session dialog (later)
        },
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
                title: Text(s['startsAt'].toDate().toString()),
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
