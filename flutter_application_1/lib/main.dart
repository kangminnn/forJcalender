import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; 

// --------------------------------------------------------------------------
// 모델 정의
// --------------------------------------------------------------------------

class AppUser {
  final String uid;
  final String email;
  final String name;
  final List<String> friends;
  final List<String> incomingRequests;

  AppUser({
    required this.uid,
    required this.email, 
    required this.name,
    List<String>? friends,
    List<String>? incomingRequests,
  }) : friends = friends ?? [],
       incomingRequests = incomingRequests ?? [];

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'name': name,
    'friends': friends,
    'incomingRequests': incomingRequests,
  };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
    uid: map['uid'],
    email: map['email'],
    name: map['name'],
    friends: List<String>.from(map['friends'] ?? []),
    incomingRequests: List<String>.from(map['incomingRequests'] ?? []),
  );
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final String type;
  final String? senderEmail;
  final String? todoId; // 추가: 반응이 달린 일정 ID
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.senderEmail,
    this.todoId,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    'type': type,
    'senderEmail': senderEmail,
    'todoId': todoId,
    'isRead': isRead,
  };

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
    id: map['id'],
    title: map['title'],
    message: map['message'],
    timestamp: DateTime.parse(map['timestamp']),
    type: map['type'],
    senderEmail: map['senderEmail'],
    todoId: map['todoId'],
    isRead: map['isRead'] ?? false,
  );
}

class TodoCategory {
  final String id;
  final String label;
  final Color color;
  TodoCategory({required this.id, required this.label, required this.color});

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'color': color.value,
  };

  factory TodoCategory.fromJson(Map<String, dynamic> json) => TodoCategory(
    id: json['id'],
    label: json['label'],
    color: Color(json['color']),
  );
}

class Todo {
  final String id;
  final String userId;
  String title;
  String description;
  DateTime startDateTime;
  DateTime endDateTime;
  List<TodoCategory> categories;
  bool isCompleted;
  Map<String, String> reactions; // { 'userUid': 'emoji' }

  Todo({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    required this.startDateTime,
    required this.endDateTime,
    required this.categories,
    this.isCompleted = false,
    Map<String, String>? reactions,
  }) : reactions = reactions ?? {};

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'title': title,
    'description': description,
    'startDateTime': startDateTime.toIso8601String(),
    'endDateTime': endDateTime.toIso8601String(),
    'categories': categories.map((c) => c.toJson()).toList(),
    'isCompleted': isCompleted,
    'reactions': reactions,
  };

  factory Todo.fromMap(Map<String, dynamic> map) => Todo(
    id: map['id'],
    userId: map['userId'],
    title: map['title'],
    description: map['description'] ?? '',
    startDateTime: DateTime.parse(map['startDateTime']),
    endDateTime: DateTime.parse(map['endDateTime']),
    categories: (map['categories'] as List).map((c) => TodoCategory.fromJson(c)).toList(),
    isCompleted: map['isCompleted'] ?? false,
    reactions: Map<String, String>.from(map['reactions'] ?? {}),
  );
}

class UserTask {
  final String id;
  final String userId;
  String title;
  String description;
  bool isCompleted;

  UserTask({required this.id, required this.userId, required this.title, this.description = '', this.isCompleted = false});

  Map<String, dynamic> toMap() => {'id': id, 'userId': userId, 'title': title, 'description': description, 'isCompleted': isCompleted};
  factory UserTask.fromMap(Map<String, dynamic> map) => UserTask(id: map['id'], userId: map['userId'], title: map['title'], description: map['description'] ?? '', isCompleted: map['isCompleted'] ?? false);
}

// --------------------------------------------------------------------------
// 상태 관리 (Providers)
// --------------------------------------------------------------------------

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  ThemeProvider() { _loadTheme(); }
  void toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', _themeMode.toString());
  }
  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('themeMode');
    if (mode != null) {
      _themeMode = ThemeMode.values.firstWhere((e) => e.toString() == mode, orElse: () => ThemeMode.light);
      notifyListeners();
    }
  }
}

