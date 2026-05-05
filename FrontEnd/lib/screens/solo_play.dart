import 'package:flutter/material.dart';
import '../logic/deck.dart';
import '../models/card.dart' as model_card;

class SoloPlay extends StatefulWidget {
  final String nickname;
  final String avatarPath;

  const SoloPlay({super.key, required this.nickname, required this.avatarPath});

  @override
  _SoloPlayState createState() => _SoloPlayState();
}

class _SoloPlayState extends State<SoloPlay> {
  late Deck deck;
  List<List<model_card.Card>> playerHands = [[]];
  List<int> playerBets = [0];
  List<model_card.Card> dealerHand = [];
  int currentHandIndex = 0;
  int balance = 1000;
  int currentBet = 0;
  int wins = 0;
  int losses = 0;
  int pushes = 0;
  int loanDebt = 0;
  int lastRideAmount = 0;
  int winStreak = 0;
  String gameMessage = 'Place a bet to start';
  bool gameActive = false;
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

  String formatNumber(int num) {
    return num.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  void initState() {
    super.initState();
    resetGame();
  }

  void resetGame() {
    deck = Deck(numDecks: 6);
    playerHands = [[]];
    playerBets = [0];
    dealerHand = [];
    currentHandIndex = 0;
    currentBet = 0;
    wins = 0;
    losses = 0;
    pushes = 0;
    loanDebt = 0;
    lastRideAmount = 0;
    winStreak = 0;
    gameMessage = 'Place a bet to start';
    gameActive = false;
    hideDealerHoleCard = true;
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

  String handText(List<model_card.Card> hand) {
    if (hand.isEmpty) return '';
    final cardNames = hand.map((card) => card.rank).join(' + ');
    return '$cardNames = ${calculateScore(hand)}';
  }

  bool sameValue(model_card.Card? cardA, model_card.Card? cardB) {
    if (cardA == null || cardB == null) return false;
    return cardA.rank == cardB.rank;
  }

  bool canSplit() {
    if (!gameActive) return false;
    if (playerHands.length != 1) return false;
    final hand = playerHands[0];
    if (hand.length != 2) return false;
    if (!sameValue(hand[0], hand[1])) return false;
    return balance >= playerBets[0];
  }

  bool canDoubleDown() {
    if (!gameActive) return false;
    final hand = playerHands[currentHandIndex];
    if (hand.length != 2) return false;
    return balance >= 2 * playerBets[currentHandIndex];
  }

  void placeBet(int amount) {
    if (gameActive) {
      setState(() => gameMessage = 'Finish the current round first');
      return;
    }

    if (currentBet + amount > balance) {
      setState(() => gameMessage = 'Not enough balance for that bet');
      return;
    }

    currentBet += amount;
    setState(() => gameMessage = 'Current bet: Ω${formatNumber(currentBet)}');
  }

  void clearBet() {
    if (gameActive) {
      setState(() => gameMessage = 'Finish the current round first');
      return;
    }
    currentBet = 0;
    setState(() => gameMessage = 'Bet cleared');
  }

  void createNewDeckIfNeeded() {
    if (deck.remainingCards() < 12) {
      deck = Deck(numDecks: 6);
    }
  }

  model_card.Card drawCard() {
    createNewDeckIfNeeded();
    return deck.dealCard() ?? Deck(numDecks: 6).dealCard()!;
  }

  void dealRound() {
    if (gameActive) {
      setState(() => gameMessage = 'Finish the current round first');
      return;
    }

    if (currentBet == 0) {
      setState(() => gameMessage = 'Place a bet first!');
      return;
    }

    if (currentBet > balance) {
      setState(() {
        currentBet = 0;
        gameMessage = 'You cannot bet more than your balance!';
      });
      return;
    }

    playerHands = [[]];
    playerBets = [currentBet];
    currentHandIndex = 0;
    dealerHand = [];
    hideDealerHoleCard = true;
    gameActive = true;

    final p1 = drawCard();
    final p2 = drawCard();
    final d1 = drawCard();
    final d2 = drawCard();

    playerHands[0] = [p1, p2];
    dealerHand = [d1, d2];

    final playerScore = calculateScore(playerHands[0]);
    final dealerScore = calculateScore(dealerHand);

    if (playerScore == 21 && dealerScore == 21) {
      hideDealerHoleCard = false;
      gameActive = false;
      pushes += 1;
      currentBet = 0;
      lastRideAmount = 0;
      setState(() => gameMessage = '🫧 Both have Blackjack! Push');
      return;
    }

    if (playerScore == 21) {
      hideDealerHoleCard = false;
      gameActive = false;
      balance += playerBets[0];
      wins += 1;
      winStreak += 1;
      lastRideAmount = playerBets[0];
      final repayment = repayLoanFromWin(playerBets[0]);
      currentBet = 0;
      setState(() => gameMessage = repayment > 0
          ? '🃏 BLACKJACK! You win! | \$$repayment loan paid'
          : '🃏 BLACKJACK! You win!');
      return;
    }

    if (dealerScore == 21) {
      hideDealerHoleCard = false;
      gameActive = false;
      balance -= playerBets[0];
      losses += 1;
      winStreak = 0;
      currentBet = 0;
      lastRideAmount = 0;
      setState(() => gameMessage = '💀 Dealer has Blackjack!');
      return;
    }

    setState(() => gameMessage = 'Game started... Hit or Stand');
  }

  void hit() {
    if (!gameActive) {
      setState(() => gameMessage = 'Start a round first!');
      return;
    }

    playerHands[currentHandIndex].add(drawCard());
    final total = calculateScore(playerHands[currentHandIndex]);

    if (total > 21) {
      advanceFromFinishedHand('💥 Hand ${currentHandIndex + 1} busted');
      return;
    }

    if (total == 21) {
      advanceFromFinishedHand('✅ Hand ${currentHandIndex + 1} reached 21');
      return;
    }

    setState(() {});
  }

  void stand() {
    if (!gameActive) {
      setState(() => gameMessage = 'Start a round first!');
      return;
    }

    advanceFromFinishedHand('✋ Hand ${currentHandIndex + 1} stands');
  }

  void doubleDown() {
    if (!canDoubleDown()) {
      setState(() => gameMessage = 'You can only double down on a hand with exactly 2 cards, and you need enough balance.');
      return;
    }

    playerBets[currentHandIndex] += playerBets[currentHandIndex];
    playerHands[currentHandIndex].add(drawCard());
    final total = calculateScore(playerHands[currentHandIndex]);

    if (total > 21) {
      advanceFromFinishedHand('💥 Hand ${currentHandIndex + 1} busted after Double Down');
      return;
    }

    if (total == 21) {
      advanceFromFinishedHand('✅ Hand ${currentHandIndex + 1} reached 21 after Double Down');
      return;
    }

    advanceFromFinishedHand('⏩ Hand ${currentHandIndex + 1} Double Down complete');
  }

  void splitHand() {
    if (!canSplit()) {
      setState(() => gameMessage = 'You can only split when your first 2 cards match and you have enough balance.');
      return;
    }

    final original = playerHands[0];
    final bet = playerBets[0];
    final firstCard = original[0];
    final secondCard = original[1];

    playerHands = [
      [firstCard, drawCard()],
      [secondCard, drawCard()],
    ];
    playerBets = [bet, bet];
    currentHandIndex = 0;
    setState(() => gameMessage = '✂️ Split done. Play Hand 1 first.');

    if (calculateScore(playerHands[0]) == 21) {
      advanceFromFinishedHand('✅ Hand 1 reached 21 after split');
    }
  }

  void advanceFromFinishedHand(String reasonText) {
    if (currentHandIndex < playerHands.length - 1) {
      currentHandIndex += 1;
      setState(() => gameMessage = '$reasonText | Now playing Hand ${currentHandIndex + 1}');

      final activeTotal = calculateScore(playerHands[currentHandIndex]);
      if (activeTotal >= 21) {
        if (activeTotal == 21) {
          advanceFromFinishedHand('✅ Hand ${currentHandIndex + 1} reached 21');
        } else {
          advanceFromFinishedHand('💥 Hand ${currentHandIndex + 1} busted');
        }
      }
      return;
    }

    dealerTurnAndResolve();
  }

  void dealerTurnAndResolve() {
    hideDealerHoleCard = false;
    while (calculateScore(dealerHand) < 17) {
      dealerHand.add(drawCard());
    }
    resolveHands();
  }

  void resolveHands() {
    final d = calculateScore(dealerHand);
    final messages = <String>[];
    var totalRideWin = 0;
    var hadWin = false;
    var hadLoss = false;

    for (var i = 0; i < playerHands.length; i++) {
      final hand = playerHands[i];
      final p = calculateScore(hand);
      final bet = playerBets[i];
      final label = playerHands.length > 1 ? 'Hand ${i + 1}' : 'Hand';

      if (p > 21) {
        balance -= bet;
        losses += 1;
        hadLoss = true;
        messages.add('$label: 💥 Bust, lose');
      } else if (d > 21) {
        balance += bet;
        wins += 1;
        hadWin = true;
        totalRideWin += bet;
        final repayment = repayLoanFromWin(bet);
        messages.add(repayment > 0
            ? '$label: 🏆 Dealer busts, win | \$$repayment loan paid'
            : '$label: 🏆 Dealer busts, win');
      } else if (p > d) {
        balance += bet;
        wins += 1;
        hadWin = true;
        totalRideWin += bet;
        final repayment = repayLoanFromWin(bet);
        messages.add(repayment > 0
            ? '$label: 🏆 Win | \$$repayment loan paid'
            : '$label: 🏆 Win');
      } else if (p < d) {
        balance -= bet;
        losses += 1;
        hadLoss = true;
        messages.add('$label: ❌ Lose');
      } else {
        pushes += 1;
        messages.add('$label: 🫧 Push');
      }
    }

    if (hadLoss) {
      winStreak = 0;
    } else if (hadWin) {
      winStreak += 1;
    }

    if (totalRideWin > 0) {
      lastRideAmount = totalRideWin;
    } else {
      lastRideAmount = 0;
    }

    gameActive = false;
    currentBet = 0;

    if (balance <= 0) {
      balance = 0;
      lastRideAmount = 0;
      setState(() => gameMessage = '💸 You are out of money! Take a loan to continue.');
      return;
    }

    setState(() => gameMessage = messages.join(' | '));
  }

  int repayLoanFromWin(int winAmount) {
    if (loanDebt <= 0) return 0;

    var repayment = (winAmount * 0.5).floor();
    if (repayment < 1) repayment = 1;
    if (repayment > loanDebt) repayment = loanDebt;

    loanDebt -= repayment;
    balance -= repayment;
    return repayment;
  }

  void takeLoan(int amount) {
    if (amount <= 0) return;
    balance += amount;
    loanDebt += amount;
    setState(() => gameMessage = '💵 You took out a \$${formatNumber(amount)} loan. Future winnings will repay it.');
  }

  void letItRide() {
    if (gameActive) {
      setState(() => gameMessage = 'Finish the current round first!');
      return;
    }

    if (lastRideAmount <= 0) {
      setState(() => gameMessage = 'No winning bet to ride.');
      return;
    }

    if (lastRideAmount > balance) {
      setState(() => gameMessage = 'You do not have enough balance to let it ride.');
      return;
    }

    currentBet = lastRideAmount;
    setState(() => gameMessage = '🎲 Let It Ride set your next bet to \$${formatNumber(lastRideAmount)}');
  }

  String cardImageUrl(model_card.Card card) {
    final rank = switch (card.rank) {
      'Ace' => 'A',
      'Jack' => 'J',
      'Queen' => 'Q',
      'King' => 'K',
      '10' => '0',
      _ => card.rank,
    };
    final suit = card.suit[0];
    return 'https://deckofcardsapi.com/static/img/$rank$suit.png';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Show confirmation dialog before going back
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Quit Solo Play?'),
            content: const Text('Your progress will be lost.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Quit'),
              ),
            ],
          ),
        );
        return shouldPop ?? false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A472A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D2617),
          title: const Text('Singleplayer Mode'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF0D2617),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Balance', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(
                        '\$${formatNumber(balance)}',
                        style: const TextStyle(color: Colors.green, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Loan', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(
                        '\$${formatNumber(loanDebt)}',
                        style: TextStyle(color: loanDebt > 0 ? Colors.red : Colors.green, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Win Streak', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(
                        '$winStreak',
                        style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Stats', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(
                        'W:$wins L:$losses P:$pushes',
                        style: const TextStyle(color: Colors.cyan, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Center(
                        child: Text(
                          gameMessage,
                          style: const TextStyle(
                            color: Colors.yellow,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Dealer's Hand
                      Column(
                        children: [
                          const Text('Dealer', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: dealerHand.asMap().entries.map((entry) {
                                final index = entry.key;
                                final card = entry.value;
                                final isHidden = hideDealerHoleCard && index == 1;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Image.network(
                                    isHidden ? 'https://deckofcardsapi.com/static/img/back.png' : cardImageUrl(card),
                                    width: 80,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          if (!hideDealerHoleCard)
                            Text(
                              'Score: ${calculateScore(dealerHand)}',
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      // Player's Hand(s)
                      for (int i = 0; i < playerHands.length; i++)
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Hand ${i + 1}',
                                  style: TextStyle(
                                    color: i == currentHandIndex ? Colors.yellow : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Bet: \$${formatNumber(playerBets[i])}',
                                  style: const TextStyle(color: Colors.cyan, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: playerHands[i].map((card) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Image.network(
                                      cardImageUrl(card),
                                      width: 80,
                                      height: 120,
                                      fit: BoxFit.cover,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            Text(
                              handText(playerHands[i]),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF0D2617),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: gameActive && currentHandIndex < playerHands.length ? hit : null,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
                        child: const Text('Hit'),
                      ),
                      ElevatedButton(
                        onPressed: gameActive && currentHandIndex < playerHands.length ? stand : null,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700]),
                        child: const Text('Stand'),
                      ),
                      ElevatedButton(
                        onPressed: canDoubleDown() ? doubleDown : null,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[700]),
                        child: const Text('Double'),
                      ),
                      ElevatedButton(
                        onPressed: canSplit() ? splitHand : null,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                        child: const Text('Split'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: !gameActive ? dealRound : null,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
                        child: const Text('Deal'),
                      ),
                      ElevatedButton(
                        onPressed: letItRide,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700]),
                        child: const Text('Let It Ride'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: betValues.map((bet) {
                      return ElevatedButton(
                        onPressed: !gameActive ? () => placeBet(bet) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: betColors[bet],
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: Text(
                          '\$$bet',
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: !gameActive && currentBet > 0 ? clearBet : null,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900]),
                        child: const Text('Clear Bet'),
                      ),
                      ElevatedButton(
                        onPressed: () => takeLoan(100),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.brown[700]),
                        child: const Text('Loan \$100'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
