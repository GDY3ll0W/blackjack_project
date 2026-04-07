import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  late io.Socket socket;

  void connect() {
    socket = io.io('http://localhost:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      print('Connected to Backend');
      socket.emit('join_room', {'nickname': 'User', 'room': 'Table1'});
    });
  }

  void disconnect() {
    socket.disconnect();
  }
}