class AuthProvider extends ChangeNotifier {
  AppUser? _currentUser;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        final doc = await _db.collection('users').doc(user.uid).get();
        if (doc.exists) _currentUser = AppUser.fromMap(doc.data()!);
      } else { _currentUser = null; }
      notifyListeners();
    });
  }

  Future<String?> signUp(String email, String password, String name) async {
    try {
      final res = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      final newUser = AppUser(uid: res.user!.uid, email: email.trim(), name: name.trim());
      await _db.collection('users').doc(res.user!.uid).set(newUser.toMap());
      _currentUser = newUser;
      notifyListeners();
      return null;
    } catch (e) { return e.toString(); }
  }

  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      final doc = await _db.collection('users').doc(_auth.currentUser!.uid).get();
      if (doc.exists) {
        _currentUser = AppUser.fromMap(doc.data()!);
        notifyListeners();
        return null;
      }
      return '사용자 정보를 찾을 수 없습니다.';
    } catch (e) { return '로그인 정보가 틀렸습니다.'; }
  }

  void logout() async { await _auth.signOut(); _currentUser = null; notifyListeners(); }

  Future<String> sendFriendRequest(String targetName) async {
    try {
      if (targetName == _currentUser!.name) return '자기 자신에게는 요청을 보낼 수 없습니다.';
      final query = await _db.collection('users').where('name', isEqualTo: targetName).get();
      if (query.docs.isEmpty) return '사용자를 찾을 수 없습니다.';
      final target = AppUser.fromMap(query.docs.first.data());
      if (target.friends.contains(_currentUser!.email)) return '이미 친구입니다.';
      await _db.collection('users').doc(target.uid).update({'incomingRequests': FieldValue.arrayUnion([_currentUser!.email])});
      await _db.collection('notifications').add(AppNotification(id: const Uuid().v4(), title: '친구 요청', message: '${_currentUser!.name}님이 친구 요청을 보냈습니다.', timestamp: DateTime.now(), type: 'friend_request', senderEmail: _currentUser!.email).toMap()..addAll({'targetUid': target.uid}));
      return '성공';
    } catch (e) { return '실패: $e'; }
  }

  Future<String> acceptFriendRequest(String senderEmail) async {
    try {
      final query = await _db.collection('users').where('email', isEqualTo: senderEmail).get();
      if (query.docs.isEmpty) return '사용자를 찾을 수 없습니다.';
      final senderDoc = query.docs.first;
      await _db.runTransaction((tx) async {
        tx.update(_db.collection('users').doc(_currentUser!.uid), {'incomingRequests': FieldValue.arrayRemove([senderEmail]), 'friends': FieldValue.arrayUnion([senderEmail])});
        tx.update(senderDoc.reference, {'friends': FieldValue.arrayUnion([_currentUser!.email])});
      });
      await _db.collection('notifications').add(AppNotification(id: const Uuid().v4(), title: '친구 성사', message: '${_currentUser!.name}님과 친구가 되었습니다.', timestamp: DateTime.now(), type: 'friend_accepted', senderEmail: _currentUser!.email).toMap()..addAll({'targetUid': senderDoc.id}));
      await _db.collection('notifications').add(AppNotification(id: const Uuid().v4(), title: '친구 성사', message: '${AppUser.fromMap(senderDoc.data()).name}님과 친구가 되었습니다.', timestamp: DateTime.now(), type: 'friend_accepted', senderEmail: senderEmail).toMap()..addAll({'targetUid': _currentUser!.uid}));
      final updated = await _db.collection('users').doc(_currentUser!.uid).get();
      _currentUser = AppUser.fromMap(updated.data()!);
      notifyListeners();
      return '성공';
    } catch (e) { return '실패: $e'; }
  }

  Future<void> removeFriend(String friendEmail) async {
    final query = await _db.collection('users').where('email', isEqualTo: friendEmail).get();
    if (query.docs.isNotEmpty) {
      await _db.runTransaction((tx) async {
        tx.update(_db.collection('users').doc(_currentUser!.uid), {'friends': FieldValue.arrayRemove([friendEmail])});
        tx.update(query.docs.first.reference, {'friends': FieldValue.arrayRemove([_currentUser!.email])});
      });
      final updated = await _db.collection('users').doc(_currentUser!.uid).get();
      _currentUser = AppUser.fromMap(updated.data()!);
      notifyListeners();
    }
  }

  Future<String?> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return '로그인 필요';
      final todos = await _db.collection('todos').where('userId', isEqualTo: user.uid).get();
      for (var d in todos.docs) await d.reference.delete();
      final tasks = await _db.collection('tasks').where('userId', isEqualTo: user.uid).get();
      for (var d in tasks.docs) await d.reference.delete();
      await _db.collection('users').doc(user.uid).delete();
      await user.delete();
      _currentUser = null;
      notifyListeners();
      return null;
    } catch (e) { return e.toString(); }
  }
}

class NotificationProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Stream<List<AppNotification>> getNotificationStream(String uid) {
    return _db.collection('notifications').where('targetUid', isEqualTo: uid).snapshots().map((snap) {
      var list = snap.docs.map((doc) => AppNotification.fromMap(doc.data())).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }
  Future<void> markAsRead(String id) async {
    final q = await _db.collection('notifications').where('id', isEqualTo: id).get();
    if (q.docs.isNotEmpty) await q.docs.first.reference.update({'isRead': true});
  }
  Future<void> deleteAllNotifications(String uid) async {
    final q = await _db.collection('notifications').where('targetUid', isEqualTo: uid).get();
    final b = _db.batch();
    for (var d in q.docs) b.delete(d.reference);
    await b.commit();
  }
}

class TaskProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Stream<List<UserTask>> getTaskStream(String uid) => _db.collection('tasks').where('userId', isEqualTo: uid).snapshots().map((s) => s.docs.map((d) => UserTask.fromMap(d.data())).toList());
  Future<void> addTask(UserTask t) async => await _db.collection('tasks').doc(t.id).set(t.toMap());
  Future<void> updateTask(UserTask t) async => await _db.collection('tasks').doc(t.id).update(t.toMap());
  Future<void> deleteTask(String id) async => await _db.collection('tasks').doc(id).delete();
  Future<void> toggleTask(UserTask t) async => await _db.collection('tasks').doc(t.id).update({'isCompleted': !t.isCompleted});
}

class TodoProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<TodoCategory> _categories = [];
  List<TodoCategory> get categories => _categories;

  // 사용자별 카테고리 불러오기 (데이터 없으면 초기화)
  Future<void> loadCategories(String uid) async {
    try {
      final snapshot = await _db.collection('users').doc(uid).collection('categories').get();
      
      if (snapshot.docs.isEmpty) {
        // 기본 카테고리 초기 설정
        final defaultCats = [
          TodoCategory(id: '1', label: '업무', color: Colors.indigo),
          TodoCategory(id: '2', label: '개인', color: Colors.teal),
          TodoCategory(id: '3', label: '취미', color: Colors.orange),
        ];
        for (var cat in defaultCats) {
          await _db.collection('users').doc(uid).collection('categories').doc(cat.id).set(cat.toJson());
        }
        _categories = defaultCats;
      } else {
        _categories = snapshot.docs.map((doc) => TodoCategory.fromJson(doc.data())).toList();
      }
      notifyListeners();
    } catch (e) {
      print("카테고리 로딩 실패: $e");
    }
  }

  Stream<List<Todo>> getTodoStream(String uid) => _db.collection('todos').where('userId', isEqualTo: uid).snapshots().map((s) => s.docs.map((d) => Todo.fromMap(d.data())).toList());
  
  Future<void> addTodo(Todo t) async => await _db.collection('todos').doc(t.id).set(t.toMap());
  Future<void> updateTodo(Todo t) async => await _db.collection('todos').doc(t.id).update(t.toMap());
  Future<void> deleteTodo(String id) async => await _db.collection('todos').doc(id).delete();
  Future<void> toggleTodo(Todo t) async => await _db.collection('todos').doc(t.id).update({'isCompleted': !t.isCompleted});
  Future<void> addReaction(Todo todo, String senderUid, String senderName, String emoji) async {
    // 1. 이모지 업데이트
    await _db.collection('todos').doc(todo.id).update({'reactions.$senderUid': emoji});

    // 2. 일정 소유자에게 알림 전송 (본인이 본인에게 남긴 경우는 제외)
    if (todo.userId != senderUid) {
      await _db.collection('notifications').add(AppNotification(
        id: const Uuid().v4(),
        title: '새로운 반응',
        message: '$senderName님이 "${todo.title}" 일정에 $emoji 반응을 남겼습니다.',
        timestamp: DateTime.now(),
        type: 'emoji_reaction',
        senderEmail: senderName, // 여기서는 이름을 보냄
        todoId: todo.id,
      ).toMap()..addAll({'targetUid': todo.userId}));
    }
  }

  Future<void> addCategory(String uid, String label, Color color) async {
    final newCat = TodoCategory(id: const Uuid().v4(), label: label, color: color);
    await _db.collection('users').doc(uid).collection('categories').doc(newCat.id).set(newCat.toJson());
    _categories.add(newCat);
    notifyListeners();
  }

  Future<void> deleteCategory(String uid, String id) async {
    await _db.collection('users').doc(uid).collection('categories').doc(id).delete();
    _categories.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  List<Todo> filterTodosByDate(DateTime date, List<Todo> source) {
    final target = DateTime(date.year, date.month, date.day);
    return source.where((t) {
      final start = DateTime(t.startDateTime.year, t.startDateTime.month, t.startDateTime.day);
      final end = DateTime(t.endDateTime.year, t.endDateTime.month, t.endDateTime.day).add(const Duration(seconds: 1));
      return (target.isAtSameMomentAs(start) || (target.isAfter(start) && target.isBefore(end)));
    }).toList();
  }
}

