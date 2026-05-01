import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import 'main_menu.dart';

class AvatarSelectionScreen extends StatefulWidget {
  final String nickname;

  const AvatarSelectionScreen({super.key, required this.nickname});

  @override
  State<AvatarSelectionScreen> createState() => _AvatarSelectionScreenState();
}

class _AvatarSelectionScreenState extends State<AvatarSelectionScreen> {
  String? selectedAvatar;
  final List<String> avatarOptions = [
    'assets/images/avatar/Octo.png',
    'assets/images/avatar/Hagfish.png',
    'assets/images/avatar/Isopod.png',
    'assets/images/avatar/Lantern.png',
    'assets/images/avatar/Pig.png',
    'assets/images/avatar/Rattail.png',
  ];

  @override
  void initState() {
    super.initState();
    AudioService.playBackgroundMusic();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A472A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Choose Your Avatar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: avatarOptions.map((avatar) {
                final isSelected = selectedAvatar == avatar;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedAvatar = avatar;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Colors.amber : Colors.white,
                        width: isSelected ? 4 : 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(
                      avatar,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: selectedAvatar != null
                  ? () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MainMenu(
                            nickname: widget.nickname,
                            avatarPath: selectedAvatar!,
                          ),
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                disabledBackgroundColor: Colors.grey,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: const Text(
                'Continue to Game',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
