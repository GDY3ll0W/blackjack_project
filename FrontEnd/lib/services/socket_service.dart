import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  late io.Socket socket;

  void connect() {
    // IMPORTANT: Replace the URL with your current ngrok address
    socket = io.io('https://nigel-nonexplainable-ernestina.ngrok-free.dev', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true, // Changed to true so it connects immediately
    });

    socket.connect();

    socket.onConnect((_) {
      print('--- Connected to Blackjack Backend ---');
    });

    socket.onDisconnect((_) => print('Disconnected from Backend'));
  }

  void disconnect() {
    socket.disconnect();
  }
}