// --------------------------------------------------------------------------
// 앱 메인 & UI
// --------------------------------------------------------------------------

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => TodoProvider()),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider(create: (_) => TaskProvider()),
    ],
    child: const CalendarApp(),
  ));
}

class CalendarApp extends StatelessWidget {
  const CalendarApp({super.key});
  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    return MaterialApp(
      debugShowCheckedModeBanner: false, title: 'J-Calendar', themeMode: tp.themeMode,
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, primary: Colors.indigo), scaffoldBackgroundColor: const Color(0xFFF5F7FA)),
      darkTheme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, primary: Colors.indigo, brightness: Brightness.dark)),
      home: context.watch<AuthProvider>().isAuthenticated ? const MainNavigationScreen() : const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final eController = TextEditingController();
  final pController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)])),
        child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(30), child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40), child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.calendar_today, size: 60, color: Colors.indigo),
            const SizedBox(height: 16),
            const Text('J-Calendar', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 40),
            TextField(controller: eController, decoration: InputDecoration(labelText: '이메일', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
            const SizedBox(height: 16),
            TextField(controller: pController, obscureText: true, decoration: InputDecoration(labelText: '비밀번호', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, height: 55, child: FilledButton(onPressed: () async {
              final err = await context.read<AuthProvider>().login(eController.text, pController.text);
              if(err != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
            }, child: const Text('로그인'))),
            TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c)=>const SignUpScreen())), child: const Text('계정 만들기')),
          ])),
        ))),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final nController = TextEditingController();
  final eController = TextEditingController();
  final pController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent), extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)])),
        child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(30), child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
            const Text('회원가입', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 30),
            TextField(controller: nController, decoration: InputDecoration(labelText: '이름', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
            const SizedBox(height: 16),
            TextField(controller: eController, decoration: InputDecoration(labelText: '이메일', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
            const SizedBox(height: 16),
            TextField(controller: pController, obscureText: true, decoration: InputDecoration(labelText: '비밀번호', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, height: 55, child: FilledButton(onPressed: () async {
              final err = await context.read<AuthProvider>().signUp(eController.text, pController.text, nController.text);
              if(err == null && mounted) Navigator.pop(context);
              else if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err!)));
            }, child: const Text('가입하기'))),
          ])),
        ))),
      ),
    );
  }
}

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

// --------------------------------------------------------------------------
// 공통 UI 컴포넌트
// --------------------------------------------------------------------------

