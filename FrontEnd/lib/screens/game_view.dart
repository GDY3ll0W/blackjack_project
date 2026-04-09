import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class GameView extends StatefulWidget {
  final String nickname;

  const GameView({super.key, required this.nickname});
  @override
  _GameViewState createState() => _GameViewState();
}

class _GameViewState extends State<GameView> {
  late IO.Socket socket;
  
  // Game State Variables
  List playerHand = [];
  List dealerHand = [];
  int balance = 100;
  int playerScore = 0;
  String gameMessage = "Place your bet to start!";
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    connectToServer();
  }

  void connectToServer() {
    socket = IO.io('https://nigel-nonexplainable-ernestina.ngrok-free.dev', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'extraHeaders': {'ngrok-skip-browser-warning': 'true'}, // For ngrok compatibility
    });

    socket.connect();

    // Listens for the $100 initial balance
    socket.on('initialState', (data) {
      setState(() => balance = data['balance']);
    });

    // Listens for the initial deal 
    socket.on('gameStarted', (data) {
      setState(() {
        playerHand = data['playerHand'];
        dealerHand = data['dealerHand'];
        balance = data['balance'];
        playerScore = data['playerScore'];
        isPlaying = true;
        gameMessage = "Hit or Stand?";
      });
    });

    socket.on('cardDealt', (data) {
      setState(() {
        playerHand.add(data['card']);
        playerScore = data['score'];
      });
    });

    socket.on('gameOver', (data) {
      setState(() {
        gameMessage = data['message'];
        dealerHand = data['dealerHand']; // Reveals the hidden card
        balance = data['newBalance'];
        isPlaying = false;
      });
    });
  }

  void placeBet(int amount) {
    socket.emit('placeBet', {'amount': amount});
  }

  void playerAction(String action) {
    socket.emit('playerAction', {'action': action});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[900], // Classic Casino Felt
      appBar: AppBar(title: Text("Blackjack Dev Build"), backgroundColor: Colors.black),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Dealer Section
          Column(
            children: [
              Text("Dealer", style: TextStyle(color: Colors.white, fontSize: 20)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: dealerHand.map((card) => CardWidget(card)).toList(),
              ),
            ],
          ),

          // 2. Info / Message Section
          Column(
            children: [
              Text(gameMessage, style: TextStyle(color: Colors.yellow, fontSize: 24, fontWeight: FontWeight.bold)),
              if (isPlaying) Text("Score: $playerScore", style: TextStyle(color: Colors.white)),
            ],
          ),

          // 3. Player Section
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: playerHand.map((card) => CardWidget(card)).toList(),
              ),
              Text("You (Balance: \$$balance)", style: TextStyle(color: Colors.white, fontSize: 20)),
              SizedBox(height: 20),
              
              // Action Buttons or Chip Buttons
              isPlaying ? buildActionButtons() : buildChipButtons(),
            ],
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget buildChipButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [5, 10, 25, 50].map((val) {
        return ElevatedButton(
          style: ElevatedButton.styleFrom(shape: CircleBorder(), padding: EdgeInsets.all(20), backgroundColor: Colors.red),
          onPressed: () => placeBet(val),
          child: Text("\$$val"),
        );
      }).toList(),
    );
  }

  Widget buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(onPressed: () => playerAction('hit'), child: Text("Hit")),
        ElevatedButton(onPressed: () => playerAction('stand'), child: Text("Stand"), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue)),
      ],
    );
  }
}

// Simple Placeholder for Card Visuals
class CardWidget extends StatelessWidget {
  final dynamic card;
  CardWidget(this.card);

  @override
  Widget build(BuildContext context) {
    bool isHidden = card['rank'] == 'Hidden';
    return Container(
      margin: EdgeInsets.all(5),
      padding: EdgeInsets.all(10),
      width: 60,
      height: 90,
      decoration: BoxDecoration(
        color: isHidden ? Colors.blue : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black),
      ),
      child: isHidden 
        ? Center(child: Icon(Icons.help_outline, color: Colors.white))
        : Column(
            children: [
              Text(card['rank'], style: TextStyle(fontWeight: FontWeight.bold)),
              Text(card['suit'][0]), // First letter of Suit
            ],
          ),
    );
  }
}