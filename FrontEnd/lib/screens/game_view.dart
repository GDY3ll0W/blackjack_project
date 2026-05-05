import 'dart:async';
import 'package:flutter/material.dart';
import '../logic/deck.dart';
import '../models/card.dart' as model_card;
import '../services/audio_service.dart';
import '../services/socket_service.dart';
import '../widgets/playing_card_widget.dart';

class GameView extends StatefulWidget {
  final String nickname;
  final String avatarPath;
  final String? roomCode;
  final bool isMultiplayer;
  final String? playerId;
  final SocketService? socketService;

  const GameView({
    super.key,
    required this.nickname,
    required this.avatarPath,
    this.roomCode,
    this.isMultiplayer = false,
    this.playerId,
    this.socketService,
  });

  @override
  State<GameView> createState() => _GameViewState();
}

enum RoundEffectType { none, win, lose, push }

class _GameViewState extends State<GameView> {
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
  int letItRideCounter = 0;
  String gameMessage = 'Place a bet to start';
  bool gameActive = false;
  bool hideDealerHoleCard = true;
  bool amIReady = false;
  bool hasWon = false;
  RoundEffectType roundEffect = RoundEffectType.none;
  bool resultPop = false;
  int selectedBetAmount = -1;
  bool selectedAllIn = false;
  int hoveredBetAmount = -1;
  bool hoveredAllIn = false;
  bool hoveredClearBet = false;

  // Multiplayer state
  late SocketService socketService;
  String? currentPlayerId;
  List<Map<String, dynamic>> players = [];
  String? currentTurnPlayerId;
  String gameStatus = 'waiting';
  Timer? turnTimer;
  int timeLeft = 30;
  bool isMyTurn = false;
  int roundNumber = 1;
  bool showRoundStartedPopup = false;
  bool showRoundEndedPopup = false;

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
    AudioService.playBackgroundMusic();

