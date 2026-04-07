class Deck {
    constructor(numDecks = 5) {
        this.numDecks = numDecks;
        this.cards = [];
        this.initializeDeck();
        this.shuffle();
    }

    initializeDeck() {
        const suits = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];
        const values = ['Ace', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'Jack', 'Queen', 'King'];
        for (let deck = 0; deck < this.numDecks; deck++) {
            for (const suit of suits) {
                for (const rank of values) {
                    this.cards.push({ suit, rank });
                }
            }
        }
    }

    shuffle() {
        for (let i = this.cards.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [this.cards[i], this.cards[j]] = [this.cards[j], this.cards[i]];
        }
    }

    dealCard() {
        return this.cards.pop();
    }

    getCardValue(card) {
        if (['Jack', 'Queen', 'King'].includes(card.rank)) {
            return 10;
        } else if (card.rank === 'Ace') {
            return 11; // Ace can be 1 or 11, but we'll handle that in the game logic
        } else {
            return parseInt(card.rank);
        }
    }

    remainingCards() {
        return this.cards.length;
    }
}

module.exports = Deck;