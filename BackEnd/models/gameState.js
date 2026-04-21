class GameState {
    constructor() {
        this.deck = this.generateDeck(5);
        this.playerHand = [];
        this.dealerHand = [];
        this.playerBalance = 100; 
        this.currentBet = 0;
        this.gameStatus = 'betting';
    }

    // Since deck.js is gone, we generate the deck internally
    generateDeck(numDecks) {
        const suits = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];
        const ranks = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'Jack', 'Queen', 'King', 'Ace'];
        let cards = [];
        for (let i = 0; i < numDecks; i++) {
            for (const suit of suits) {
                for (const rank of ranks) {
                    cards.push({ rank, suit });
                }
            }
        }
        // Fisher-Yates Shuffle
        for (let i = cards.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [cards[i], cards[j]] = [cards[j], cards[i]];
        }
        return { 
            cards, 
            dealCard: function() { return this.cards.pop(); } 
        };
    }

    getCardValue(card) {
        if (['Jack', 'Queen', 'King'].includes(card.rank)) return 10;
        if (card.rank === 'Ace') return 11;
        return parseInt(card.rank);
    }

    calculateScore(hand) {
        let score = 0;
        let aces = 0;
        hand.forEach(card => {
            if (card.rank === 'Ace') {
                aces += 1;
                score += 11;
            } else {
                score += this.getCardValue(card);
            }
        });
        while (score > 21 && aces > 0) {
            score -= 10;
            aces -= 1;
        }
        return score;
    }

    startNewGame(betAmount) {
        if (betAmount > this.playerBalance) return { error: "Insufficient funds" };
        if (this.deck.cards.length < 20) this.deck = this.generateDeck(5);

        this.currentBet = betAmount;
        this.playerBalance -= betAmount;
        this.playerHand = [this.deck.dealCard(), this.deck.dealCard()];
        this.dealerHand = [this.deck.dealCard(), this.deck.dealCard()];
        
        const playerScore = this.calculateScore(this.playerHand);
        const dealerScore = this.calculateScore(this.dealerHand);
        
        this.gameStatus = (playerScore === 21 || dealerScore === 21) ? 'gameOver' : 'playing';

        return {
            playerHand: this.playerHand,
            dealerHand: this.gameStatus === 'playing' ? [this.dealerHand[0], { rank: 'Hidden', suit: 'Hidden' }] : this.dealerHand,
            balance: this.playerBalance,
            playerScore,
            status: this.gameStatus
        };
    }

    playerHit() {
        const newCard = this.deck.dealCard();
        this.playerHand.push(newCard);
        const score = this.calculateScore(this.playerHand);
        if (score > 21) this.gameStatus = 'gameOver';
        return { card: newCard, score, isBust: score > 21, status: this.gameStatus };
    }

    playerStand() {
        this.gameStatus = 'dealer_turn';
        let dealerScore = this.calculateScore(this.dealerHand);
        // Dealer AI: Stand on 17
        while (dealerScore < 17) {
            this.dealerHand.push(this.deck.dealCard());
            dealerScore = this.calculateScore(this.dealerHand);
        }
        return this.determineWinner(dealerScore);
    }

    determineWinner(dealerScore) {
        const playerScore = this.calculateScore(this.playerHand);
        let payout = 0;
        if (playerScore <= 21 && (dealerScore > 21 || playerScore > dealerScore)) {
            payout = this.currentBet * 2;
        } else if (playerScore === dealerScore) {
            payout = this.currentBet;
        }
        this.playerBalance += payout;
        this.gameStatus = 'gameOver';
        return {
            dealerHand: this.dealerHand,
            dealerScore,
            playerScore,
            newBalance: this.playerBalance
        };
    }
}

module.exports = GameState;