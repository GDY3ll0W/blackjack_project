class GameState {
    constructor() {
        this.deck = this.generateDeck(6);
        this.players = new Map(); // playerId -> { id, slot, hand, balance, bet, status, isReady, ... }
        this.dealerHand = [];
        this.currentPlayerIndex = 0;
        this.gameStatus = 'waiting'; // waiting, betting, playing, dealer_turn, game_over
        this.turnTimer = null;
        this.currentTurnPlayerId = null;
        this.playerOrder = []; // Array of player IDs in turn order
        this.roundNumber = 1; // Added to track the multiplayer round loop
    }

    // --- CORE DECK & SCORING (Kept original logic) ---
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

    // --- PLAYER MANAGEMENT ---
    addPlayer(playerId) {
        if (this.players.size >= 6) return false;
        if (this.players.has(playerId)) return true;

        const usedSlots = new Set(Array.from(this.players.values()).map(p => p.slot));
        let slot = 1;
        while (usedSlots.has(slot) && slot <= 6) { slot++; }

        this.players.set(playerId, {
            id: playerId,
            slot: slot,
            hand: [],
            balance: 1000,
            bet: 0,
            status: 'waiting',
            isReady: false, 
            wins: 0,
            losses: 0,
            pushes: 0,
            loanDebt: 0
        });

        this.playerOrder.push(playerId);
        this.playerOrder.sort((a, b) => this.players.get(a).slot - this.players.get(b).slot);
        return true;
    }

    removePlayer(playerId) {
        if (!this.players.has(playerId)) return;
        this.players.delete(playerId);
        this.playerOrder = this.playerOrder.filter(id => id !== playerId);

        if (this.currentTurnPlayerId === playerId) {
            this.nextTurn();
        }
    }

    getActivePlayers() {
        return Array.from(this.players.values())
            .filter(p => p.status !== 'disconnected')
            .sort((a, b) => a.slot - b.slot);
    }

    // --- NEW MULTIPLAYER ROUND FLOW ---
    togglePlayerReady(playerId) {
        const player = this.players.get(playerId);
        if (player) {
            player.isReady = !player.isReady; // Toggle readiness
            
            // Auto-transition from Lobby to Betting if everyone is ready
            const activePlayers = this.getActivePlayers();
            const allReady = activePlayers.length >= 2 && activePlayers.every(p => p.isReady); //[cite: 4]

            if (allReady && this.gameStatus === 'waiting') {
                this.startBettingPhase();
            }
            return player.isReady;
        }
        return false;
    }

    startBettingPhase() {
        if (this.players.size < 2) return;

        this.gameStatus = 'betting'; //
        this.currentPlayerIndex = 0;
        
        // Reset player states for the new round
        for (const player of this.players.values()) {
            player.status = 'waiting';
            player.isReady = false; //[cite: 4] Reset for the "Betting Ready" check
            player.hand = [];
            player.bet = 0;
        }

        this.currentTurnPlayerId = null; // Everyone bets simultaneously
        this.startTurnTimer(); // Global phase timer
    }

    placeBet(playerId, amount) {
        const player = this.players.get(playerId);
        if (!player || this.gameStatus !== 'betting') {
            return { error: "Cannot place bet at this time" };
        }

        if (amount > player.balance) return { error: "Insufficient funds" };
        if (amount <= 0) return { error: "Invalid bet amount" };

        player.bet = amount;
        player.balance -= amount;
        player.status = 'bet_placed';
        player.isReady = true; //[cite: 4] Mark as ready once bet is in

        this.checkAllBetsPlaced();
        return { success: true, balance: player.balance };
    }

    checkAllBetsPlaced() {
        const activePlayers = this.getActivePlayers();
        const allBetOrReady = activePlayers.every(p => p.status === 'bet_placed' || p.status === 'skipped'); //[cite: 4]

        if (allBetOrReady) {
            this.startRound();
        }
    }

    // --- GAMEPLAY PHASE ---
    startRound() {
        if (this.deck.cards.length < this.players.size * 12) {
            this.deck = this.generateDeck(6);
        }

        this.dealerHand = [this.deck.dealCard(), this.deck.dealCard()];

        for (const player of this.players.values()) {
            if (player.status === 'bet_placed') {
                player.hand = [this.deck.dealCard(), this.deck.dealCard()];
                player.status = 'playing';
                player.isReady = false; //[cite: 4] Reset for action phase
            }
        }

        this.gameStatus = 'playing';
        this.currentTurnPlayerId = this.playerOrder.find(id => this.players.get(id)?.status === 'playing') || null; //[cite: 1]
        this.startTurnTimer();

        return {
            dealerHand: [this.dealerHand[0], { rank: 'Hidden', suit: 'Hidden' }],
            status: this.gameStatus
        };
    }

    startTurnTimer() {
        if (this.turnTimer) clearTimeout(this.turnTimer);
        this.turnTimer = setTimeout(() => {
            this.skipTurn();
        }, 30000); 
    }

    skipTurn() {
        this.nextTurn();
    }

    nextTurn() {
        if (this.turnTimer) clearTimeout(this.turnTimer);
        this.turnTimer = null;

        if (this.playerOrder.length === 0) {
            this.gameStatus = 'waiting';
            return;
        }

        let nextIndex = (this.playerOrder.indexOf(this.currentTurnPlayerId) + 1) % this.playerOrder.length;
        let attempts = 0;
        while (attempts < this.playerOrder.length) {
            const nextPlayerId = this.playerOrder[nextIndex];
            const player = this.players.get(nextPlayerId);
            if (player && player.status === 'playing') {
                this.currentTurnPlayerId = nextPlayerId;
                this.startTurnTimer();
                return;
            }
            nextIndex = (nextIndex + 1) % this.playerOrder.length;
            attempts++;
        }

        this.dealerTurn(); // If no more players are 'playing', it's dealer's turn
    }

    playerAction(playerId, action) {
        const player = this.players.get(playerId);

        if (!player || player.id !== this.currentTurnPlayerId || this.gameStatus !== 'playing') {
            return { error: "Not your turn" };
        }

        if (action === 'hit') {
            const newCard = this.deck.dealCard();
            player.hand.push(newCard);
            const score = this.calculateScore(player.hand);

            if (score > 21) {
                player.status = 'bust';
                this.nextTurn();
                return { action: 'bust', card: newCard, score, playerId };
            }
            return { action: 'hit', card: newCard, score, playerId };
        }

        if (action === 'stand') {
            player.status = 'stood';
            this.nextTurn();
            return { action: 'stand', playerId };
        }

        if (action === 'double_down') {
            if (player.hand.length !== 2 || player.balance < player.bet) return { error: "Cannot double down" };
            player.balance -= player.bet;
            player.bet *= 2;
            const newCard = this.deck.dealCard();
            player.hand.push(newCard);
            player.status = this.calculateScore(player.hand) > 21 ? 'bust' : 'stood';
            this.nextTurn();
            return { action: 'double_down', card: newCard, score: this.calculateScore(player.hand), newBet: player.bet, playerId };
        }

        return { error: "Invalid action" };
    }

    // --- RESOLUTION ---
    dealerTurn() {
        this.gameStatus = 'dealer_turn';
        let dealerScore = this.calculateScore(this.dealerHand);

        while (dealerScore < 17) {
            this.dealerHand.push(this.deck.dealCard());
            dealerScore = this.calculateScore(this.dealerHand);
        }

        this.resolveRound(dealerScore);
    }

    resolveRound(dealerScore) {
        this.gameStatus = 'game_over'; //[cite: 1]
        const results = [];

        for (const player of this.players.values()) {
            if (player.status === 'waiting' || player.status === 'skipped') continue;

            const playerScore = this.calculateScore(player.hand);
            let result = '';

            if (player.status === 'bust') {
                player.losses++;
                result = 'lose';
            } else if (dealerScore > 21 || playerScore > dealerScore) {
                player.balance += (player.bet * 2);
                player.wins++;
                result = 'win';
            } else if (playerScore === dealerScore) {
                player.balance += player.bet;
                player.pushes++;
                result = 'push';
            } else {
                player.losses++;
                result = 'lose';
            }

            results.push({ playerId: player.id, result, balance: player.balance });
            
            // Reset player for the next round loop[cite: 1]
            player.isReady = false; 
            player.status = 'waiting';
        }

        this.roundNumber++; //[cite: 1]

        // 5 second delay to let players see the Round Results before resetting[cite: 1]
        setTimeout(() => {
            this.startBettingPhase();
        }, 5000);

        return { dealerHand: this.dealerHand, dealerScore, results, nextRound: this.roundNumber };
    }
}

module.exports = GameState;