const express = require('express');
const path = require('path');
const http = require('http');
const { Server } = require('socket.io');
const GameState = require('./models/gameState');

const app = express();
const server = http.createServer(app);

/**
 * 1. CLOUD CONFIGURATION
 * Google Cloud Run assigns a dynamic port via the PORT environment variable.
 */
const PORT = process.env.PORT || 8080;

app.use(express.static(path.join(__dirname, 'public')));


/**
 * 2. SOCKET.IO & CORS
 * origin: "*" allows your Firebase Hosting URL to connect.
 */
const io = new Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"],
        credentials: true
    }
});


/**
 * 3. MULTIPLAYER STATE MANAGEMENT
 * We use a Map to keep track of different game instances by their room code.
 */
const gameRooms = new Map();

/**
 * ROOM CODE GENERATOR
 * Generates a unique 6-character alphanumeric room code
 */
function generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let code = '';
    for (let i = 0; i < 6; i++) {
        code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    // Ensure the code doesn't already exist
    if (gameRooms.has(code)) {
        return generateRoomCode(); // Recursively generate if collision
    }
    return code;
}

io.on('connection', (socket) => {
    console.log(`>>> Client Connected: ${socket.id}`);

    /**
     * CREATE ROOM LOGIC
     * Generates a new room code and initializes a game session
     */
    socket.on('createRoom', () => {
        // Clean up previous rooms if user is switching
        const rooms = Array.from(socket.rooms);
        rooms.forEach(r => { if(r !== socket.id) socket.leave(r); });

        const roomCode = generateRoomCode();
        
        // Create a new GameState for the room
        gameRooms.set(roomCode, new GameState());
        console.log(`[Room ${roomCode}] - New Game Room Created by ${socket.id}`);

        // Join the creator to the room
        socket.join(roomCode);
        const roomSize = io.sockets.adapter.rooms.get(roomCode)?.size || 0;

        console.log(`[Room ${roomCode}] - User ${socket.id} joined as creator (${roomSize}/6)`);

        // Send the room code back to the user
        socket.emit('roomCreated', { 
            code: roomCode,
            balance: gameRooms.get(roomCode).playerBalance,
            activePlayers: roomSize
        });

        // Notify everyone in the room
        io.to(roomCode).emit('playerJoined', { count: roomSize });
    });

    /**
     * JOIN ROOM LOGIC
     * This handles creating a "table" for up to 6 classmates.
     */
    socket.on('joinRoom', (roomCode) => {
        // Clean up previous rooms if user is switching
        const rooms = Array.from(socket.rooms);
        rooms.forEach(r => { if(r !== socket.id) socket.leave(r); });

        socket.join(roomCode);

        // If room doesn't exist, create a new GameState for it
        if (!gameRooms.has(roomCode)) {
            gameRooms.set(roomCode, new GameState());
            console.log(`[Room ${roomCode}] - New Game Session Created`);
        }

        const currentGame = gameRooms.get(roomCode);
        const roomSize = io.sockets.adapter.rooms.get(roomCode)?.size || 0;

        // Limit the room to 6 players
        if (roomSize > 6) {
            socket.emit('error', { message: "Table is full! Use a different code." });
            socket.leave(roomCode);
            return;
        }

        console.log(`[Room ${roomCode}] - User ${socket.id} joined (${roomSize}/6)`);

        // Send the initial state back to the user
        socket.emit('initialState', { 
            balance: currentGame.playerBalance,
            room: roomCode,
            activePlayers: roomSize
        });

        // Notify everyone else at the table
        io.to(roomCode).emit('playerJoined', { count: roomSize });
    });

    /**
     * GAMEPLAY: PLACE BET
     */
    socket.on('placeBet', (data) => {
        const roomCode = Array.from(socket.rooms).find(r => r !== socket.id);
        const currentGame = gameRooms.get(roomCode);

        if (currentGame) {
            console.log(`[Room ${roomCode}] - Bet: $${data.amount}`);
            const result = currentGame.startNewGame(data.amount);
            
            if (result.error) {
                socket.emit('error', { message: result.error });
            } else {
                // Broadcast results to the whole room
                io.to(roomCode).emit('gameStarted', result);
            }
        }
    });

    /**
     * GAMEPLAY: ACTIONS (HIT/STAND)
     */
    socket.on('playerAction', (data) => {
        const roomCode = Array.from(socket.rooms).find(r => r !== socket.id);
        const currentGame = gameRooms.get(roomCode);

        if (!currentGame) return;

        if (data.action === 'hit') {
            console.log(`[Room ${roomCode}] - Player Hit`);
            const hitResult = currentGame.playerHit();
            
            // Send the card update to everyone at the table
            io.to(roomCode).emit('cardDealt', hitResult);

            if (hitResult.score > 21) {
                console.log(`[Room ${roomCode}] - Player Bust`);
                io.to(roomCode).emit('gameOver', { 
                    reason: 'Bust', 
                    finalScore: hitResult.score,
                    dealerHand: currentGame.dealerHand
                });
            }
        }

        if (data.action === 'stand') {
            console.log(`[Room ${roomCode}] - Player Stand`);
            // Add your Dealer AI logic here later
            // io.to(roomCode).emit('dealerTurn', ...);
        }
    });

    socket.on('disconnecting', () => {
        const rooms = Array.from(socket.rooms);
        rooms.forEach(roomCode => {
            if(roomCode !== socket.id) {
                const roomSize = (io.sockets.adapter.rooms.get(roomCode)?.size || 1) - 1;
                io.to(roomCode).emit('playerLeft', { count: roomSize });
                
                // Cleanup memory if room is empty
                if (roomSize === 0) {
                    gameRooms.delete(roomCode);
                    console.log(`[Room ${roomCode}] - Session Closed (Empty)`);
                }
            }
        });
    });

    socket.on('disconnect', () => {
        console.log(`<<< Client Disconnected: ${socket.id}`);
    });
});

/**
 * 4. SERVER START
 * '0.0.0.0' is required for Cloud Run to route traffic to the container.
 */
server.listen(PORT, '0.0.0.0', () => {
    console.log(`\n=================================`);
    console.log(`BLACKJACK MULTIPLAYER LIVE`);
    console.log(`PORT: ${PORT}`);
    console.log(`ENV:  Production (Cloud Run)`);
    console.log(`=================================\n`);
});