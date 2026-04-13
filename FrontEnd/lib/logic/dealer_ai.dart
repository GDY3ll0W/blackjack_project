import '../models/card.dart';
import 'deck.dart';

// Assuming a GameState class exists with similar structure
// If not, this can be adapted
class GameState {
  late Deck deck;
  List<Card> dealerHand = [];
  int calculateScore(List<Card> hand) {
    int score = 0;
    int aces = 0;

    for (var card in hand) {
      if (card.rank == 'Ace') {
        aces++;
        score += 11;
      } else {
        score += deck.getCardValue(card);
      }
    }

    // If we are over 21, convert Aces from 11 to 1 one by one
    while (score > 21 && aces > 0) {
      score -= 10;
      aces--;
    }
    return score;
  }
}

class DealerAI {
  /// Checks if the dealer's hand is a "soft" hand
  /// (contains an Ace counted as 11)
  static bool isSoftHand(List<Card> hand, Deck deck) {
    int score = 0;
    int aces = 0;

    for (var card in hand) {
      if (card.rank == 'Ace') {
        aces++;
        score += 11;
      } else {
        score += deck.getCardValue(card);
      }
    }

    // It's a soft hand if we still have an Ace counted as 11
    return aces > 0 && score <= 21;
  }

  /// Plays the dealer's turn
  /// @param gameState - Passes the current game instance
  /// @returns The final state of the dealer's hand and score
  static Map<String, dynamic> playTurn(GameState gameState) {
    int dealerScore = gameState.calculateScore(gameState.dealerHand);
    bool isSoft = isSoftHand(gameState.dealerHand, gameState.deck);

    print('Dealer starts turn with score: $dealerScore (${isSoft ? 'soft' : 'hard'})');

    // Dealer stands on hard 17+, hits on soft 17
    while (dealerScore < 17 || (dealerScore == 17 && isSoftHand(gameState.dealerHand, gameState.deck))) {
      Card? newCard = gameState.deck.dealCard();
      if (newCard != null) {
        gameState.dealerHand.add(newCard);
      }

      dealerScore = gameState.calculateScore(gameState.dealerHand);
      bool isCurrentSoft = isSoftHand(gameState.dealerHand, gameState.deck);

      print('Dealer draws ${newCard?.rank}. New score: $dealerScore (${isCurrentSoft ? 'soft' : 'hard'})');
    }

    print('Dealer final score: $dealerScore');

    return {
      'finalHand': gameState.dealerHand,
      'finalScore': dealerScore
    };
  }
}