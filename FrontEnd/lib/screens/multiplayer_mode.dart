import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import 'game_view.dart';

class MultiplayerMode extends StatefulWidget {
  final String nickname;
  final String avatarPath;

  const MultiplayerMode({
    super.key,
    required this.nickname,
    required this.avatarPath,
  });

  @override
  State<MultiplayerMode> createState() => _MultiplayerModeState();
}

class _MultiplayerModeState extends State<MultiplayerMode> {
  final TextEditingController _roomCodeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  void _createRoom() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Generate a random room code
    final roomCode = _generateRoomCode();

    // Initialize socket and connect
    SocketService().connect(roomCode);

    // Navigate to game view
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameView(
            nickname: widget.nickname,
            avatarPath: widget.avatarPath,
            roomCode: roomCode,
            isMultiplayer: true,
          ),
        ),
      );
    }
  }

  void _joinRoom() {
    if (_roomCodeController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a room code';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final roomCode = _roomCodeController.text.trim().toUpperCase();

    // Initialize socket and connect
    SocketService().connect(roomCode);

    // Navigate to game view
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameView(
            nickname: widget.nickname,
            avatarPath: widget.avatarPath,
            roomCode: roomCode,
            isMultiplayer: true,
          ),
        ),
      );
    }
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String result = '';
    for (int i = 0; i < 6; i++) {
      result += chars[(DateTime.now().millisecond + i) % chars.length];
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Allow back navigation
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A472A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D2617),
          title: const Text('Multiplayer Mode'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Connect to a Game',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 60),
                  // Create Room Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading ? null : _createRoom,
                      child: const Text(
                        'CREATE ROOM',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white30)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.white30)),
                    ],
                  ),
                  const SizedBox(height: 40),
                  // Room Code Input
                  TextField(
                    controller: _roomCodeController,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                    textTransform: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Enter Room Code',
                      hintStyle: const TextStyle(color: Colors.white54),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.yellowAccent, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Join Room Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading ? null : _joinRoom,
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'JOIN ROOM',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }
}
