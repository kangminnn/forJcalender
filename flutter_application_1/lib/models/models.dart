import 'package:flutter/material.dart';

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
  final String? todoId;
  final Map<String, dynamic>? sharedTodoData; // 추가: 공유된 일정 데이터
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.senderEmail,
    this.todoId,
    this.sharedTodoData,
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
    'sharedTodoData': sharedTodoData,
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
    sharedTodoData: map['sharedTodoData'],
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
  Map<String, dynamic> reactions;

  Todo({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    required this.startDateTime,
    required this.endDateTime,
    required this.categories,
    this.isCompleted = false,
    Map<String, dynamic>? reactions,
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
    reactions: Map<String, dynamic>.from(map['reactions'] ?? {}),
  );
}

class UserTask {
  final String id;
  final String userId;
  String title;
  String description;
  bool isCompleted;
  DateTime createdAt;

  UserTask({
    required this.id, 
    required this.userId, 
    required this.title, 
    this.description = '', 
    this.isCompleted = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id, 
    'userId': userId, 
    'title': title, 
    'description': description, 
    'isCompleted': isCompleted,
    'createdAt': createdAt.toIso8601String(),
  };

  factory UserTask.fromMap(Map<String, dynamic> map) => UserTask(
    id: map['id'], 
    userId: map['userId'], 
    title: map['title'], 
    description: map['description'] ?? '', 
    isCompleted: map['isCompleted'] ?? false,
    createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
  );
}
