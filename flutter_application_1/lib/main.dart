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
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.senderEmail,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    'type': type,
    'senderEmail': senderEmail,
    'isRead': isRead,
  };

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
    id: map['id'],
    title: map['title'],
    message: map['message'],
    timestamp: DateTime.parse(map['timestamp']),
    type: map['type'],
    senderEmail: map['senderEmail'],
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

  Todo({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    required this.startDateTime,
    required this.endDateTime,
    required this.categories,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'title': title,
    'description': description,
    'startDateTime': startDateTime.toIso8601String(),
    'endDateTime': endDateTime.toIso8601String(),
    'categories': categories.map((c) => c.toJson()).toList(),
    'isCompleted': isCompleted,
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
  );
}

// --------------------------------------------------------------------------
// 상태 관리 (Providers)
// --------------------------------------------------------------------------

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme();
  }

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
        if (doc.exists) {
          _currentUser = AppUser.fromMap(doc.data()!);
        }
      } else {
        _currentUser = null;
      }
      notifyListeners();
    });
  }

  Future<String?> signUp(String email, String password, String name) async {
    try {
      final res = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final newUser = AppUser(uid: res.user!.uid, email: email, name: name);
      await _db.collection('users').doc(res.user!.uid).set(newUser.toMap());
      _currentUser = newUser;
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      final res = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final doc = await _db.collection('users').doc(res.user!.uid).get();
      if (doc.exists) {
        _currentUser = AppUser.fromMap(doc.data()!);
        notifyListeners();
        return null;
      }
      return '사용자 정보를 찾을 수 없습니다.';
    } catch (e) {
      return '이메일 또는 비밀번호가 틀렸습니다.';
    }
  }

  void logout() async {
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<String> sendFriendRequest(String targetName) async {
    try {
      if (targetName == _currentUser!.name) return '자기 자신에게는 요청을 보낼 수 없습니다.';

      final query = await _db.collection('users').where('name', isEqualTo: targetName).get();
      if (query.docs.isEmpty) return '해당 이름을 가진 사용자를 찾을 수 없습니다.';
      
      final targetDoc = query.docs.first;
      final target = AppUser.fromMap(targetDoc.data());
      
      if (target.friends.contains(_currentUser!.email)) return '이미 친구 사이입니다.';
      if (target.incomingRequests.contains(_currentUser!.email)) return '이미 요청을 보냈습니다.';

      await _db.collection('users').doc(target.uid).update({
        'incomingRequests': FieldValue.arrayUnion([_currentUser!.email])
      });

      await _db.collection('notifications').add(AppNotification(
        id: const Uuid().v4(),
        title: '친구 요청',
        message: '${_currentUser!.name}님이 친구 요청을 보냈습니다.',
        timestamp: DateTime.now(),
        type: 'friend_request',
        senderEmail: _currentUser!.email,
      ).toMap()..addAll({'targetUid': target.uid}));
      
      return '성공';
    } catch (e) {
      return '요청 전송 실패: $e';
    }
  }

  Future<String> acceptFriendRequest(String senderEmail) async {
    try {
      final senderQuery = await _db.collection('users').where('email', isEqualTo: senderEmail).get();
      if (senderQuery.docs.isEmpty) return '보낸 사용자를 찾을 수 없습니다.';
      final senderDoc = senderQuery.docs.first;
      final senderData = AppUser.fromMap(senderDoc.data());
      final senderUid = senderDoc.id;
      
      await _db.runTransaction((transaction) async {
        transaction.update(_db.collection('users').doc(_currentUser!.uid), {
          'incomingRequests': FieldValue.arrayRemove([senderEmail]),
          'friends': FieldValue.arrayUnion([senderEmail])
        });
        transaction.update(senderDoc.reference, {
          'friends': FieldValue.arrayUnion([_currentUser!.email])
        });
      });

      // 상대방에게 알림 전송
      await _db.collection('notifications').add(AppNotification(
        id: const Uuid().v4(),
        title: '친구 성사',
        message: '${_currentUser!.name}님과 친구가 되었습니다.',
        timestamp: DateTime.now(),
        type: 'friend_accepted',
        senderEmail: _currentUser!.email,
      ).toMap()..addAll({'targetUid': senderUid}));

      // 나에게 알림 전송
      await _db.collection('notifications').add(AppNotification(
        id: const Uuid().v4(),
        title: '친구 성사',
        message: '${senderData.name}님과 친구가 되었습니다.',
        timestamp: DateTime.now(),
        type: 'friend_accepted',
        senderEmail: senderEmail,
      ).toMap()..addAll({'targetUid': _currentUser!.uid}));
      
      final updated = await _db.collection('users').doc(_currentUser!.uid).get();
      _currentUser = AppUser.fromMap(updated.data()!);
      notifyListeners();
      return '성공';
    } catch (e) {
      return '수락 실패: $e';
    }
  }

  Future<void> removeFriend(String friendEmail) async {
    try {
      final friendQuery = await _db.collection('users').where('email', isEqualTo: friendEmail).get();
      if (friendQuery.docs.isEmpty) return;
      final friendDoc = friendQuery.docs.first;

      await _db.runTransaction((transaction) async {
        transaction.update(_db.collection('users').doc(_currentUser!.uid), {
          'friends': FieldValue.arrayRemove([friendEmail])
        });
        transaction.update(friendDoc.reference, {
          'friends': FieldValue.arrayRemove([_currentUser!.email])
        });
      });

      final updated = await _db.collection('users').doc(_currentUser!.uid).get();
      _currentUser = AppUser.fromMap(updated.data()!);
      notifyListeners();
    } catch (_) {}
  }

  Future<String?> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return '로그인 정보가 없습니다.';

      // 1. 모든 일정 삭제
      final todos = await _db.collection('todos').where('userId', isEqualTo: user.uid).get();
      for (var doc in todos.docs) await doc.reference.delete();

      // 2. 모든 알림 삭제
      final notifs = await _db.collection('notifications').where('targetUid', isEqualTo: user.uid).get();
      for (var doc in notifs.docs) await doc.reference.delete();

      // 3. 친구들의 목록에서 나를 제거
      for (var friendEmail in _currentUser!.friends) {
        final fQuery = await _db.collection('users').where('email', isEqualTo: friendEmail).get();
        if (fQuery.docs.isNotEmpty) {
          await fQuery.docs.first.reference.update({
            'friends': FieldValue.arrayRemove([_currentUser!.email])
          });
        }
      }

      // 4. 사용자 문서 삭제 및 계정 삭제
      await _db.collection('users').doc(user.uid).delete();
      await user.delete();
      
      _currentUser = null;
      notifyListeners();
      return null;
    } catch (e) {
      return '회원 탈퇴 실패: $e (최근 로그인 기록이 필요할 수 있습니다.)';
    }
  }
}

class NotificationProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<AppNotification>> getNotificationStream(String uid) {
    return _db.collection('notifications')
        .where('targetUid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          var list = snap.docs.map((doc) => AppNotification.fromMap(doc.data())).toList();
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return list;
        });
  }

  Future<void> markAsRead(String notifId) async {
    final query = await _db.collection('notifications').where('id', isEqualTo: notifId).get();
    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.update({'isRead': true});
    }
  }

  Future<void> deleteAllNotifications(String uid) async {
    final query = await _db.collection('notifications').where('targetUid', isEqualTo: uid).get();
    final batch = _db.batch();
    for (var doc in query.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

class TodoProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<TodoCategory> _categories = [
    TodoCategory(id: '1', label: '업무', color: Colors.indigo),
    TodoCategory(id: '2', label: '개인', color: Colors.teal),
    TodoCategory(id: '3', label: '취미', color: Colors.orange),
  ];
  
  List<TodoCategory> get categories => _categories;

  TodoProvider() {
    _loadCategories();
  }

  void _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('categories');
    if (json != null) {
      _categories = (jsonDecode(json) as List).map((c) => TodoCategory.fromJson(c)).toList();
      notifyListeners();
    }
  }

  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('categories', jsonEncode(_categories.map((c) => c.toJson()).toList()));
  }

  Stream<List<Todo>> getTodoStream(String uid) {
    return _db.collection('todos')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Todo.fromMap(doc.data())).toList());
  }

  Future<void> addTodo(Todo todo) async {
    await _db.collection('todos').doc(todo.id).set(todo.toMap());
  }

  Future<void> updateTodo(Todo todo) async {
    await _db.collection('todos').doc(todo.id).update(todo.toMap());
  }

  Future<void> deleteTodo(String id) async {
    await _db.collection('todos').doc(id).delete();
  }

  Future<void> toggleTodo(Todo todo) async {
    await _db.collection('todos').doc(todo.id).update({'isCompleted': !todo.isCompleted});
  }

  void addCategory(String label, Color color) {
    _categories.add(TodoCategory(id: const Uuid().v4(), label: label, color: color));
    _saveCategories();
    notifyListeners();
  }

  void deleteCategory(String id) {
    _categories.removeWhere((c) => c.id == id);
    _saveCategories();
    notifyListeners();
  }

  List<Todo> filterTodosByDate(DateTime date, List<Todo> source) {
    final target = DateTime(date.year, date.month, date.day);
    return source.where((t) {
      final start = DateTime(t.startDateTime.year, t.startDateTime.month, t.startDateTime.day);
      final end = DateTime(t.endDateTime.year, t.endDateTime.month, t.endDateTime.day);
      return (target.isAtSameMomentAs(start) || target.isAtSameMomentAs(end)) ||
             (target.isAfter(start) && target.isBefore(end));
    }).toList();
  }
}

