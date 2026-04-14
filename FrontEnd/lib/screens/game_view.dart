import 'package:flutter/material.dart';
import '../logic/deck.dart';
import '../models/card.dart' as model_card;

class GameView extends StatefulWidget {
  final String nickname;

  const GameView({super.key, required this.nickname});

  @override
  _GameViewState createState() => _GameViewState();
}

class _GameViewState extends State<GameView> {
  late Deck deck;
  List<model_card.Card> playerHand = [];
  List<model_card.Card> dealerHand = [];
  int balance = 1000;
  int currentBet = 0;
  String gameMessage = 'Place a bet to start';
  bool isPlaying = false;
  bool hideDealerHoleCard = true;

  final List<int> betValues = [5, 10, 20, 25, 50, 100, 150, 200];
  final Map<int, Color> betColors = {
    5: Colors.red,
    10: Colors.blue,
    20: Colors.purple,
    25: Colors.green,
    50: Colors.black,
    100: Colors.orange,
    150: Colors.brown,
    200: Colors.amber,
  };

  @override
  void initState() {
    super.initState();
    resetGame();
  }

  void resetGame() {
    deck = Deck(numDecks: 6);
    playerHand = [];
    dealerHand = [];
    currentBet = 0;
    isPlaying = false;
    hideDealerHoleCard = true;
    gameMessage = 'Place a bet to start';
    setState(() {});
  }

  int calculateScore(List<model_card.Card> hand) {
    int total = 0;
    int aces = 0;

    for (final card in hand) {
      if (card.rank == 'Ace') {
        total += 11;
        aces += 1;
      } else if (['Jack', 'Queen', 'King'].contains(card.rank)) {
        total += 10;
      } else {
        total += int.parse(card.rank);
      }
    }

    while (total > 21 && aces > 0) {
      total -= 10;
      aces -= 1;
    }

    return total;
  }

  void placeBet(int amount) {
    if (isPlaying) {
      setState(() => gameMessage = 'Finish the current round first');
      return;
    }

    if (balance < amount) {
      setState(() => gameMessage = 'Not enough balance for that bet');
      return;
    }

    currentBet = amount;
    setState(() => gameMessage = 'Current bet: \Ω$currentBet');
  }

  void dealRound() {
    if (isPlaying) return;
    if (currentBet == 0) {
      setState(() => gameMessage = 'Place a bet first!');
      return;
    }

    if (deck.remainingCards() < 10) {
      deck = Deck(numDecks: 6);
    }

    playerHand = [deck.dealCard()!, deck.dealCard()!];
    dealerHand = [deck.dealCard()!, deck.dealCard()!];
    isPlaying = true;
    hideDealerHoleCard = true;
    gameMessage = 'Game started... Hit or Stand';
    setState(() {});

    if (calculateScore(playerHand) == 21) {
      stand();
    }
  }

  void hit() {
    if (!isPlaying) return;

    final card = deck.dealCard();
    if (card == null) return;

    playerHand.add(card);
    setState(() {});

    if (calculateScore(playerHand) > 21) {
      endGame('lose', '💥 BUST! You lose');
    }
  }

  void stand() {
    if (!isPlaying) return;

    hideDealerHoleCard = false;
    while (calculateScore(dealerHand) < 17) {
      final card = deck.dealCard();
      if (card == null) break;
      dealerHand.add(card);
    }

    final p = calculateScore(playerHand);
    final d = calculateScore(dealerHand);

    if (p > 21) {
      endGame('lose', '💥 BUST! You lose');
    } else if (d > 21) {
      endGame('win', '🏆 Dealer busts! You win');
    } else if (p > d) {
      endGame('win', '🏆 You win');
    } else if (p < d) {
      endGame('lose', '❌ You lose');
    } else {
      endGame('push', '🫧 Push (tie)');
    }
  }

  void endGame(String result, String message) {
    if (result == 'win') {
      balance += currentBet;
    } else if (result == 'lose') {
      balance -= currentBet;
    }

    currentBet = 0;
    isPlaying = false;
    hideDealerHoleCard = false;
    setState(() => gameMessage = message);
  }

