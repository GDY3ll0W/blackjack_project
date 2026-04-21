import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  late io.Socket socket;

  // Your actual Live Google Cloud Run URL
  final String cloudRunUrl = 'https://blackjack-backend-549147796202.us-central1.run.app'; 

  void connect(String roomCode) {
    // We use websocket transport for Cloud Run compatibility
    socket = io.io(cloudRunUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'extraHeaders': {
        'Connection': 'upgrade',
        'Upgrade': 'websocket'
      }
    });

    socket.onConnect((_) {
      print('--- Connected to Blackjack Backend ---');
      // Automatically join the table upon connection
      joinRoom(roomCode);
    });

    socket.onDisconnect((_) => print('Disconnected from Backend'));

    // --- GAME LISTENERS ---

    // 1. Initial State (Balance & Room Info)
    socket.on('initialState', (data) {
      print('Connected! Current Balance: ${data['balance']}');
      // Update your UI balance variable here
    });

    // 2. Game Started (Initial Deal)
    socket.on('gameStarted', (data) {
      print('Game has started! Player Hand: ${data['playerHand']}');
      // Update your UI lists for player and dealer cards
    });

    // 3. Card Dealt (Result of a 'Hit')
    socket.on('cardDealt', (data) {
      print('New card received: ${data['card']}');
      // Add this card to your player's hand list
    });

    // 4. Game Over (Dealer results and Payouts)
    socket.on('gameOver', (data) {
      print('Result: ${data['message']}');
      print('Dealer final hand: ${data['dealerHand']}');
      // Show the 'New Game' button in your UI
    });

    // 5. Error Handling
    socket.on('error', (data) {
      print('Server Error: ${data['message']}');
    });
  }

  // --- ACTIONS ---

  void joinRoom(String roomCode) {
    print('Joining room: $roomCode');
    socket.emit('joinRoom', roomCode);
  }

  void placeBet(double amount) {
    print('Placing bet: $amount');
    socket.emit('placeBet', {'amount': amount});
  }

  void playAction(String action) {
    print('Player action: $action');
    socket.emit('playerAction', {'action': action});
  }

  void disconnect() {
    socket.disconnect();
  }
}