// --------------------------------------------------------------------------
// 메인 앱
// --------------------------------------------------------------------------

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    print("Firebase initialization failed: $e");
  }

  await initializeDateFormatting();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TodoProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const CalendarApp(),
    ),
  );
}

class CalendarApp extends StatelessWidget {
  const CalendarApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'J-Calendar',
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, primary: Colors.indigo, brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, primary: Colors.indigo, brightness: Brightness.dark),
      ),
      home: context.watch<AuthProvider>().isAuthenticated ? const MainNavigationScreen() : const LoginScreen(),
    );
  }
}

// --------------------------------------------------------------------------
// 로그인 & 회원가입 화면
// --------------------------------------------------------------------------

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30.0),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 60, color: Colors.indigo),
                    const SizedBox(height: 16),
                    const Text('J-Calendar', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.indigo)),
                    const SizedBox(height: 8),
                    Text('당신의 하루를 기록하세요', style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 40),
                    TextField(controller: emailController, decoration: InputDecoration(labelText: '이메일', prefixIcon: const Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
                    const SizedBox(height: 16),
                    TextField(controller: passwordController, obscureText: true, decoration: InputDecoration(labelText: '비밀번호', prefixIcon: const Icon(Icons.lock_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity, height: 55,
                      child: FilledButton(onPressed: () async {
                        final err = await context.read<AuthProvider>().login(emailController.text, passwordController.text);
                        if(err != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.redAccent));
                      }, style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: const Text('로그인', style: TextStyle(fontSize: 18))),
                    ),
                    const SizedBox(height: 16),
                    TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c)=>const SignUpScreen())), child: const Text('새로운 계정 만들기')),
                  ],
                ),
              ),
            ),
          ),
        ),
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
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF667EEA), Color(0xFF764BA2)])),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Card(
              elevation: 10, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text('회원가입', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo)),
                    const SizedBox(height: 30),
                    TextField(controller: nameController, decoration: InputDecoration(labelText: '이름', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
                    const SizedBox(height: 16),
                    TextField(controller: emailController, decoration: InputDecoration(labelText: '이메일', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
                    const SizedBox(height: 16),
                    TextField(controller: passwordController, obscureText: true, decoration: InputDecoration(labelText: '비밀번호', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
                    const SizedBox(height: 32),
                    SizedBox(width: double.infinity, height: 55, child: FilledButton(onPressed: () async {
                      final err = await context.read<AuthProvider>().signUp(emailController.text, passwordController.text, nameController.text);
                      if(err == null && mounted) Navigator.pop(context);
                      else if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err!)));
                    }, child: const Text('가입하기'))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// 메인 내비게이션
// --------------------------------------------------------------------------

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [const CalendarScreen(), const TodoListScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: '캘린더'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined), label: '할 일'),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// 캘린더 화면
// --------------------------------------------------------------------------

class CalendarScreen extends StatefulWidget {
  final AppUser? friend;
  const CalendarScreen({super.key, this.friend});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() { super.initState(); _selectedDay = _focusedDay; }

  void _showTodoDialog({Todo? existingTodo, DateTime? initialDate}) {
    if (widget.friend != null) return;

    final titleController = TextEditingController(text: existingTodo?.title);
    final descController = TextEditingController(text: existingTodo?.description);
    List<TodoCategory> selectedCategories = List.from(existingTodo?.categories ?? []);
    DateTime start = existingTodo?.startDateTime ?? initialDate ?? DateTime.now();
    DateTime end = existingTodo?.endDateTime ?? start.add(const Duration(hours: 1));
    String? validationError; 

    Future<void> pickDate(bool isStart, StateSetter setModalState) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: isStart ? start : end,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      if (picked != null) {
        setModalState(() {
          if (isStart) {
            start = DateTime(picked.year, picked.month, picked.day, start.hour, start.minute);
          } else {
            end = DateTime(picked.year, picked.month, picked.day, end.hour, end.minute);
          }
          validationError = null;
        });
      }
    }

    void pickTime(bool isStart, StateSetter setModalState) {
      showCupertinoModalPopup(
        context: context,
        builder: (_) => Container(
          height: 300, color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 216,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: isStart ? start : end,
                    onDateTimeChanged: (d) => setModalState(() {
                      if (isStart) {
                        start = DateTime(start.year, start.month, start.day, d.hour, d.minute);
                      } else {
                        end = DateTime(end.year, end.month, end.day, d.hour, d.minute);
                      }
                      validationError = null;
                    }),
                  ),
                ),
                CupertinoButton(child: const Text('확인'), onPressed: () => Navigator.pop(context))
              ],
            ),
          ),
        ),
      );
    }

    showModalBottomSheet(
      context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('일정 설정', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(controller: titleController, decoration: InputDecoration(hintText: '일정 제목', filled: true, fillColor: Theme.of(context).brightness == Brightness.light ? Colors.grey[100] : Colors.grey[800], border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
                const SizedBox(height: 12),
                TextField(controller: descController, maxLines: 3, decoration: InputDecoration(hintText: '상세 내용', filled: true, fillColor: Theme.of(context).brightness == Brightness.light ? Colors.grey[100] : Colors.grey[800], border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
                const SizedBox(height: 20),
                const Text('시작 일시', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                Row(
                  children: [
                    Expanded(child: ListTile(contentPadding: EdgeInsets.zero, title: Text(DateFormat('yyyy.MM.dd').format(start)), trailing: const Icon(Icons.calendar_today, size: 18), onTap: () => pickDate(true, setModalState))),
                    Expanded(child: ListTile(contentPadding: EdgeInsets.zero, title: Text(DateFormat('HH:mm').format(start)), trailing: const Icon(Icons.access_time, size: 18), onTap: () => pickTime(true, setModalState))),
                  ],
                ),
                const Divider(height: 1),
                const SizedBox(height: 10),
                const Text('종료 일시', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                Row(
                  children: [
                    Expanded(child: ListTile(contentPadding: EdgeInsets.zero, title: Text(DateFormat('yyyy.MM.dd').format(end)), trailing: const Icon(Icons.calendar_today, size: 18), onTap: () => pickDate(false, setModalState))),
                    Expanded(child: ListTile(contentPadding: EdgeInsets.zero, title: Text(DateFormat('HH:mm').format(end)), trailing: const Icon(Icons.access_time, size: 18), onTap: () => pickTime(false, setModalState))),
                  ],
                ),
                const Divider(height: 1),
                const SizedBox(height: 20),
                const Text('카테고리 (중복 선택 가능)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, 
                  children: context.read<TodoProvider>().categories.map((cat) {
                    final isSelected = selectedCategories.any((c) => c.id == cat.id);
                    return FilterChip(
                      label: Text(cat.label), 
                      selected: isSelected, 
                      onSelected: (v) {
                        setModalState(() {
                          if (v) selectedCategories.add(cat);
                          else selectedCategories.removeWhere((c) => c.id == cat.id);
                        });
                      }, 
                      selectedColor: cat.color.withOpacity(0.3),
                      showCheckmark: true,
                    );
                  }).toList()
                ),
                const SizedBox(height: 20),
                if (validationError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(validationError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                Row(
                  children: [
                    if(existingTodo != null) Expanded(child: OutlinedButton(onPressed: () { context.read<TodoProvider>().deleteTodo(existingTodo.id); Navigator.pop(context); }, style: OutlinedButton.styleFrom(foregroundColor: Colors.red), child: const Text('삭제'))),
                    if(existingTodo != null) const SizedBox(width: 10),
                    Expanded(flex: 2, child: FilledButton(onPressed: () {
                      if (end.isBefore(start)) {
                        setModalState(() => validationError = '시작 시간은 종료 시간 이전이어야 합니다.');
                        return;
                      }
                      if(titleController.text.isNotEmpty) {
                        final user = context.read<AuthProvider>().currentUser!;
                        final newTodo = Todo(id: existingTodo?.id ?? const Uuid().v4(), userId: user.uid, title: titleController.text, description: descController.text, startDateTime: start, endDateTime: end, categories: selectedCategories, isCompleted: existingTodo?.isCompleted ?? false);
                        if(existingTodo == null) context.read<TodoProvider>().addTodo(newTodo);
                        else context.read<TodoProvider>().updateTodo(newTodo);
                        Navigator.pop(context);
                      }
                    }, child: Text(existingTodo == null ? '저장' : '수정 완료'))),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFriendList(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser!;
    
    showModalBottomSheet(
      context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('users').where('email', whereIn: user.friends.isEmpty ? [''] : user.friends).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final friends = snapshot.data!.docs.map((doc) => AppUser.fromMap(doc.data() as Map<String, dynamic>)).toList();
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('친구 목록', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                if (friends.isEmpty) const Text('친구가 없습니다.')
                else ...friends.map((f) => ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(f.name),
                  subtitle: Text(f.email),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (c) => CalendarScreen(friend: f)));
                  },
                )),
                const SizedBox(height: 20),
              ],
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = context.watch<AuthProvider>().currentUser;
    final user = widget.friend ?? authUser;
    final isMe = widget.friend == null;
    final todoProvider = context.watch<TodoProvider>();
    final notifProvider = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: isMe ? () => _showFriendList(context) : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(user?.name ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (isMe) const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
        centerTitle: true, 
        actions: isMe ? [
          StreamBuilder<List<AppNotification>>(
            stream: notifProvider.getNotificationStream(authUser!.uid),
            builder: (context, snapshot) {
              final unreadCount = snapshot.hasData ? snapshot.data!.where((n) => !n.isRead).length : 0;
              return Stack(
                children: [
                  IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const NotificationScreen())), icon: const Icon(Icons.notifications_outlined)),
                  if (unreadCount > 0) Positioned(right: 8, top: 8, child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)), constraints: const BoxConstraints(minWidth: 16, minHeight: 16), child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center))),
                ],
              );
            }
          ),
          IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SettingsScreen())), icon: const Icon(Icons.settings_outlined)),
        ] : [
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
        ]
      ),
      body: StreamBuilder<List<Todo>>(
        stream: todoProvider.getTodoStream(user!.uid),
        builder: (context, snapshot) {
          final allTodos = snapshot.data ?? [];
          final todos = todoProvider.filterTodosByDate(_selectedDay ?? _focusedDay, allTodos);
          
          return Column(
            children: [
              if (!isMe) Container(width: double.infinity, color: Colors.indigo.withOpacity(0.1), padding: const EdgeInsets.symmetric(vertical: 8), child: const Text('친구의 일정을 확인 중입니다 (읽기 전용)', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
                  child: TableCalendar(
                    locale: 'ko_KR', firstDay: DateTime.utc(2020), lastDay: DateTime.utc(2030), focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (s, f) => setState(() { _selectedDay = s; _focusedDay = f; }),
                    eventLoader: (day) => todoProvider.filterTodosByDate(day, allTodos),
                    calendarStyle: const CalendarStyle(
                      todayDecoration: BoxDecoration(color: Colors.indigoAccent, shape: BoxShape.circle), 
                      selectedDecoration: BoxDecoration(color: Colors.indigo, shape: BoxShape.circle), 
                      markerDecoration: BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
                      outsideDaysVisible: false,
                    ),
                    headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(20), 
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor, 
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
                  ),
                  child: Column(
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(DateFormat('MM월 dd일 일정').format(_selectedDay!), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (isMe) IconButton.filledTonal(onPressed: () => _showTodoDialog(initialDate: _selectedDay), icon: const Icon(Icons.add)),
                      ]),
                      const SizedBox(height: 10),
                      Expanded(child: todos.isEmpty ? const Center(child: Text('일정이 없습니다.')) : ListView.builder(itemCount: todos.length, itemBuilder: (c, i) => TodoItemTile(todo: todos[i], onTap: () => _showTodoDialog(existingTodo: todos[i])))),
                    ],
                  ),
                ),
              )
            ],
          );
        }
      ),
    );
  }
}

