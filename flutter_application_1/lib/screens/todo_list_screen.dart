import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});
  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  TodoCategory? _filter;
  final List<Color> _colorPalette = [Colors.red, Colors.pink, Colors.purple, Colors.deepPurple, Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan, Colors.teal, Colors.green, Colors.lightGreen, Colors.lime, Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange, Colors.brown, Colors.grey, Colors.blueGrey, Colors.black];

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    Color selectedColor = _colorPalette[0];
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setModalState) => AlertDialog(
      title: const Text('새 카테고리'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: controller, decoration: const InputDecoration(hintText: '이름 입력')),
        const SizedBox(height: 20),
        SizedBox(width: 300, child: Wrap(spacing: 8, runSpacing: 8, children: _colorPalette.map((color) => GestureDetector(onTap: () => setModalState(() => selectedColor = color), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: selectedColor == color ? Border.all(width: 3, color: Colors.white) : null, boxShadow: [if(selectedColor==color) const BoxShadow(color: Colors.black26, blurRadius: 4)])))).toList())),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')), FilledButton(onPressed: () { if(controller.text.isNotEmpty) { context.read<TodoProvider>().addCategory(context.read<AuthProvider>().currentUser!.uid, controller.text, selectedColor); Navigator.pop(context); } }, child: const Text('추가'))],
    )));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TodoProvider>();
    final a = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('전체 일정', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
      body: StreamBuilder<List<Todo>>(
        stream: p.getTodoStream(a.currentUser!.uid),
        builder: (context, snapshot) {
          final now = DateTime.now();
          var todos = (snapshot.data ?? []).where((t) => t.endDateTime.isAfter(now)).toList();
          if (_filter != null) todos = todos.where((t) => t.categories.any((c) => c.id == _filter!.id)).toList();
          todos.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

          return Column(
            children: [
              SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(children: [
                FilterChip(label: const Text('전체'), selected: _filter == null, onSelected: (v) => setState(() => _filter = null), showCheckmark: false),
                const SizedBox(width: 8),
                ...p.categories.map((c) => Padding(padding: const EdgeInsets.only(right: 8.0), child: GestureDetector(
                  onLongPress: () => showDialog(context: context, builder: (dc) => AlertDialog(title: const Text('카테고리 삭제'), content: Text('"${c.label}"을(를) 삭제하시겠습니까?'), actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('취소')), TextButton(onPressed: () { p.deleteCategory(a.currentUser!.uid, c.id); Navigator.pop(dc); }, child: const Text('삭제', style: TextStyle(color: Colors.red)))])),
                  child: FilterChip(label: Text(c.label), selected: _filter?.id == c.id, onSelected: (v) => setState(() => _filter = v ? c : null), selectedColor: c.color.withOpacity(0.3), showCheckmark: false),
                ))),
                IconButton.filledTonal(onPressed: _showAddCategoryDialog, icon: const Icon(Icons.add, size: 20)),
              ])),
              Expanded(child: todos.isEmpty ? const Center(child: Text('진행 중인 일정이 없습니다.')) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: todos.length, itemBuilder: (c, i) => TodoItemTile(todo: todos[i], onTap: () => showAddEditTodoDialog(context, existing: todos[i])))),
            ],
          );
        },
      ),
    );
  }
}
