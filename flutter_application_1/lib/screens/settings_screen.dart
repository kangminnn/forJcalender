import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import 'calendar_screen.dart';

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
          if (ap.currentUser != null && ap.currentUser!.friends.isNotEmpty) FutureBuilder<QuerySnapshot>(
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