// --------------------------------------------------------------------------
// 설정 화면
// --------------------------------------------------------------------------

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();
    final nameController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('설정', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('앱 설정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 10),
          Card(
            elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text('다크 모드'),
                  trailing: Switch(value: themeProvider.themeMode == ThemeMode.dark, onChanged: (_) => themeProvider.toggleTheme()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('로그아웃', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    authProvider.logout();
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('회원 탈퇴', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('회원 탈퇴'),
                        content: const Text('정말로 탈퇴하시겠습니까? 모든 데이터가 영구적으로 삭제됩니다.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
                          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('탈퇴', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      final err = await authProvider.deleteAccount();
                      if (err != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                      } else if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Text('친구 관리', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 10),
          Card(
            elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(child: TextField(controller: nameController, decoration: const InputDecoration(hintText: '친구 이름 입력', border: InputBorder.none))),
                      IconButton.filledTonal(onPressed: () async {
                        if (nameController.text.isNotEmpty) {
                          final msg = await authProvider.sendFriendRequest(nameController.text.trim());
                          if(context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: msg == '성공' ? Colors.green : Colors.redAccent));
                            if (msg == '성공') nameController.clear();
                          }
                        }
                      }, icon: const Icon(Icons.person_add_alt_1)),
                    ],
                  ),
                ),
                if (authProvider.currentUser!.friends.isNotEmpty) ...[
                  const Divider(height: 1),
                  FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance.collection('users').where('email', whereIn: authProvider.currentUser!.friends).get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      final friends = snapshot.data!.docs;
                      return Column(
                        children: friends.map((fDoc) {
                          final f = AppUser.fromMap(fDoc.data() as Map<String, dynamic>);
                          return ListTile(
                            title: Text(f.name),
                            subtitle: Text(f.email),
                            trailing: IconButton(
                              icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                              onPressed: () => authProvider.removeFriend(f.email),
                            ),
                          );
                        }).toList(),
                      );
                    }
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// 알림 화면
// --------------------------------------------------------------------------

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림', style: TextStyle(fontWeight: FontWeight.bold)), 
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => provider.deleteAllNotifications(auth.currentUser!.uid),
            child: const Text('전체 삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: provider.getNotificationStream(auth.currentUser!.uid),
        builder: (context, snapshot) {
          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) return const Center(child: Text('알림이 없습니다.'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (c, i) {
              final n = notifications[i];
              return Card(
                elevation: 0, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                color: n.isRead ? Colors.white : Theme.of(context).primaryColor.withOpacity(0.05),
                child: ListTile(
                  title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.message),
                      const SizedBox(height: 4),
                      Text(DateFormat('MM/dd HH:mm').format(n.timestamp), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                  trailing: n.type == 'friend_request' && !auth.currentUser!.friends.contains(n.senderEmail) ? TextButton(
                    onPressed: () async {
                      final msg = await auth.acceptFriendRequest(n.senderEmail!);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: msg == '성공' ? Colors.green : Colors.redAccent));
                        if (msg == '성공') provider.markAsRead(n.id);
                      }
                    }, 
                    child: const Text('수락'),
                  ) : null,
                  onTap: () => provider.markAsRead(n.id),
                ),
              );
            },
          );
        }
      ),
    );
  }
}

