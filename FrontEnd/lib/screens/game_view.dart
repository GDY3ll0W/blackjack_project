import 'package:flutter/material.dart';

class GameView extends StatefulWidget {
  final String nickname;
  const GameView({super.key, required this.nickname});

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> {
  int _hitCount = 0;

  void _handleHit() {
    setState(() {
      _hitCount++;
    });
    print('${widget.nickname} hit amount: $_hitCount');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Player: ${widget.nickname}'),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'HIT COUNTER',
              style: TextStyle(color: Colors.grey[700], fontSize: 18),
            ),
            Text(
              '$_hitCount',
              style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _handleHit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[900],
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
              ),
              child: const Text('HIT', style: TextStyle(fontSize: 24, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}