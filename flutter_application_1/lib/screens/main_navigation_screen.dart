import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import 'calendar_screen.dart';
import 'todo_list_screen.dart';
import 'task_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _idx = 0;
  bool _initialized = false;
  final _screens = [const CalendarScreen(), const TodoListScreen(), const TaskScreen()];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) {
        context.read<TodoProvider>().loadCategories(user.uid);
        _initialized = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_idx],
      bottomNavigationBar: NavigationBar(selectedIndex: _idx, onDestinationSelected: (i)=>setState(()=>_idx=i), destinations: const [
        NavigationDestination(icon: Icon(Icons.calendar_month), label: '캘린더'),
        NavigationDestination(icon: Icon(Icons.checklist), label: '일정'),
        NavigationDestination(icon: Icon(Icons.task_alt), label: '할 일'),
      ]),
    );
  }
}