// --------------------------------------------------------------------------
// 할 일 목록 및 카테고리 관리
// --------------------------------------------------------------------------

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
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')), FilledButton(onPressed: () { if(controller.text.isNotEmpty) { context.read<TodoProvider>().addCategory(controller.text, selectedColor); Navigator.pop(context); } }, child: const Text('추가'))],
    )));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TodoProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('전체 일정', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
      body: StreamBuilder<List<Todo>>(
        stream: provider.getTodoStream(auth.currentUser!.uid),
        builder: (context, snapshot) {
          final allTodos = snapshot.data ?? [];
          final todos = _filter == null ? allTodos : allTodos.where((t) => t.categories.any((c) => c.id == _filter!.id)).toList();

          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('전체'), 
                      selected: _filter == null, 
                      onSelected: (v) => setState(() => _filter = null),
                      showCheckmark: false,
                    ),
                    const SizedBox(width: 8),
                    ...provider.categories.map((c) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: GestureDetector(
                        onLongPress: () {
                          showDialog(context: context, builder: (dialogContext) => AlertDialog(
                            title: const Text('카테고리 삭제'), 
                            content: Text('"${c.label}" 카테고리를 삭제하시겠습니까?'), 
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')), 
                              TextButton(onPressed: () { 
                                provider.deleteCategory(c.id); 
                                Navigator.pop(dialogContext); 
                              }, child: const Text('삭제', style: TextStyle(color: Colors.red)))
                            ]
                          ));
                        },
                        child: FilterChip(
                          label: Text(c.label), 
                          selected: _filter?.id == c.id, 
                          onSelected: (v) => setState(() => _filter = v ? c : null), 
                          selectedColor: c.color.withOpacity(0.3),
                          showCheckmark: false,
                        ),
                      ),
                    )),
                    IconButton.filledTonal(onPressed: _showAddCategoryDialog, icon: const Icon(Icons.add, size: 20)),
                  ],
                ),
              ),
              Expanded(child: todos.isEmpty ? const Center(child: Text('일정이 없습니다.')) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: todos.length, itemBuilder: (c, i) => TodoItemTile(todo: todos[i], showDate: true, onTap: () => _showTodoDialogFromList(context, todos[i])))),
            ],
          );
        }
      ),
    );
  }

  void _showTodoDialogFromList(BuildContext context, Todo todo) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('캘린더 화면에서 일정을 클릭하여 수정할 수 있습니다.')));
  }
}

