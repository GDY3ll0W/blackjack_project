const express = require('express');
const path = require('path');
const http = require('http');
const { Server } = require('socket.io');
const GameState = require('./models/gameState');

const app = express();
const server = http.createServer(app);
app.use(express.static(path.join(__dirname, 'public')));

// Configure Socket.io with CORS for Flutter/Web development
const io = new Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"],
        allowedHeaders: ["ngrok-skip-browser-warning"],
        credentials: true
    }
});

const game = new GameState();

io.on('connection', (socket) => {
    console.log('--- Dev Client Connected ---');
    console.log('ID:', socket.id);

    // Immediately sends the player's starting balance to $100 when they connect
    socket.emit('initialState', { 
        balance: game.playerBalance 
    });

    // Handles Betting and Game Start
    socket.on('placeBet', (data) => {
        console.log(`Bet Received: $${data.amount}`);
        
        const result = game.startNewGame(data.amount);
        
        if (result.error) {
            console.log('Error:', result.error);
            socket.emit('error', { message: result.error });
        } else {
            console.log('Game Started. Hands Dealt.');
            // Send hands, score, and updates balance to Flutter
            socket.emit('gameStarted', result);
        }
    });

    // Handles Gameplay Actions (Hit/Stand)
    socket.on('playerAction', (data) => {
        if (data.action === 'hit') {
            console.log('Player chooses to Hit');
            const hitResult = game.playerHit();
            
            socket.emit('cardDealt', hitResult);

            // Checks for Bust
            if (hitResult.score > 21) {
                console.log('Player Busted!');
                socket.emit('gameOver', { 
                    reason: 'Bust', 
                    finalScore: hitResult.score,
                    dealerHand: game.dealerHand
                });
            }
        }

        if (data.action === 'stand') {
            console.log('Player stands. Dealer\'s turn.');
            // We will add the dealer_ai logic here next!
        }
    });

    socket.on('disconnect', () => {
        console.log('Client disconnected');
    });
});

const PORT = 3000;
server.listen(PORT, () => {
    console.log(`=================================`);
    console.log(`BLACKJACK BACKEND RUNNING ON PORT ${PORT}`);
    console.log(`=================================`);
});