import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/providers.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  void _showTodoDetails(BuildContext context, String todoId) async {
    final doc = await FirebaseFirestore.instance.collection('todos').doc(todoId).get();
    if (doc.exists && context.mounted) {
      final todo = Todo.fromMap(doc.data()!);
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(todo.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (todo.description.isNotEmpty) Text(todo.description),
              const SizedBox(height: 10),
              Text('일시: ${DateFormat('MM/dd HH:mm').format(todo.startDateTime)}', style: const TextStyle(fontSize: 12)),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('닫기'))],
        ),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제된 일정입니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AuthProvider>();
    final p = context.watch<NotificationProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('알림'), actions: [TextButton(onPressed: ()=>p.deleteAllNotifications(a.currentUser!.uid), child: const Text('전체 삭제', style: TextStyle(color: Colors.red)))]),
      body: StreamBuilder<List<AppNotification>>(
        stream: p.getNotificationStream(a.currentUser!.uid),
        builder: (context, snap) {
          final list = snap.data ?? [];
          if(list.isEmpty) return const Center(child: Text('알림이 없습니다.'));
          return ListView.builder(padding: const EdgeInsets.all(16), itemCount: list.length, itemBuilder: (c, i) {
            final n = list[i];
            return Card(
              color: n.isRead ? null : Colors.indigo.withOpacity(0.05),
              child: ListTile(
                title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                subtitle: Text(n.message),
                trailing: n.type == 'friend_request' && !a.currentUser!.friends.contains(n.senderEmail) ? TextButton(onPressed: () async { final m = await a.acceptFriendRequest(n.senderEmail!); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))); p.markAsRead(n.id); }, child: const Text('수락')) : null,
                onTap: () {
                  p.markAsRead(n.id);
                  if (n.todoId != null) {
                    _showTodoDetails(context, n.todoId!);
                  }
                },
              ),
            );
          });
        },
      ),
    );
  }
}