class TodoItemTile extends StatelessWidget {
  final Todo todo;
  final bool showDate;
  final VoidCallback onTap;
  const TodoItemTile({super.key, required this.todo, this.showDate = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final startStr = DateFormat('M/d HH:mm').format(todo.startDateTime);
    final endStr = DateFormat('M/d HH:mm').format(todo.endDateTime);
    
    return Dismissible(
      key: Key(todo.id), direction: DismissDirection.endToStart,
      background: Container(color: Colors.redAccent, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
      onDismissed: (d) => context.read<TodoProvider>().deleteTodo(todo.id),
      child: Card(
        elevation: 0, margin: const EdgeInsets.only(bottom: 12), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: ListTile(
          onTap: onTap,
          leading: Checkbox(value: todo.isCompleted, onChanged: (v) => context.read<TodoProvider>().toggleTodo(todo)),
          title: Text(todo.title, style: TextStyle(decoration: todo.isCompleted ? TextDecoration.lineThrough : null, fontWeight: FontWeight.bold)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (todo.description.isNotEmpty) Text(todo.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text('$startStr - $endStr', style: const TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.w600)),
            if (todo.categories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  children: todo.categories.map((cat) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: cat.color.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                    child: Text(cat.label, style: TextStyle(fontSize: 10, color: cat.color, fontWeight: FontWeight.bold)),
                  )).toList(),
                ),
              )
            else
              const Text('카테고리 없음', style: TextStyle(fontSize: 10, color: Colors.grey))
          ]),
          trailing: const Icon(Icons.edit_note, color: Colors.grey),
        ),
      ),
    );
  }
}
