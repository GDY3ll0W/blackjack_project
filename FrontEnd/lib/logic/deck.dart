import 'dart:math';
import '../models/card.dart';

class Deck {
  int numDecks;
  List<Card> cards = [];

  Deck({this.numDecks = 5}) {
    initializeDeck();
    shuffle();
  }

  void initializeDeck() {
    const suits = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];
    const values = [
      'Ace',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '10',
      'Jack',
      'Queen',
      'King',
    ];
    for (int deck = 0; deck < numDecks; deck++) {
      for (final suit in suits) {
        for (final rank in values) {
          cards.add(Card(suit, rank));
        }
      }
    }
  }

  void shuffle() {
    final random = Random();
    for (int i = cards.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = cards[i];
      cards[i] = cards[j];
      cards[j] = temp;
    }
  }

  Card? dealCard() {
    if (cards.isNotEmpty) {
      return cards.removeLast();
    }
    return null;
  }

  int getCardValue(Card card) {
    if (['Jack', 'Queen', 'King'].contains(card.rank)) {
      return 10;
    } else if (card.rank == 'Ace') {
      return 11;
    } else {
      return int.parse(card.rank);
    }
  }

  int remainingCards() {
    return cards.length;
  }
}