    if (widget.isMultiplayer) {
      socketService = widget.socketService ?? SocketService();
      currentPlayerId = widget.playerId;

      // Set up socket listeners
      setupSocketListeners();

      if (widget.socketService == null) {
        // If no socket service provided, we need to connect
        socketService.connect(widget.roomCode ?? '');
      }
    }
  }

  void setupSocketListeners() {
  socketService.onRoomJoined = (data) {
    if (mounted) {
      setState(() {
        currentPlayerId = data['playerId'];
        players = List<Map<String, dynamic>>.from(data['players']);
        gameStatus = data['gameStatus'];
        currentTurnPlayerId = data['currentTurnPlayerId'];

        final me = players.firstWhere((p) => p['id'] == currentPlayerId, orElse: () => {});
        if (me.isNotEmpty) {
          amIReady = me['isReady'] ?? false;
          balance = (me['balance'] ?? balance).toInt();
          loanDebt = (me['loanDebt'] ?? loanDebt).toInt();
          wins = (me['wins'] ?? wins).toInt();
          losses = (me['losses'] ?? losses).toInt();
          pushes = (me['pushes'] ?? pushes).toInt();
          currentBet = (me['bet'] ?? 0).toInt();
        }

        updateMyTurn();
      });
    }
  };

  socketService.onPlayerListUpdate = (data) {
    if (mounted) {
      setState(() {
        // Sync the game phase and whose turn it is
        gameStatus = data['gameStatus']?.toString() ?? gameStatus;
        currentTurnPlayerId = data['currentTurnPlayerId'];
        players = List<Map<String, dynamic>>.from(data['players']);

        // Sync your specific status from the server's player list
        final me = players.firstWhere((p) => p['id'] == currentPlayerId, orElse: () => {});
        if (me.isNotEmpty) {
          amIReady = me['isReady'] ?? false;
          balance = (me['balance'] ?? balance).toInt();
          loanDebt = (me['loanDebt'] ?? loanDebt).toInt();
          wins = (me['wins'] ?? wins).toInt();
          losses = (me['losses'] ?? losses).toInt();
          pushes = (me['pushes'] ?? pushes).toInt();
          currentBet = (me['bet'] ?? 0).toInt();
        }

        updateMyTurn();
        
        // Start turn timer if it's now your turn
        if (isMyTurn && (gameStatus == 'betting' || gameStatus == 'playing')) {
          startTurnTimer();
        }
      });
    }
  };

  socketService.onRoundStarted = (data) {
    if (mounted) {
      setState(() {
        // 1. Sync Dealer Hand from Server
        dealerHand = List<model_card.Card>.from(
          data['dealerHand'].map((card) => model_card.Card.fromJson(card))
        );
        hideDealerHoleCard = true;

        // 2. Sync Game State
        currentTurnPlayerId = data['currentTurnPlayerId'];
        gameStatus = data['status']?.toString() ?? gameStatus;
        gameActive = true;
        players = List<Map<String, dynamic>>.from(data['players']);
        roundNumber = data['roundNumber'] ?? roundNumber;

        // 3. Sync your own hand, bet and stats
        final me = players.firstWhere((p) => p['id'] == currentPlayerId, orElse: () => {});
        if (me.isNotEmpty) {
          playerHands = [
            List<model_card.Card>.from(me['hand'].map((card) => model_card.Card.fromJson(card)))
          ];
          playerBets = [(me['bet'] ?? 0).toInt()];
          currentBet = (me['bet'] ?? 0).toInt();
          balance = (me['balance'] ?? balance).toInt();
          loanDebt = (me['loanDebt'] ?? loanDebt).toInt();
          wins = (me['wins'] ?? wins).toInt();
          losses = (me['losses'] ?? losses).toInt();
          pushes = (me['pushes'] ?? pushes).toInt();
        }

        updateMyTurn();
        gameMessage = isMyTurn ? 'Your turn!' : 'Round Started - Waiting...';
        showRoundStartedPopup = true;
      });
      // Hide popup after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => showRoundStartedPopup = false);
        }
      });
    }
  };

  socketService.onActionResult = (data) {
    if (mounted) {
      setState(() {
        // If the action happened to YOU, update your local hand
        if (data['playerId'] == currentPlayerId) {
          if (data['action'] == 'hit' || data['action'] == 'double_down') {
            playerHands[0].add(model_card.Card.fromJson(data['card']));
          }
        }
        // Update message to show what happened at the table
        String actionMsg;
        if (data['action'] == 'bust') {
          final card = model_card.Card.fromJson(data['card']);
          actionMsg = 'Player ${data['slot'] ?? data['playerId']} got ${card.rank} of ${card.suit} - BUST! (Score: ${data['score']})';
        } else if (data['action'] == 'hit' && data['card'] != null) {
          final card = model_card.Card.fromJson(data['card']);
          actionMsg = 'Player ${data['slot'] ?? data['playerId']} hits - Got ${card.rank} of ${card.suit}';
        } else {
          actionMsg = 'Player ${data['slot'] ?? data['playerId']} ${data['action']}s';
        }
        gameMessage = actionMsg;
      });
    }
  };

  socketService.onRoundEnd = (data) {
    if (mounted) {
      setState(() {
        dealerHand = List<model_card.Card>.from(
          data['dealerHand'].map((card) => model_card.Card.fromJson(card))
        );
        hideDealerHoleCard = false;
        currentTurnPlayerId = null;
        gameStatus = data['status']?.toString() ?? gameStatus;

        for (final result in data['results']) {
          if (result['playerId'] == currentPlayerId) {
            balance = (result['balance'] ?? balance).toInt();

            if (result['result'] == 'win') {
              setRoundEffect(RoundEffectType.win);
              wins++;
            } else if (result['result'] == 'lose') {
              setRoundEffect(RoundEffectType.lose);
              losses++;
            } else {
              setRoundEffect(RoundEffectType.push);
              pushes++;
            }
          }
        }

        gameActive = false;
        currentBet = 0;
        playerBets = [0];
        clearSelectedBet();
        gameMessage = 'Round ended! To start next round, place a bet.';
        showRoundEndedPopup = true;
        roundNumber++;
      });
      // Hide popup after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => showRoundEndedPopup = false);
        }
      });
    }
  };

  socketService.onBetPlaced = (data) {
    if (mounted) {
      setState(() {
        if (data['playerId'] == currentPlayerId) {
          balance = (data['balance'] ?? balance).toInt();
          currentBet = (data['amount'] ?? currentBet).toInt();
          gameMessage = 'Bet confirmed: Ω${data['amount']}';
        }
      });
    }
  };

  socketService.onLoanTaken = (data) {
    if (mounted) {
      setState(() {
        if (data['playerId'] == currentPlayerId) {
          balance = (data['balance'] ?? balance).toInt();
          loanDebt = (data['loanDebt'] ?? loanDebt).toInt();
          gameMessage = 'Loan approved: Ω${data['balance']} available';
        }
      });
    }
  };

  socketService.onBetCancelled = (data) {
    if (mounted) {
      setState(() {
        if (data['playerId'] == currentPlayerId) {
          currentBet = 0;
          clearSelectedBet();
          gameMessage = 'Bet cancelled. Choose another amount.';
        }
      });
    }
  };

  socketService.onError = (data) {
    if (mounted) {
      setState(() {
        gameMessage = 'Error: ${data['message']}';
      });
    }
  };
}

