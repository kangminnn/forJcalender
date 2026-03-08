import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';
import 'notification_screen.dart';
import 'settings_screen.dart';

class CalendarScreen extends StatefulWidget {
  final AppUser? friend;
  const CalendarScreen({super.key, this.friend});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime? _selected;
  @override
  void initState() { super.initState(); _selected = _focused; }

  void _handleTodoTap({Todo? existing, DateTime? initial}) {
    if (widget.friend != null) {
      if (existing != null) _showEmojiPicker(existing);
      return;
    }
    showAddEditTodoDialog(context, existing: existing, initial: initial);
  }

  void _showEmojiPicker(Todo todo) {
    final emojis = ['👍', '❤️', '😊', '🔥', '👏', '😮'];
    final me = context.read<AuthProvider>().currentUser!;
    showModalBottomSheet(
      context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('반응 남기기', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: emojis.map((e) => GestureDetector(onTap: () {
            context.read<TodoProvider>().addReaction(todo, me.uid, me.name, e);
            Navigator.pop(context);
          }, child: Text(e, style: const TextStyle(fontSize: 30)))).toList()),
          const SizedBox(height: 20),
        ]),
      )
    );
  }

  void _showFriendList() {
    final u = context.read<AuthProvider>().currentUser!;
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))), builder: (context) => FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('users').where('email', whereIn: u.friends.isEmpty ? [''] : u.friends).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final friends = snapshot.data!.docs.map((d) => AppUser.fromMap(d.data() as Map<String, dynamic>)).toList();
        return Container(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('친구 목록', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          if (friends.isEmpty) const Text('친구가 없습니다.') else ...friends.map((f) => ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(f.name), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (c) => CalendarScreen(friend: f))); })),
          const SizedBox(height: 20),
        ]));
      }
    ));
  }

  @override
  Widget build(BuildContext context) {
    final authU = context.watch<AuthProvider>().currentUser;
    final user = widget.friend ?? authU;
    final isMe = widget.friend == null;
    final todoP = context.watch<TodoProvider>();
    return Scaffold(
      appBar: AppBar(
        title: InkWell(onTap: isMe ? _showFriendList : null, child: Row(mainAxisSize: MainAxisSize.min, children: [Text(user?.name ?? ''), if (isMe) const Icon(Icons.arrow_drop_down)])),
        centerTitle: true, actions: isMe ? [IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c)=>const NotificationScreen())), icon: const Icon(Icons.notifications)), IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c)=>const SettingsScreen())), icon: const Icon(Icons.settings))] : [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))],
      ),
      body: StreamBuilder<List<Todo>>(
        stream: todoP.getTodoStream(user!.uid),
        builder: (context, snapshot) {
          final all = snapshot.data ?? [];
          final filtered = todoP.filterTodosByDate(_selected ?? _focused, all);
          return Column(children: [
            if (!isMe) Container(width: double.infinity, color: Colors.indigo.withOpacity(0.1), padding: const EdgeInsets.symmetric(vertical: 8), child: const Text('친구의 일정 (반응을 남겨보세요)', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo))),
            TableCalendar(locale: 'ko_KR', firstDay: DateTime.utc(2020), lastDay: DateTime.utc(2030), focusedDay: _focused, selectedDayPredicate: (d)=>isSameDay(_selected, d), onDaySelected: (s, f)=>setState((){_selected=s; _focused=f;}), eventLoader: (d)=>todoP.filterTodosByDate(d, all), headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true)),
            Expanded(child: Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))), child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(DateFormat('MM월 dd일 일정').format(_selected!), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), if (isMe) IconButton.filledTonal(onPressed: () => _handleTodoTap(initial: _selected), icon: const Icon(Icons.add))]),
              const SizedBox(height: 10),
              Expanded(child: filtered.isEmpty ? const Center(child: Text('일정이 없습니다.')) : ListView.builder(itemCount: filtered.length, itemBuilder: (c, i) => TodoItemTile(todo: filtered[i], onTap: () => _handleTodoTap(existing: filtered[i]))))
            ])))
          ]);
        }
      ),
    );
  }
}
