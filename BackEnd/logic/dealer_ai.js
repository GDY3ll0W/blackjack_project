class DealerAI {
    /**
     * @param {GameState} gameState - Passes the current game instance
     * @returns {Object} The final state of the dealer's hand and score
     */
    static playTurn(gameState) {
        let dealerScore = gameState.calculateScore(gameState.dealerHand);

        console.log(`Dealer starts turn with score: ${dealerScore}`);

        while (dealerScore < 17) {
            const newCard = gameState.deck.dealCard();
            gameState.dealerHand.push(newCard);
            
            dealerScore = gameState.calculateScore(gameState.dealerHand);
            
            console.log(`Dealer draws ${newCard.rank}. New score: ${dealerScore}`);
        }

        return {
            finalHand: gameState.dealerHand,
            finalScore: dealerScore
        };
    }
}

module.exports = DealerAI;