void updateMyTurn() {
  bool wasMyTurn = isMyTurn;
  isMyTurn = currentTurnPlayerId == currentPlayerId;
  
  // If it just became our turn, give visual/audio feedback
  if (isMyTurn && !wasMyTurn) {
    if (gameStatus == 'betting') {
      gameMessage = 'Your turn to bet!';
    } else if (gameStatus == 'playing') {
      gameMessage = 'Your turn! Hit or Stand?';
    }
  }
}

void startTurnTimer() {
  if (turnTimer != null) {
    turnTimer!.cancel();
    turnTimer = null;
  }

  // Only run local visual timer if it's actually our turn
  if (!isMyTurn) return;

  timeLeft = 30;
  turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (mounted) {
      setState(() {
        timeLeft--;
        if (timeLeft <= 0) {
          timer.cancel();
          // Safety: Auto-stand or skip if player is AFK
          if (gameStatus == 'playing') stand();
        }
      });
    }
  });
}

  void placeBet(int amount, {bool fromCustom = false, bool fromAllIn = false}) {
    if (widget.isMultiplayer) {
      if (gameStatus != 'betting') {
        setState(() => gameMessage = 'Betting phase is not active');
        return;
      }
      if (currentBet > 0) {
        setState(() => gameMessage = 'Clear your current bet before choosing another amount');
        return;
      }
      if (amount <= 0 || amount > balance) {
        setState(() => gameMessage = 'Invalid bet amount');
        return;
      }

      socketService.placeBet(widget.roomCode ?? '', amount.toDouble());
      setState(() {
        currentBet = amount;
        selectedBetAmount = fromCustom || fromAllIn ? -1 : amount;
        selectedAllIn = fromAllIn;
        gameMessage = 'Placing bet...';
      });
      return;
    }

    if (gameActive) {
      setState(() => gameMessage = 'Finish the current round first');
      return;
    }

    if (currentBet + amount > balance) {
      setState(() => gameMessage = 'Not enough balance for that bet');
      return;
    }

    currentBet += amount;
    selectedBetAmount = fromCustom || fromAllIn ? -1 : amount;
    selectedAllIn = fromAllIn;

    setState(() => gameMessage = 'Current bet: Ω${formatNumber(currentBet)}');
  }

  void clearSelectedBet() {
    selectedBetAmount = -1;
    selectedAllIn = false;
  }

  void clearBet() {
    if (widget.isMultiplayer) {
      if (gameStatus != 'betting') {
        setState(() => gameMessage = 'You can only clear bets during betting');
        return;
      }
      if (currentBet <= 0) {
        setState(() => gameMessage = 'No bet to clear');
        return;
      }
      socketService.cancelBet(widget.roomCode ?? '');
      currentBet = 0;
      clearSelectedBet();
      setState(() => gameMessage = 'Bet cancelled. Choose a new amount.');
      return;
    }

    if (gameActive) {
      setState(() => gameMessage = 'Finish the current round first');
      return;
    }
    currentBet = 0;
    clearSelectedBet();
    setState(() => gameMessage = 'Bet cleared');
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
    letItRideCounter = 0;
    gameMessage = 'Place a bet to start';
    gameActive = false;
    hideDealerHoleCard = true;
    roundEffect = RoundEffectType.none;
    resultPop = false;
    clearSelectedBet();
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

  void setRoundEffect(RoundEffectType effect) {
    roundEffect = effect;
    resultPop = true;
    if (mounted) {
      setState(() {});
    }
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() {
          roundEffect = RoundEffectType.none;
          resultPop = false;
        });
      }
    });
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
    if (widget.isMultiplayer) {
      // In multiplayer, betting is handled separately
      return;
    }

    // Single player logic
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
      winStreak = 0;
      clearSelectedBet();
      roundEffect = RoundEffectType.push;
      resultPop = true;
      setState(() => gameMessage = '🫧 Both have Blackjack! Push');
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => roundEffect = RoundEffectType.none);
      });
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
      clearSelectedBet();
      roundEffect = RoundEffectType.win;
      resultPop = true;
      setState(() => gameMessage = repayment > 0
          ? '🃏 BLACKJACK! You win! | \$$repayment loan paid'
          : '🃏 BLACKJACK! You win!');
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => roundEffect = RoundEffectType.none);
      });
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
      clearSelectedBet();
      roundEffect = RoundEffectType.lose;
      resultPop = true;
      setState(() => gameMessage = '💀 Dealer has Blackjack!');
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => roundEffect = RoundEffectType.none);
      });
      return;
    }

    setState(() => gameMessage = 'Game started... Hit or Stand');
  }

  void hit() {
    if (widget.isMultiplayer) {
      if (!isMyTurn || gameStatus != 'playing') {
        setState(() => gameMessage = 'Not your turn');
        return;
      }
      socketService.playAction(widget.roomCode ?? '', 'hit');
      return;
    }

    // Single player logic
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
    if (widget.isMultiplayer) {
      if (!isMyTurn || gameStatus != 'playing') {
        setState(() => gameMessage = 'Not your turn');
        return;
      }
      socketService.playAction(widget.roomCode ?? '', 'stand');
      return;
    }

    // Single player logic
    if (!gameActive) {
      setState(() => gameMessage = 'Start a round first!');
      return;
    }

    advanceFromFinishedHand('✋ Hand ${currentHandIndex + 1} stands');
  }

  void doubleDown() {
    if (widget.isMultiplayer) {
      if (!isMyTurn || gameStatus != 'playing') {
        setState(() => gameMessage = 'Not your turn');
        return;
      }
      if (!canDoubleDown()) {
        setState(() => gameMessage = 'Cannot double down now');
        return;
      }
      socketService.playAction(widget.roomCode ?? '', 'double_down');
      return;
    }

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
      letItRideCounter = 0;
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
      winStreak = 0;
      letItRideCounter = 0;
      roundEffect = RoundEffectType.lose;
      resultPop = true;
      setState(() => gameMessage = '💸 You are out of money! Take a loan to continue.');
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => roundEffect = RoundEffectType.none);
      });
      return;
    }

    if (hadWin) {
      roundEffect = RoundEffectType.win;
    } else if (hadLoss) {
      roundEffect = RoundEffectType.lose;
    } else {
      roundEffect = RoundEffectType.push;
    }
    resultPop = true;

    setState(() => gameMessage = messages.join(' | '));
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => roundEffect = RoundEffectType.none);
    });
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
    if (widget.isMultiplayer) {
      if (gameStatus != 'betting') {
        setState(() => gameMessage = 'Loans are only available during betting phase.');
        return;
      }
      socketService.takeLoan(widget.roomCode ?? '', amount);
      return;
    }
    balance += amount;
    loanDebt += amount;
    setState(() => gameMessage = '💵 You took out a \$${formatNumber(amount)} loan. Future winnings will repay it.');
  }

  void letItRide() {
    if (gameActive) {
      setState(() => gameMessage = 'Finish the current round first!');
      return;
    }

    if (winStreak <= 0) {
      setState(() => gameMessage = 'No winning streak to ride.');
      return;
    }

    if (balance <= 0) {
      setState(() => gameMessage = 'You have no balance to ride.');
      return;
    }

    letItRideCounter += 1;
    currentBet = balance;
    clearSelectedBet();
    selectedAllIn = true;
    setState(() => gameMessage = '🎲 Let It Ride! Your bet: Ω${formatNumber(balance)}');
  }

  ButtonStyle buildButtonStyle(Color backgroundColor, {Color? hoverColor}) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) return backgroundColor.withValues(alpha: 0.75);
        if (states.contains(WidgetState.hovered)) return hoverColor ?? backgroundColor.withValues(alpha: 0.9);
        return backgroundColor;
      }),
      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
      shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    );
  }

  Widget buildBetChip(int value) {
    final isSelected = selectedBetAmount == value;
    final isHovered = hoveredBetAmount == value;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hoveredBetAmount = value),
      onExit: (_) => setState(() => hoveredBetAmount = -1),
      child: GestureDetector(
        onTap: () => placeBet(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.identity()..scale(isSelected ? 1.08 : isHovered ? 1.05 : 1.0),
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: betColors[value],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? Colors.amber : Colors.white, width: isSelected ? 3 : 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: isSelected ? 12 : 5,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: Center(
            child: Text('Ω$value', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
      ),
    );
  }

  Widget buildBetActionChip({
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isSelected,
    required bool isHovered,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          hoveredAllIn = label.contains('RIDE') || label.contains('ALL IN');
          hoveredClearBet = label.contains('CLEAR');
        });
      },
      onExit: (_) {
        setState(() {
          hoveredAllIn = false;
          hoveredClearBet = false;
        });
      },
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.identity()..scale(isSelected ? 1.08 : isHovered ? 1.05 : 1.0),
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? Colors.amber : Colors.white, width: isSelected ? 3 : 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: isSelected ? 12 : 5,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 11, height: 1.2)),
          ),
        ),
      ),
    );
  }

  Color getBackgroundColor() {
    switch (roundEffect) {
      case RoundEffectType.win:
        return const Color(0xFF185D2A);
      case RoundEffectType.lose:
        return const Color(0xFF6F2121);
      case RoundEffectType.push:
        return const Color(0xFF1B5F5F);
      case RoundEffectType.none:
        return const Color(0xFF4A6F3C);
    }
  }

  List<BoxShadow> getBackgroundShadow() {
    switch (roundEffect) {
      case RoundEffectType.win:
        return [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.25), blurRadius: 20, spreadRadius: 4)];
      case RoundEffectType.lose:
        return [BoxShadow(color: Colors.redAccent.withValues(alpha: 0.28), blurRadius: 20, spreadRadius: 4)];
      case RoundEffectType.push:
        return [BoxShadow(color: Colors.cyanAccent.withValues(alpha: 0.24), blurRadius: 20, spreadRadius: 4)];
      case RoundEffectType.none:
        return [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 20, spreadRadius: 2)];
    }
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          // Show confirmation dialog before going back
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Exit Game?'),
              content: Text(widget.isMultiplayer
                ? 'Leaving will disconnect you from the room.'
                : 'Your progress will be lost.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Exit'),
                ),
              ],
            ),
          );
          if (shouldPop ?? false && mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: widget.isMultiplayer
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Blackjack - Multiplayer'),
                    Text(
                      'Room: ${widget.roomCode ?? "Unknown"}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                    ),
                  ],
                )
              : const Text('Blackjack - Singleplayer'),
          backgroundColor: Colors.black.withValues(alpha: 0.8),
        ),
        body: Stack(
        children: [
          // BACKGROUND
          AnimatedContainer(
            width: double.infinity,
            height: double.infinity,
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: getBackgroundColor(),
              boxShadow: getBackgroundShadow(),
            ),
            alignment: Alignment.center,
            child: Image.asset(
              widget.isMultiplayer
                  ? 'assets/images/table/DeepBlackjack.png'
                  : 'assets/images/table/DeepBlackjackSolo.png',
              fit: BoxFit.contain,
            ),
          ),
          
          // LOBBY LIST (Top Right) - Only in multiplayer
          if (widget.isMultiplayer)
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                width: 200,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Room Lobby',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...players.map((player) {
                      final isCurrentPlayer = player['id'] == currentPlayerId;
                      final isCurrentTurn = player['id'] == currentTurnPlayerId;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCurrentTurn 
                              ? Colors.amber.withValues(alpha: 0.3)
                              : isCurrentPlayer 
                                  ? Colors.blue.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Player ${player['slot']}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: isCurrentPlayer ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            if (isCurrentTurn) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.access_time, color: Colors.amber, size: 14),
                            ],
                            const Spacer(),
                            Text(
                              'Ω${formatNumber(player['balance'] ?? 0)}',
                              style: const TextStyle(
                                color: Colors.lightGreen,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (players.isEmpty)
                      const Text(
                        'Waiting for players...',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ),

          // TURN TIMER (Top Center) - Only in multiplayer when it's someone's turn
          if (widget.isMultiplayer && isMyTurn && timeLeft > 0)
            Positioned(
              top: 20,
              left: MediaQuery.of(context).size.width / 2 - 50,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber, width: 2),
                ),
                child: Text(
                  'Time: ${timeLeft}s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // ROUND NUMBER (Middle Left) - Only in multiplayer
          if (widget.isMultiplayer)
            Positioned(
              left: 20,
              top: MediaQuery.of(context).size.height / 2 - 50,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber, width: 2),
                ),
                child: Text(
                  'Round $roundNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // PLAYER AVATAR (Top left)
          Positioned(
            left: 16,
            top: 16,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.amber, width: 3),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  widget.avatarPath,
                  fit: BoxFit.cover,
                ), 
              ),
            ),
          ),
          
          // UI LAYER
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // TOP STATS BAR
                    Text('Balance: Ω${formatNumber(balance)}', 
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 10, color: Colors.black)])),
                    const SizedBox(height: 4),
                    Text('Current Bet: Ω${formatNumber(currentBet)}', 
                      style: const TextStyle(color: Colors.white, fontSize: 20, shadows: [Shadow(blurRadius: 10, color: Colors.black)])),
                    const SizedBox(height: 4),
                    Text('Loan Debt: Ω${formatNumber(loanDebt)}', 
                      style: TextStyle(color: loanDebt > 0 ? Colors.orange : Colors.green, fontSize: 20, fontWeight: FontWeight.bold, shadows: const [Shadow(blurRadius: 10, color: Colors.black)])),
                    const SizedBox(height: 4),
                    Text('Wins: $wins | Losses: $losses | Pushes: $pushes', 
                      style: const TextStyle(color: Colors.lightGreen, fontSize: 18, shadows: [Shadow(blurRadius: 10, color: Colors.black)])),
                    const SizedBox(height: 12),
                    AnimatedScale(
                      scale: resultPop ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        gameMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: roundEffect == RoundEffectType.lose ? Colors.red[200] : roundEffect == RoundEffectType.win ? Colors.yellow[200] : Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: const [Shadow(blurRadius: 10, color: Colors.black)],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // DEALER
                    Image.asset(
                      'assets/images/dealer/Dealer.png',
                      width: 60,
                      height: 60,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 8),
                    Text(
                      dealerHand.isEmpty 
                        ? 'Dealer Cards: '
                        : hideDealerHoleCard && dealerHand.length > 1
                          ? 'Dealer Cards: ${dealerHand[0].rank} + ? = ${calculateScore([dealerHand[0]])} shown'
                          : 'Dealer Cards: ${handText(dealerHand)}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // PLAYER HANDS - Display cards only
                    const Text('Player', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    
                    Center(
                      child: Column(
                        children: [
                          for (int i = 0; i < playerHands.length; i++)
                            Column(
                              children: [
                                Text('Player Hand ${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 8),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: playerHands[i].map((card) {
                                      return PlayingCardWidget(
                                        imageUrl: cardImageUrl(card),
                                        rank: card.rank,
                                        suit: card.suit,
                                        hidden: false,
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  playerHands[i].isEmpty 
                                    ? 'Hand ${i + 1}: '
                                    : 'Hand ${i + 1}: ${handText(playerHands[i])}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text('Bet: Ω${formatNumber(playerBets[i])}', style: const TextStyle(color: Colors.lightGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 16),
                              ],
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // ACTION BUTTONS (Hit, Stand, Double Down, Split)
                    if ((widget.isMultiplayer && isMyTurn && gameStatus == 'playing') || (!widget.isMultiplayer && gameActive))
                      Column(
                        children: [
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              ElevatedButton(
                                onPressed: hit,
                                style: buildButtonStyle(Colors.red[700]!, hoverColor: Colors.red[500]),
                                child: const Text('Hit', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              ElevatedButton(
                                onPressed: stand,
                                style: buildButtonStyle(Colors.blue[700]!, hoverColor: Colors.blue[500]),
                                child: const Text('Stand', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              if (!widget.isMultiplayer)
                                ElevatedButton(
                                  onPressed: canDoubleDown() ? doubleDown : null,
                                  style: buildButtonStyle(Colors.purple[700]!, hoverColor: Colors.purple[500]),
                                  child: const Text('Double Down', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              if (!widget.isMultiplayer)
                                ElevatedButton(
                                  onPressed: canSplit() ? splitHand : null,
                                  style: buildButtonStyle(Colors.brown[700]!, hoverColor: Colors.brown[500]),
                                  child: const Text('Split', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    
                    // BET CHIPS - Only show in single player or multiplayer betting phase
                    if ((!widget.isMultiplayer && !gameActive) || (widget.isMultiplayer && gameStatus == 'betting'))
                      Column(
                        children: [
                          const Text('Bet Options', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          if (widget.isMultiplayer)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.red[900]!.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red, width: 2),
                              ),
                              child: const Text(
                                'ALL BETS ARE FINAL ONCE CLICKED - BE WISE!!!!!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: betValues.map(buildBetChip).toList(),
                          ),
                          const SizedBox(height: 10),
                          // CLEAR BET, ALL IN & CUSTOM
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              if (!widget.isMultiplayer)
                                buildBetActionChip(
                                  label: 'CLEAR\nBET',
                                  color: Colors.blue[900]!,
                                  onTap: clearBet,
                                  isSelected: false,
                                  isHovered: hoveredClearBet,
                                ),
                              buildBetActionChip(
                                label: !widget.isMultiplayer && winStreak > 0 ? 'LET IT\nRIDE' : 'ALL IN',
                                color: Colors.red[900]!,
                                onTap: () {
                                  if (widget.isMultiplayer) {
                                    if (gameStatus != 'betting') {
                                      setState(() => gameMessage = 'Betting phase is not active');
                                      return;
                                    }
                                    placeBet(balance);
                                    return;
                                  }
                                  if (winStreak > 0) {
                                    letItRide();
                                    return;
                                  }
                                  currentBet = balance;
                                  selectedBetAmount = -1;
                                  selectedAllIn = true;
                                  setState(() => gameMessage = 'Current bet: Ω${formatNumber(currentBet)}');
                                },
                                isSelected: selectedAllIn,
                                isHovered: hoveredAllIn,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (!widget.isMultiplayer && !gameActive && currentBet > 0)
                            ElevatedButton(
                              onPressed: dealRound,
                              style: buildButtonStyle(Colors.green[700]!, hoverColor: Colors.green[500]),
                              child: const Text('Start Round', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          if (!widget.isMultiplayer && !gameActive && winStreak > 0)
                            const SizedBox(height: 16),
                        ],
                      ),
                    
                    // LOAN OPTIONS (only when balance is 0 and no active bet)
                    if (balance == 0 && currentBet == 0)
                      Column(
                        children: [
                          const Text('Loan Options', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              ElevatedButton(
                                onPressed: () => takeLoan(100),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo[900],
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                                child: const Text('Take \$100 Loan', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              ElevatedButton(
                                onPressed: () => takeLoan(500),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo[900],
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                                child: const Text('Take \$500 Loan', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              ElevatedButton(
                                onPressed: () => takeLoan(1000),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo[900],
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                                child: const Text('Take \$1,000 Loan', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        if (widget.isMultiplayer && (gameStatus == 'waiting' || gameStatus == 'LOBBY' || gameStatus == 'STARTING'))
            _buildLobbyOverlay(),
        ],
      ), // Stack
      ),
    );
  }

  Widget _buildLobbyOverlay() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withValues(alpha: 0.85),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.group, color: Colors.amber, size: 80),
          const SizedBox(height: 20),
          Text("ROOM: ${widget.roomCode}", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Wait for your partners to be ready", style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 40),
          Container(
            width: 350,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)),
            child: Column(
              children: players.map((player) {
                bool ready = player['isReady'] ?? false;
                bool isMe = player['id'] == currentPlayerId;
                return ListTile(
                  leading: CircleAvatar(backgroundColor: isMe ? Colors.amber : Colors.blueGrey),
                  title: Text(isMe ? "You" : "Partner", style: const TextStyle(color: Colors.white)),
                  trailing: Icon(ready ? Icons.check_circle : Icons.hourglass_empty, color: ready ? Colors.green : Colors.grey),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 50),
          SizedBox(
            width: 250,
            height: 60,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: amIReady ? Colors.red : Colors.green),
              onPressed: () {
                socketService.toggleReady(widget.roomCode ?? ''); 
              },
              child: Text(amIReady ? "CANCEL READY" : "READY TO PLAY", style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }


  
  @override
  void dispose() {
    turnTimer?.cancel();
    if (widget.isMultiplayer) {
      socketService.disconnect();
    }
    super.dispose();
  }
}