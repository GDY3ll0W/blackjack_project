import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'avatar_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nicknameController = TextEditingController();

  Future<void> _login() async {
    if (_nicknameController.text.isNotEmpty) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
        
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AvatarSelectionScreen(nickname: _nicknameController.text),
          ),
        );
      } catch (e) {
        print(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A472A),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'BLACKJACK TEST',
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _nicknameController,
                style: const TextStyle(color: Colors.white),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(15),
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Enter Nickname',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.yellowAccent)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: const Text('JOIN GAME'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}