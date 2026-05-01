import 'package:flutter/material.dart';
import 'game_view.dart';
import 'multiplayer_mode.dart';

class MainMenu extends StatelessWidget {
  final String nickname;
  final String avatarPath;

  const MainMenu({
    super.key,
    required this.nickname,
    required this.avatarPath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A472A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'BLACKJACK',
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 60),
            Text(
              'Welcome, $nickname!',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 80),
            // Singleplayer Button
            SizedBox(
              width: 300,
              height: 70,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GameView(
                        nickname: nickname,
                        avatarPath: avatarPath,
                        isMultiplayer: false,
                      ),
                    ),
                  );
                },
                child: const Text(
                  'SINGLEPLAYER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            // Multiplayer Button
            SizedBox(
              width: 300,
              height: 70,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MultiplayerMode(
                        nickname: nickname,
                        avatarPath: avatarPath,
                      ),
                    ),
                  );
                },
                child: const Text(
                  'MULTIPLAYER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
