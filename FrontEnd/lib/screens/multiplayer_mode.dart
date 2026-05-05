import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String? _statusMessage;
  String? _errorMessage;
  SocketService? _socketService;
  Timer? _roomCreateTimer;
  bool _navigatingToGame = false;

  void _createRoom() {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting...';
      _errorMessage = null;
    });

    _socketService = SocketService();
    final socketService = _socketService!;
    socketService.onRoomCreated = (data) {
      _roomCreateTimer?.cancel();
      if (mounted) {
        setState(() {
          _statusMessage = 'ROOM CREATED: ${data['code']}';
          _errorMessage = null;
        });
        _navigatingToGame = true;
      }
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GameView(
              nickname: widget.nickname,
              avatarPath: widget.avatarPath,
              roomCode: data['code'],
              isMultiplayer: true,
              playerId: data['playerId'],
              socketService: socketService,
            ),
          ),
        );
      });
    };

    socketService.onConnectErrorCallback = (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = null;
          _errorMessage = 'Unable to connect to server.';
        });
      }
    };

    socketService.onConnected = () {
      if (mounted) {
        setState(() {
          _statusMessage = 'Connected. Creating room...';
          _errorMessage = null;
        });
      }
    };

    socketService.onDisconnected = () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Disconnected while creating room.';
        });
      }
    };

    socketService.onError = (data) {
      _roomCreateTimer?.cancel();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = null;
          _errorMessage = data['message'];
        });
      }
    };

    _roomCreateTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _isLoading) {
        _socketService?.disconnect();
        setState(() {
          _isLoading = false;
          _statusMessage = null;
          _errorMessage = 'Room creation timed out. Try again.';
        });
      }
    });

    socketService.connect('', createRoomOnConnect: true);
  }

  void _joinRoom() {
    if (_roomCodeController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a room code';
        _statusMessage = null;
        _isLoading = false;
      });
      return;
    }

    final roomCode = _roomCodeController.text.trim().toUpperCase();
    
    if (roomCode.length != 6) {
      setState(() {
        _errorMessage = 'Room code must be exactly 6 characters';
        _statusMessage = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting...';
      _errorMessage = null;
    });
    _socketService = SocketService();
    final socketService = _socketService!;

    socketService.onRoomJoined = (data) {
      if (mounted) {
        _navigatingToGame = true;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GameView(
              nickname: widget.nickname,
              avatarPath: widget.avatarPath,
              roomCode: data['room'],
              isMultiplayer: true,
              playerId: data['playerId'],
              socketService: socketService,
            ),
          ),
        );
      }
    };

    socketService.onRoomFull = (data) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = null;
          _errorMessage = data['message'];
        });
        // Show dialog with back buttons
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Room Full'),
            content: Text(data['message']),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Create Room'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Could navigate back to join room, but for now just close
                },
                child: const Text('Back to Join Room'),
              ),
            ],
          ),
        );
      }
    };

    socketService.onError = (data) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = null;
          _errorMessage = data['message'];
        });
      }
    };

    socketService.onConnected = () {
      if (mounted) {
        setState(() {
          _statusMessage = 'Connected. Joining room...';
          _errorMessage = null;
        });
      }
    };

    socketService.onDisconnected = () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Disconnected while joining room.';
        });
      }
    };

    socketService.connect(roomCode);
  }

  Future<bool> _handleBack() async {
    if (_isLoading && _socketService != null) {
      _roomCreateTimer?.cancel();
      _socketService!.disconnect();
      setState(() {
        _isLoading = false;
        _statusMessage = null;
        _errorMessage = 'Room creation canceled';
      });
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _handleBack();
          if (shouldPop && mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A472A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D2617),
          title: const Text('Multiplayer Mode'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final shouldPop = await _handleBack();
              if (shouldPop && mounted) Navigator.pop(context);
            },
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
                  const Text(
                    'ONLY 6 CHARACTER LIMIT',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    enabled: !_isLoading,
                    controller: _roomCodeController,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Z0-9]'),
                      ),
                    ],
                    decoration: InputDecoration(
                      hintText: 'Enter 6-char code',
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
                      counterText: '',
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
                  if (_statusMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(
                        _statusMessage!,
                        style: const TextStyle(
                          color: Colors.lightGreenAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
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
    _roomCreateTimer?.cancel();
    _roomCodeController.dispose();
    if (!_navigatingToGame) {
      _socketService?.disconnect();
    }
    super.dispose();
  }
}
