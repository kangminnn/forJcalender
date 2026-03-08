import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../models/models.dart';

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

  Future<void> loadCategories(String uid) async {
    try {
      final snapshot = await _db.collection('users').doc(uid).collection('categories').get();
      if (snapshot.docs.isEmpty) {
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
    } catch (e) { print("카테고리 로딩 실패: $e"); }
  }

  Stream<List<Todo>> getTodoStream(String uid) => _db.collection('todos').where('userId', isEqualTo: uid).snapshots().map((s) => s.docs.map((d) => Todo.fromMap(d.data())).toList());
  Future<void> addTodo(Todo t) async => await _db.collection('todos').doc(t.id).set(t.toMap());
  Future<void> updateTodo(Todo t) async => await _db.collection('todos').doc(t.id).update(t.toMap());
  Future<void> deleteTodo(String id) async => await _db.collection('todos').doc(id).delete();
  Future<void> toggleTodo(Todo t) async => await _db.collection('todos').doc(t.id).update({'isCompleted': !t.isCompleted});
  
  Future<void> addReaction(Todo todo, String senderUid, String senderName, String emoji) async {
    await _db.collection('todos').doc(todo.id).update({'reactions.$senderUid': emoji});
    if (todo.userId != senderUid) {
      await _db.collection('notifications').add(AppNotification(
        id: const Uuid().v4(),
        title: '새로운 반응',
        message: '$senderName님이 일정에 $emoji 반응을 남겼습니다.',
        timestamp: DateTime.now(),
        type: 'emoji_reaction',
        senderEmail: senderName,
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
      // 종료일 계산 시, 만약 종료 시간이 자정(00:00)이라면 해당 날짜의 시작으로 간주하여 이전 날짜까지만 포함되도록 함
      var end = DateTime(t.endDateTime.year, t.endDateTime.month, t.endDateTime.day);
      if (t.endDateTime.hour == 0 && t.endDateTime.minute == 0 && t.endDateTime.second == 0 && t.endDateTime.millisecond == 0) {
        // 정확히 자정인 경우, 해당 날짜는 포함하지 않음 (예: 9일 00:00 종료면 8일까지만 표시)
        end = end.subtract(const Duration(seconds: 1));
        end = DateTime(end.year, end.month, end.day);
      }
      return (target.isAtSameMomentAs(start) || target.isAtSameMomentAs(end) || (target.isAfter(start) && target.isBefore(end)));
    }).toList();
  }
}
