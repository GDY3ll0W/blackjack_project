import 'package:flutter/material.dart';
import '../services/socket_service.dart';

class GameView extends StatefulWidget {
  final String nickname;
  const GameView({super.key, required this.nickname});

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> {
  final SocketService _socketService = SocketService();
  List<Map<String, String>> playerHand = [];

  @override
  void initState() {
    super.initState();
    _socketService.connect();
    _socketService.socket.on('cardDealt', (data) {
      if (mounted) {
        setState(() {
          playerHand.add({
            'suit': data['card']['suit'].toString(),
            'rank': data['card']['rank'].toString(),
          });
        });
      }
    });
  }

  void _handleHit() {
    _socketService.socket.emit('playerAction', {'action': 'hit'});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A472A),
      appBar: AppBar(
        title: Text('Player: ${widget.nickname}'),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('YOUR HAND', style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10.0,
              runSpacing: 10.0,
              children: playerHand.map((card) => PlayingCardWidget(
                suit: card['suit']!,
                rank: card['rank']!,
              )).toList(),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: _handleHit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[900],
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
              ),
              child: const Text('HIT', style: TextStyle(fontSize: 24, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class PlayingCardWidget extends StatelessWidget {
  final String suit;
  final String rank;

  const PlayingCardWidget({super.key, required this.suit, required this.rank});

  @override
  Widget build(BuildContext context) {
    Color cardColor = (suit == 'Hearts' || suit == 'Diamonds') ? Colors.red : Colors.black;
    String suitChar = suit == 'Spades' ? '♠' : suit == 'Hearts' ? '♥' : suit == 'Diamonds' ? '♦' : '♣';

    return Container(
      width: 70,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Text(rank, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cardColor)),
            ),
            Text(suitChar, style: TextStyle(fontSize: 32, color: cardColor)),
          ],
        ),
      ),
    );
  }
}