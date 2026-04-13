const Deck = require('../logic/deck'); // Ensure this points to your deck.js file

class GameState {
    constructor() {
        this.deck = new Deck(5);
        this.playerHand = [];
        this.dealerHand = [];
        this.playerBalance = 100; // Starting Currency
        this.currentBet = 0;
        this.gameStatus = 'betting'; // 'betting', 'playing', 'dealer_turn', 'gameOver'
    }

    // Helper: Check if deck needs reshuffling (25% threshold)
    shouldReshuffleDeck() {
        return this.deck.cards.length < (this.deck.decks * 52 * 0.25);
    }

    // --- Core Logic: Scoring ---
    // This handles the Ace being 1 or 11 automatically
    calculateScore(hand) {
        let score = 0;
        let aces = 0;

        hand.forEach(card => {
            if (card.rank === 'Ace') {
                aces += 1;
                score += 11;
            } else {
                // Uses the getCardValue method from your Deck class
                score += this.deck.getCardValue(card);
            }
        });

        // If we are over 21, convert Aces from 11 to 1 one by one
        while (score > 21 && aces > 0) {
            score -= 10;
            aces -= 1;
        }
        return score;
    }

    // Action: Start Game
    startNewGame(betAmount) {
        if (betAmount > this.playerBalance) {
            return { error: "Insufficient funds" };
        }

        // Reshuffle if needed
        if (this.shouldReshuffleDeck()) {
            this.deck = new Deck(5);
        }

        // Deduct bet from wallet
        this.currentBet = betAmount;
        this.playerBalance -= betAmount;

        // Reset and Deal (1-1-1-1 sequence)
        this.playerHand = [this.deck.dealCard(), this.deck.dealCard()];
        this.dealerHand = [this.deck.dealCard(), this.deck.dealCard()];
        
        // Check for natural blackjack
        const playerScore = this.calculateScore(this.playerHand);
        const dealerScore = this.calculateScore(this.dealerHand);
        
        if (playerScore === 21 && dealerScore === 21) {
            // Both have blackjack - Push
            this.gameStatus = 'gameOver';
            this.playerBalance += this.currentBet;
            return {
                message: 'Push (Both have Blackjack!)',
                playerHand: this.playerHand,
                dealerHand: this.dealerHand,
                playerScore: playerScore,
                dealerScore: dealerScore,
                balance: this.playerBalance,
                status: this.gameStatus
            };
        } else if (playerScore === 21) {
            // Player natural blackjack - win with 3:2 payout
            this.gameStatus = 'gameOver';
            this.playerBalance += Math.floor(this.currentBet * 2.5);
            return {
                message: 'Blackjack! You Win!',
                playerHand: this.playerHand,
                dealerHand: this.dealerHand,
                playerScore: playerScore,
                dealerScore: dealerScore,
                balance: this.playerBalance,
                status: this.gameStatus
            };
        } else if (dealerScore === 21) {
            // Dealer natural blackjack - player loses
            this.gameStatus = 'gameOver';
            return {
                message: 'Dealer has Blackjack. You Lose.',
                playerHand: this.playerHand,
                dealerHand: this.dealerHand,
                playerScore: playerScore,
                dealerScore: dealerScore,
                balance: this.playerBalance,
                status: this.gameStatus
            };
        }
        
        this.gameStatus = 'playing';

        return {
            playerHand: this.playerHand,
            // Hide the dealer's second card for the initial UI display
            dealerHand: [this.dealerHand[0], { rank: 'Hidden', suit: 'Hidden' }],
            balance: this.playerBalance,
            playerScore: playerScore,
            status: this.gameStatus
        };
    }

    // Action: Hit 
    playerHit() {
        // Validate game state
        if (this.gameStatus !== 'playing') {
            return { error: "Invalid game state for hit" };
        }

        const newCard = this.deck.dealCard();
        this.playerHand.push(newCard);
        
        const score = this.calculateScore(this.playerHand);
        
        if (score > 21) {
            this.gameStatus = 'gameOver';
        }

        return {
            card: newCard,
            score: score,
            isBust: score > 21,
            message: score > 21 ? 'Bust! Dealer Wins.' : '',
            status: this.gameStatus
        };
    }

    // Action: Stand
    playerStand() {
        // Validate game state
        if (this.gameStatus !== 'playing') {
            return { error: "Invalid game state for stand" };
        }

        this.gameStatus = 'dealer_turn';
        
        // Dealer AI rules (Dealer hits until 17, including soft 17)
        const DealerAI = require('../logic/dealer_ai'); 
        const aiResult = DealerAI.playTurn(this);
        
        return this.determineWinner(aiResult.finalScore);
    }

    // Logic: Result Calculation
    determineWinner(dealerScore) {
        const playerScore = this.calculateScore(this.playerHand);
        let resultMessage = '';
        let payout = 0;

        if (playerScore > 21) {
            resultMessage = 'Bust! Dealer Wins.';
            // Player loses the bet (already deducted at start)
        } else if (dealerScore > 21) {
            resultMessage = 'Dealer Busts! You Win!';
            payout = this.currentBet * 2; // Return bet + winnings
        } else if (playerScore > dealerScore) {
            resultMessage = 'You Win!';
            payout = this.currentBet * 2; // Return bet + winnings
        } else if (playerScore < dealerScore) {
            resultMessage = 'Dealer Wins.';
            // Player loses the bet
        } else {
            resultMessage = 'Push (Tie).';
            payout = this.currentBet; // Return original bet
        }

        this.gameStatus = 'gameOver';
        this.playerBalance += payout;
        this.currentBet = 0;

        return {
            message: resultMessage,
            dealerHand: this.dealerHand,
            dealerScore: dealerScore,
            playerScore: playerScore,
            newBalance: this.playerBalance
        };
    }
}

module.exports = GameState;