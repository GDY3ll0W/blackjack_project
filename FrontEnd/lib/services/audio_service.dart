import 'package:audioplayers/audioplayers.dart';

class AudioService {
  // We use static so we can call these from anywhere without creating a new instance
  static final AudioPlayer _bgPlayer = AudioPlayer();
  static bool _isBackgroundPlaying = false;

  // 1. Play Background Music (Looping)
  static Future<void> playBackgroundMusic() async {
    if (_isBackgroundPlaying) return;

    try {
      await _bgPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgPlayer.setVolume(0.2); // Keep it a bit quieter than SFX
      await _bgPlayer.play(AssetSource('audio/FullStack_BackgroundMusic.mp3'));
      _isBackgroundPlaying = true;
    } catch (e) {
      // Fail silently if audio cannot start yet.
      print('AudioService: failed to start background music: $e');
    }
  }
}