void showAddEditTodoDialog(BuildContext context, {Todo? existing, DateTime? initial}) {
  final tController = TextEditingController(text: existing?.title);
  final dController = TextEditingController(text: existing?.description);
  final todoP = context.read<TodoProvider>();
  final authP = context.read<AuthProvider>();
  List<TodoCategory> selectedCats = List.from(existing?.categories ?? []);
  
  bool isAllDay = existing != null && 
                  existing.startDateTime.hour == 0 && existing.startDateTime.minute == 0 &&
                  existing.endDateTime.hour == 0 && existing.endDateTime.minute == 0;

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
                const Text('시간 미지정', style: TextStyle(fontSize: 12)),
                Switch(value: isAllDay, onChanged: (v)=>setModalState(()=>isAllDay=v)),
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
            ListTile(title: const Text('시작 날짜'), subtitle: Text(DateFormat('yyyy-MM-dd').format(start)), trailing: const Icon(Icons.calendar_today, size: 18), onTap: () async {
              final d = await showDatePicker(context: context, initialDate: start, firstDate: DateTime(2020), lastDate: DateTime(2030));
              if(d != null) setModalState(() => start = DateTime(d.year, d.month, d.day, start.hour, start.minute));
            }),
            if(!isAllDay) ListTile(title: const Text('시작 시간'), subtitle: Text(DateFormat('HH:mm').format(start)), trailing: const Icon(Icons.access_time, size: 18), onTap: () {
              showCupertinoModalPopup(context: context, builder: (_) => Container(height: 200, color: Colors.white, child: CupertinoDatePicker(mode: CupertinoDatePickerMode.time, initialDateTime: start, onDateTimeChanged: (d)=>setModalState(()=>start=DateTime(start.year, start.month, start.day, d.hour, d.minute)))));
            }),
            ListTile(title: const Text('종료 날짜'), subtitle: Text(DateFormat('yyyy-MM-dd').format(end)), trailing: const Icon(Icons.calendar_today, size: 18), onTap: () async {
              final d = await showDatePicker(context: context, initialDate: end, firstDate: DateTime(2020), lastDate: DateTime(2030));
              if(d != null) setModalState(() => end = DateTime(d.year, d.month, d.day, end.hour, end.minute));
            }),
            if(!isAllDay) ListTile(title: const Text('종료 시간'), subtitle: Text(DateFormat('HH:mm').format(end)), trailing: const Icon(Icons.access_time, size: 18), onTap: () {
              showCupertinoModalPopup(context: context, builder: (_) => Container(height: 200, color: Colors.white, child: CupertinoDatePicker(mode: CupertinoDatePickerMode.time, initialDateTime: end, onDateTimeChanged: (d)=>setModalState(()=>end=DateTime(end.year, end.month, end.day, d.hour, d.minute)))));
            }),
            const SizedBox(height: 30),
            SizedBox(width: double.infinity, height: 50, child: FilledButton(onPressed: () {
              if(tController.text.isNotEmpty) {
                final fs = isAllDay ? DateTime(start.year, start.month, start.day) : start;
                final fe = isAllDay ? DateTime(end.year, end.month, end.day).add(const Duration(days: 1)) : end;
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
            }, child: const Text('저장'))),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    ),
  );
}

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
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(DateFormat('MM월 dd일 일정').format(_selected!), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), if (isMe) IconButton.filledTonal(onPressed: () => _showTodoDialog(initial: _selected), icon: const Icon(Icons.add))]),
              const SizedBox(height: 10),
              Expanded(child: filtered.isEmpty ? const Center(child: Text('일정이 없습니다.')) : ListView.builder(itemCount: filtered.length, itemBuilder: (c, i) => TodoItemTile(todo: filtered[i], onTap: () => _showTodoDialog(existing: filtered[i]))))
            ])))
          ]);
        }
      ),
    );
  }
}

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});
  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
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
          final todos = (snapshot.data ?? []).where((t) => t.endDateTime.isAfter(now)).toList();
          todos.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
          if (todos.isEmpty) return const Center(child: Text('진행 중인 일정이 없습니다.'));
          return ListView.builder(padding: const EdgeInsets.all(16), itemCount: todos.length, itemBuilder: (c, i) => TodoItemTile(todo: todos[i], onTap: () {
            // 이 화면에서도 수정 가능하게 다이얼로그 호출 로직을 위해 CalendarScreen의 다이얼로그를 공통 위젯으로 뺄 필요가 있으나,
            // 여기서는 단순함을 위해 캘린더 탭으로 유도하거나 간단한 스낵바를 띄웁니다.
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('캘린더 탭에서 해당 날짜를 선택하여 수정할 수 있습니다.')));
          }));
        },
      ),
    );
  }
}

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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final ap = context.watch<AuthProvider>();
    final nController = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('앱 설정', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        Card(child: Column(children: [
          ListTile(leading: const Icon(Icons.dark_mode), title: const Text('다크 모드'), trailing: Switch(value: tp.themeMode == ThemeMode.dark, onChanged: (_)=>tp.toggleTheme())),
          ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('로그아웃'), onTap: (){ ap.logout(); Navigator.pop(context); }),
          ListTile(leading: const Icon(Icons.delete_forever, color: Colors.red), title: const Text('회원 탈퇴'), onTap: () async {
            final ok = await showDialog<bool>(context: context, builder: (c)=>AlertDialog(title: const Text('회원 탈퇴'), content: const Text('모든 데이터가 삭제됩니다.'), actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text('취소')), TextButton(onPressed: ()=>Navigator.pop(c,true), child: const Text('탈퇴', style: TextStyle(color: Colors.red)))]));
            if(ok==true) { await ap.deleteAccount(); Navigator.pop(context); }
          }),
        ])),
        const SizedBox(height: 30),
        const Text('친구 관리', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        Card(child: Column(children: [
          Padding(padding: const EdgeInsets.all(16), child: Row(children: [
            Expanded(child: TextField(controller: nController, decoration: const InputDecoration(hintText: '친구 이름 입력'))),
            IconButton(onPressed: () async { if(nController.text.isNotEmpty) { final m = await ap.sendFriendRequest(nController.text.trim()); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))); nController.clear(); } }, icon: const Icon(Icons.person_add))
          ])),
          if (ap.currentUser!.friends.isNotEmpty) FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance.collection('users').where('email', whereIn: ap.currentUser!.friends).get(),
            builder: (context, snap) {
              if(!snap.hasData) return const SizedBox();
              return Column(children: snap.data!.docs.map((d) {
                final f = AppUser.fromMap(d.data() as Map<String, dynamic>);
                return ListTile(title: Text(f.name), subtitle: Text(f.email), trailing: IconButton(icon: const Icon(Icons.person_remove, color: Colors.red), onPressed: ()=>ap.removeFriend(f.email)));
              }).toList());
            }
          )
        ]))
      ]),
    );
  }
}

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

