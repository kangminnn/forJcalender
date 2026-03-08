import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';

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
