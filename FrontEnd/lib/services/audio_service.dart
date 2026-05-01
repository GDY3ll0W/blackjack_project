import 'package:audioplayers/audioplayers.dart';

class AudioService {
  // We use static so we can call these from anywhere without creating a new instance
  static final AudioPlayer _bgPlayer = AudioPlayer();
  static final AudioPlayer _sfxPlayer = AudioPlayer();
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

  // 2. Play Win Sound
  static Future<void> playWinSound() async {
    await _sfxPlayer.play(AssetSource('audio/FullStack_Win.mp3'));
  }

  // 3. Play Loss Sound
  static Future<void> playLossSound() async {
    await _sfxPlayer.play(AssetSource('audio/FullStack_Loss.mp3'));
  }

  // 4. Play Let It Ride Sound (with counter logic)
  static Future<void> playLetItRideSound(int counter) async {
    late String audioFile;
    
    if (counter == 1) {
      audioFile = 'audio/FullStack_First_letitride1.mp3';
    } else if (counter == 2) {
      audioFile = 'audio/FullStack_Second_letitride2.mp3';
    } else if (counter == 3) {
      audioFile = 'audio/FullStack_Third_letitride3.mp3';
    } else if (counter == 4) {
      audioFile = 'audio/FullStack_Fourth_letitride4.mp3';
    } else {
      // For 5 and beyond, use the 5th file
      audioFile = 'audio/Fullstack_Fifth_letitride5.mp3';
    }
    
    await _sfxPlayer.play(AssetSource(audioFile));
  }

  // 5. Play House Always Has The Edge Sound (when balance reaches 0)
  static Future<void> playHouseEdgeSound() async {
    await _sfxPlayer.play(AssetSource('audio/FullStack_TheHouseAlwaysHasTheEdge.mp3'));
  }
}