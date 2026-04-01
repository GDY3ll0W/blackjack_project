import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Blackjack Lobby')),
        body: const Center(child: SocketConnector()),
      ),
    );
  }
}

class SocketConnector extends StatefulWidget {
  const SocketConnector({super.key});

  @override
  State<SocketConnector> createState() => _SocketConnectorState();
}

class _SocketConnectorState extends State<SocketConnector> {
  late io.Socket socket;

  @override
  void initState() {
    super.initState();
    initSocket();
  }

  void initSocket() {
    socket = io.io('http://localhost:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      print('Connected');
      socket.emit('join_room', {'nickname': 'Adolf', 'room': 'Table1'});
    });
  }

  @override
  void dispose() {
    socket.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Text('Connecting...');
  }
}