class TodoItemTile extends StatelessWidget {
  final Todo todo;
  final VoidCallback onTap;
  const TodoItemTile({super.key, required this.todo, required this.onTap});
  @override
  Widget build(BuildContext context) {
    bool isAllDay = todo.startDateTime.hour == 0 && todo.startDateTime.minute == 0 && todo.endDateTime.hour == 0 && todo.endDateTime.minute == 0;
    final sStr = isAllDay ? DateFormat('M/d').format(todo.startDateTime) : DateFormat('M/d HH:mm').format(todo.startDateTime);
    final eStr = isAllDay ? DateFormat('M/d').format(todo.endDateTime.subtract(const Duration(seconds: 1))) : DateFormat('M/d HH:mm').format(todo.endDateTime);
    return Dismissible(key: Key(todo.id), onDismissed: (_)=>context.read<TodoProvider>().deleteTodo(todo.id), child: Card(
      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(onTap: onTap, title: Row(children: [
        Expanded(child: Text(todo.title, style: TextStyle(decoration: todo.isCompleted ? TextDecoration.lineThrough : null, fontWeight: FontWeight.bold))),
        if (todo.reactions.isNotEmpty) ...todo.reactions.values.take(3).map((e) => Padding(padding: const EdgeInsets.only(left: 4), child: Text(e, style: const TextStyle(fontSize: 12)))),
      ]), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (todo.description.isNotEmpty) Text(todo.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(isAllDay && todo.startDateTime.day == todo.endDateTime.subtract(const Duration(seconds: 1)).day ? sStr : '$sStr - $eStr', style: const TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.bold)),
      ])),
    ));
  }
}
