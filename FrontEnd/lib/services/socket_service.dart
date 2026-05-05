import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  late io.Socket socket;
  bool _createRoomOnConnect = false;

  // Callbacks for UI updates
  Function()? onConnected;
  Function(dynamic)? onConnectErrorCallback;
  Function()? onDisconnected;
  Function(Map<String, dynamic>)? onRoomCreated;
  Function(Map<String, dynamic>)? onRoomJoined;
  Function(Map<String, dynamic>)? onRoomFull;
  Function(Map<String, dynamic>)? onPlayerListUpdate;
  Function(Map<String, dynamic>)? onError;

  // --- URL CONFIGURATION ---
  final String cloudRunUrl = 'https://blackjack-backend-549147796202.us-central1.run.app';
  final String localUrl = 'http://localhost:8080';

  void connect(String roomCode, {bool createRoomOnConnect = false}) {
    _createRoomOnConnect = createRoomOnConnect;

    // Use cloudRunUrl for production or localUrl for testing
    socket = io.io(localUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'forceNew': true,
    });

    // --- CONNECTION EVENTS ---
    socket.onConnect((_) {
      print('--- Connected to Blackjack Backend ---');
      onConnected?.call();
      if (_createRoomOnConnect) {
        createRoom();
      } else if (roomCode.isNotEmpty) {
        joinRoom(roomCode);
      }
    });

    socket.onConnectError((err) {
      print('Connect error: $err');
      onConnectErrorCallback?.call(err);
      onError?.call({'message': 'Unable to connect to backend.'});
    });

    socket.onDisconnect((_) {
      print('Disconnected from Backend');
      onDisconnected?.call();
    });

    // --- GAME LISTENERS ---
    // These match the emitters in server.js
    socket.on('roomCreated', (data) => onRoomCreated?.call(Map<String, dynamic>.from(data)));
    socket.on('roomJoined', (data) => onRoomJoined?.call(Map<String, dynamic>.from(data)));
    socket.on('roomFull', (data) => onRoomFull?.call(Map<String, dynamic>.from(data)));
    
    // This is now our main listener for rounds, turns, and dealer cards[cite: 1, 2]
    socket.on('playerListUpdate', (data) => onPlayerListUpdate?.call(Map<String, dynamic>.from(data)));
    
    socket.on('error', (data) {
      print('Server Error: $data');
      if (data is Map) {
        onError?.call(Map<String, dynamic>.from(data));
      } else {
        onError?.call({'message': data.toString()});
      }
    });

    socket.connect();
  }

  // --- EMITTERS ---
  void createRoom() {
    print('Emitting createRoom');
    socket.emit('createRoom');
  }

  void joinRoom(String roomCode) {
    print('Joining room: $roomCode');
    socket.emit('joinRoom', roomCode);
  }

  // Tells server player is ready to start the round[cite: 4]
  void toggleReady(String roomCode) {
    print('Toggling ready for room: $roomCode');
    socket.emit('toggleReady', roomCode);
  }

  // Sends the bet amount for the current round
  void placeBet(String roomCode, double amount) {
    socket.emit('placeBet', {
      'roomCode': roomCode,
      'amount': amount
    });
  }

  // Sends Hit, Stand, or Double action
  void playAction(String roomCode, String action) {
    socket.emit('playerAction', {
      'roomCode': roomCode,
      'action': action
    });
  }

  void disconnect() {
    socket.disconnect();
  }
}