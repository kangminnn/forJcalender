import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../providers/providers.dart';

void showAddEditTodoDialog(BuildContext context, {Todo? existing, DateTime? initial}) {
  final tController = TextEditingController(text: existing?.title);
  final dController = TextEditingController(text: existing?.description);
  final todoP = context.read<TodoProvider>();
  final authP = context.read<AuthProvider>();
  List<TodoCategory> selectedCats = List.from(existing?.categories ?? []);
  
  // '시간 지정' 여부: 기존 일정이 00:00:00이 아니면 지정된 것으로 판단, 기본값은 false(미지정)
  bool isTimeEnabled = existing != null && 
                      !(existing.startDateTime.hour == 0 && existing.startDateTime.minute == 0 &&
                        existing.endDateTime.hour == 0 && existing.endDateTime.minute == 0);

  DateTime start = existing?.startDateTime ?? initial ?? DateTime.now();
  DateTime end = existing?.endDateTime ?? start.add(const Duration(hours: 1));

  showModalBottomSheet(
    context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(existing == null ? '일정 추가' : '일정 수정', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Row(children: [
                const Text('시간 지정', style: TextStyle(fontSize: 12)),
                Switch(value: isTimeEnabled, onChanged: (v)=>setModalState(()=>isTimeEnabled=v)),
              ]),
            ]),
            const SizedBox(height: 20),
            TextField(controller: tController, decoration: const InputDecoration(hintText: '제목')),
            TextField(controller: dController, decoration: const InputDecoration(hintText: '내용')),
            const SizedBox(height: 20),
            const Text('카테고리', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: todoP.categories.map((cat) => FilterChip(
              label: Text(cat.label), 
              selected: selectedCats.any((c) => c.id == cat.id), 
              onSelected: (v) => setModalState(() { if(v) selectedCats.add(cat); else selectedCats.removeWhere((c) => c.id == cat.id); }),
              selectedColor: cat.color.withOpacity(0.3),
            )).toList()),
            const SizedBox(height: 20),
            const Text('시작 일시', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(DateFormat('yyyy-MM-dd').format(start)),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: start, firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if(d != null) setModalState(() => start = DateTime(d.year, d.month, d.day, start.hour, start.minute));
                    },
                  ),
                ),
                if(isTimeEnabled) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(DateFormat('HH:mm').format(start)),
                      trailing: const Icon(Icons.access_time, size: 18),
                      onTap: () {
                        showCupertinoModalPopup(context: context, builder: (_) => Container(height: 200, color: Colors.white, child: CupertinoDatePicker(mode: CupertinoDatePickerMode.time, initialDateTime: start, onDateTimeChanged: (d)=>setModalState(()=>start=DateTime(start.year, start.month, start.day, d.hour, d.minute)))));
                      },
                    ),
                  ),
                ],
              ],
            ),
            const Divider(height: 1),
            const SizedBox(height: 10),
            const Text('종료 일시', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(DateFormat('yyyy-MM-dd').format(end)),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: end, firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if(d != null) setModalState(() => end = DateTime(d.year, d.month, d.day, end.hour, end.minute));
                    },
                  ),
                ),
                if(isTimeEnabled) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(DateFormat('HH:mm').format(end)),
                      trailing: const Icon(Icons.access_time, size: 18),
                      onTap: () {
                        showCupertinoModalPopup(context: context, builder: (_) => Container(height: 200, color: Colors.white, child: CupertinoDatePicker(mode: CupertinoDatePickerMode.time, initialDateTime: end, onDateTimeChanged: (d)=>setModalState(()=>end=DateTime(end.year, end.month, end.day, d.hour, d.minute)))));
                      },
                    ),
                  ),
                ],
              ],
            ),
            const Divider(height: 1),
            const SizedBox(height: 30),
            Row(
              children: [
                if(existing != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('일정 삭제'),
                            content: const Text('이 일정을 삭제하시겠습니까?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
                              TextButton(
                                onPressed: () {
                                  todoP.deleteTodo(existing.id);
                                  Navigator.pop(context); // 팝업 닫기
                                  Navigator.pop(context); // 다이얼로그 닫기
                                },
                                child: const Text('삭제', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('삭제'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () {
                      if(tController.text.isNotEmpty) {
                        // 시간 지정이 꺼져 있으면 00:00:00 으로 저장
                        final fs = isTimeEnabled ? start : DateTime(start.year, start.month, start.day);
                        final fe = isTimeEnabled ? end : DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
                        final nt = Todo(
                          id: existing?.id ?? const Uuid().v4(), 
                          userId: authP.currentUser!.uid, 
                          title: tController.text, 
                          description: dController.text, 
                          startDateTime: fs, 
                          endDateTime: fe, 
                          categories: selectedCats, 
                          isCompleted: existing?.isCompleted ?? false, 
                          reactions: existing?.reactions
                        );
                        if(existing == null) todoP.addTodo(nt); else todoP.updateTodo(nt);
                        Navigator.pop(context);
                      }
                    },
                    child: Text(existing == null ? '저장' : '수정 완료'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    ),
  );
}

class TodoItemTile extends StatelessWidget {
  final Todo todo;
  final VoidCallback onTap;
  const TodoItemTile({super.key, required this.todo, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final authP = context.read<AuthProvider>();
    final isMe = todo.userId == authP.currentUser?.uid;
    
    bool isAllDay = todo.startDateTime.hour == 0 && todo.startDateTime.minute == 0 && todo.endDateTime.hour == 0 && todo.endDateTime.minute == 0;
    final sStr = isAllDay ? DateFormat('M/d').format(todo.startDateTime) : DateFormat('M/d HH:mm').format(todo.startDateTime);
    final eStr = isAllDay ? DateFormat('M/d').format(todo.endDateTime.subtract(const Duration(seconds: 1))) : DateFormat('M/d HH:mm').format(todo.endDateTime);
    
    Widget content = Card(
      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(onTap: onTap, title: Row(children: [
        Expanded(child: Text(todo.title, style: TextStyle(decoration: todo.isCompleted ? TextDecoration.lineThrough : null, fontWeight: FontWeight.bold))),
        if (todo.reactions.isNotEmpty) ...todo.reactions.values.take(3).map((e) => Padding(padding: const EdgeInsets.only(left: 4), child: Text(e, style: const TextStyle(fontSize: 12)))),
      ]), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (todo.description.isNotEmpty) Text(todo.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(isAllDay && todo.startDateTime.day == todo.endDateTime.subtract(const Duration(seconds: 1)).day ? sStr : '$sStr - $eStr', style: const TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.bold)),
      ])),
    );

    if (!isMe) return content;

    return Dismissible(
      key: Key(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(15)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('일정 삭제'),
            content: const Text('이 일정을 삭제하시겠습니까?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
            ],
          ),
        );
      },
      onDismissed: (_) => context.read<TodoProvider>().deleteTodo(todo.id),
      child: content,
    );
  }
}