  String cardImageUrl(model_card.Card card) {
    final rank = switch (card.rank) {
      'Ace' => 'A',
      'Jack' => 'J',
      'Queen' => 'Q',
      'King' => 'K',
      _ => card.rank,
    };
    final suit = card.suit[0];
    return 'https://deckofcardsapi.com/static/img/$rank$suit.png';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blackjack Dev Build'),
        backgroundColor: Colors.black.withOpacity(0.8),
      ),
      body: Stack(
        children: [
          // 1. BACKGROUND ART LAYER (UPDATED FOR ZOOM OUT)
          Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFF4A6F3C), // A green extracted from the artwork to fill gaps
            alignment: Alignment.center, // Keeps the creature face in the center
            child: Image.asset(
              "assets/images/table/DeepBlackjack.png",
              fit: BoxFit.contain, // This forces the *whole* image to be visible
            ),
          ),
          
          // 2. UI LAYER (Unchanged from previous)
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Balance: \Ω$balance', 
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 10, color: Colors.black)])),
                    const SizedBox(height: 4),
                    Text('Current Bet: \Ω$currentBet', 
                      style: const TextStyle(color: Colors.white, fontSize: 20, shadows: [Shadow(blurRadius: 10, color: Colors.black)])),
                    const SizedBox(height: 16),
                    const Text('Dealer', 
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    
                    // Dealer Hand Display
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: dealerHand.asMap().entries.map((entry) {
                          final index = entry.key;
                          final card = entry.value;
                          final hidden = hideDealerHoleCard && index == 1;
                          return PlayingCardWidget(
                            imageUrl: hidden
                                ? 'https://deckofcardsapi.com/static/img/back.png'
                                : cardImageUrl(card),
                            rank: hidden ? null : card.rank,
                            suit: hidden ? null : card.suit,
                            hidden: hidden,
                          );
                        }).toList(),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    // Game Message with semi-transparent background for readability
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(gameMessage, 
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.yellow, fontSize: 24, fontWeight: FontWeight.bold)),
                    ),
                    
                    const SizedBox(height: 16),
                    const Text('Player', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    
                    // Player Hand Display
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: playerHand.map((card) {
                          return PlayingCardWidget(
                            imageUrl: cardImageUrl(card),
                            rank: card.rank,
                            suit: card.suit,
                            hidden: false,
                          );
                        }).toList(),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    Text('Score: ${calculateScore(playerHand)}', 
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    
                    const SizedBox(height: 24),
                    if (!isPlaying) buildBetSection(),
                    if (isPlaying) buildActionButtons(),
                    const SizedBox(height: 12),
                    buildControlButtons(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBetSection() {
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: betValues.map((value) {
            return GestureDetector(
              onTap: () => placeBet(value),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: betColors[value],
                  shape: BoxShape.circle, // Circular chips look better on the art
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black54, offset: Offset(2, 2))],
                ),
                child: Center(
                  child: Text('\Ω$value', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: dealRound,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[800], 
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: const Text('Start Round', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: hit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[700], 
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
          ),
          child: const Text('Hit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: stand,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[700], 
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
          ),
          child: const Text('Stand', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: resetGame,
          style: TextButton.styleFrom(foregroundColor: Colors.white70),
          child: const Text('Reset Table', style: TextStyle(fontSize: 14, decoration: TextDecoration.underline)),
        ),
      ],
    );
  }
}

class PlayingCardWidget extends StatelessWidget {
  final String imageUrl;
  final String? rank;
  final String? suit;
  final bool hidden;

  const PlayingCardWidget({
    super.key,
    required this.imageUrl,
    this.rank,
    this.suit,
    this.hidden = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 6, offset: const Offset(2, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: hidden ? Colors.blue[900] : Colors.white,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!hidden) Text(rank ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                  if (!hidden) Text(suit != null ? suit![0] : '', style: const TextStyle(color: Colors.black)),
                  if (hidden) const Icon(Icons.casino, color: Colors.white),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}