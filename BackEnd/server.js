const express = require('express');
const path = require('path');
const http = require('http');
const { Server } = require('socket.io');
const GameState = require('./models/gameState');

const app = express();
const server = http.createServer(app);

// 1. CLOUD RUN PORT CONFIGURATION
const PORT = process.env.PORT || 8080;

app.use(express.static(path.join(__dirname, 'public')));

// 2. SOCKET.IO & CORS
const io = new Server(server, {
    cors: {
        origin: "*", 
        methods: ["GET", "POST"],
        credentials: true
    }
});

const gameRooms = new Map();

function generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let code = '';
    for (let i = 0; i < 6; i++) {
        code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return gameRooms.has(code) ? generateRoomCode() : code;
}

// Helper to send a consistent state to Flutter
function broadcastUpdate(roomCode, game) {
    io.to(roomCode).emit('playerListUpdate', {
        players: game.getActivePlayers(),
        gameStatus: game.gameStatus,
        currentTurnPlayerId: game.currentTurnPlayerId,
        dealerHand: game.dealerHand,
        roundNumber: game.roundNumber // Added to track rounds
    });
}

io.on('connection', (socket) => {
    console.log(`>>> New Connection: ${socket.id}`);

    // --- CREATE ROOM ---
    socket.on('createRoom', () => {
        try {
            const roomCode = generateRoomCode();
            const gameState = new GameState();
            gameState.gameStatus = 'waiting';
            
            gameState.addPlayer(socket.id); 
            gameRooms.set(roomCode, gameState);
            socket.join(roomCode);

            console.log(`[ROOM CREATED] Code: ${roomCode} | Host: ${socket.id}`);

            socket.emit('roomCreated', { 
                code: roomCode,
                playerId: socket.id,
                players: gameState.getActivePlayers(),
                gameStatus: 'waiting' 
            });
        } catch (err) {
            console.error("CREATE_ROOM ERROR:", err);
        }
    });

    // --- JOIN ROOM ---
    socket.on('joinRoom', (roomCode) => {
        try {
            const cleanCode = roomCode.toUpperCase().trim();
            const game = gameRooms.get(cleanCode);

            if (!game) {
                socket.emit('error', { message: 'Room not found.' });
                return;
            }

            if (game.gameStatus !== 'waiting') {
                socket.emit('error', { message: 'Game already in progress.' });
                return;
            }

            const added = game.addPlayer(socket.id); 

            if (!added) {
                socket.emit('roomFull', { message: "Room is full" });
                return;
            }

            socket.join(cleanCode);
            socket.emit('roomJoined', { 
                room: cleanCode,
                playerId: socket.id,
                players: game.getActivePlayers(),
                gameStatus: game.gameStatus
            });

            broadcastUpdate(cleanCode, game);
        } catch (err) {
            console.error("JOIN_ROOM ERROR:", err);
        }
    });

    // --- READY SYSTEM & ROUND START ---
    socket.on('toggleReady', (roomCode) => {
        try {
            const cleanCode = roomCode.toUpperCase().trim();
            const game = gameRooms.get(cleanCode);

            if (game) {
                game.togglePlayerReady(socket.id); // Triggers logic in gameState.js[cite: 4]
                const players = game.getActivePlayers();
                
                // Logic for transitioning from Lobby to Betting[cite: 4]
                const allReady = players.length >= 2 && players.every(p => p.isReady === true);

                if (allReady && game.gameStatus === 'waiting') {
                    io.to(cleanCode).emit('playerListUpdate', { 
                        players: players, 
                        gameStatus: 'STARTING' 
                    });

                    setTimeout(() => {
                        game.startBettingPhase(); 
                        broadcastUpdate(cleanCode, game);
                    }, 3000); 
                } else {
                    broadcastUpdate(cleanCode, game);
                }
            }
        } catch (err) {
            console.error("TOGGLE_READY ERROR:", err);
        }
    });

    // --- PLACE BET ---
    socket.on('placeBet', ({ roomCode, amount }) => {
        const cleanCode = roomCode.toUpperCase().trim();
        const game = gameRooms.get(cleanCode);
        if (game) {
            const result = game.placeBet(socket.id, amount); // Handles auto-start if all bet
            if (result.error) {
                socket.emit('error', { message: result.error });
            } else {
                broadcastUpdate(cleanCode, game);
            }
        }
    });

    // --- PLAYER ACTIONS (Hit, Stand, Double) ---
    socket.on('playerAction', ({ roomCode, action }) => {
        const cleanCode = roomCode.toUpperCase().trim();
        const game = gameRooms.get(cleanCode);
        if (game) {
            const result = game.playerAction(socket.id, action);
            if (result.error) {
                socket.emit('error', { message: result.error });
            } else {
                broadcastUpdate(cleanCode, game);
            }
        }
    });

    // --- DISCONNECT ---
    socket.on('disconnect', () => {
        console.log(`<<< Disconnected: ${socket.id}`);
        // Optional: Find the room the player was in and remove them
        gameRooms.forEach((game, roomCode) => {
            if (game.players.has(socket.id)) {
                game.removePlayer(socket.id);
                broadcastUpdate(roomCode, game);
            }
        });
    });
});

server.listen(PORT, '0.0.0.0', () => {
    console.log(`\n---------------------------------`);
    console.log(`  BLACKJACK SERVER IS ONLINE`);
    console.log(`  PORT: ${PORT}`);
    console.log(`---------------------------------\n`);
});