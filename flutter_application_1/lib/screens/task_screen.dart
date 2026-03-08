import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../providers/providers.dart';

class TaskScreen extends StatelessWidget {
  const TaskScreen({super.key});
  void _showTaskDialog(BuildContext context, {UserTask? existing}) {
    final tController = TextEditingController(text: existing?.title);
    final dController = TextEditingController(text: existing?.description);
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))), builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('할 일 설정', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        TextField(controller: tController, decoration: const InputDecoration(hintText: '제목')),
        TextField(controller: dController, decoration: const InputDecoration(hintText: '내용')),
        const SizedBox(height: 30),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: () {
          if(tController.text.isNotEmpty) {
            final prov = context.read<TaskProvider>();
            final nt = UserTask(id: existing?.id ?? const Uuid().v4(), userId: context.read<AuthProvider>().currentUser!.uid, title: tController.text, description: dController.text, isCompleted: existing?.isCompleted ?? false);
            if(existing == null) prov.addTask(nt); else prov.updateTask(nt);
            Navigator.pop(context);
          }
        }, child: const Text('저장'))),
        const SizedBox(height: 30),
      ]),
    ));
  }
  @override
  Widget build(BuildContext context) {
    final a = context.watch<AuthProvider>();
    final p = context.watch<TaskProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('할 일', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
      body: StreamBuilder<List<UserTask>>(
        stream: p.getTaskStream(a.currentUser!.uid),
        builder: (context, snapshot) {
          final tasks = snapshot.data ?? [];
          if (tasks.isEmpty) return const Center(child: Text('할 일이 없습니다.'));
          
          // 정렬 로직 추가: 완료 여부(미완료 우선) -> 생성일(최신순)
          tasks.sort((a, b) {
            if (a.isCompleted != b.isCompleted) {
              return a.isCompleted ? 1 : -1;
            }
            return b.createdAt.compareTo(a.createdAt);
          });

          return ListView.builder(padding: const EdgeInsets.all(16), itemCount: tasks.length, itemBuilder: (c, i) {
            final t = tasks[i];
            return Dismissible(key: Key(t.id), onDismissed: (_)=>p.deleteTask(t.id), child: Card(child: ListTile(
              leading: Checkbox(value: t.isCompleted, onChanged: (_)=>p.toggleTask(t)),
              title: Text(t.title, style: TextStyle(decoration: t.isCompleted ? TextDecoration.lineThrough : null)),
              subtitle: t.description.isNotEmpty ? Text(t.description) : null,
              onTap: () => _showTaskDialog(context, existing: t),
            )));
          });
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showTaskDialog(context), child: const Icon(Icons.add)),
    );
  }
}
