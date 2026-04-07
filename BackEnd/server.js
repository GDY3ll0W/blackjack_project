const Deck = require('./logic/deck');
const myDeck = new Deck(5);
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
    cors: {
        origin: "http://localhost:3000",
        methods: ["GET", "POST"]
    }
});

io.on('connection', (socket) => {
    console.log('a user connected', socket.id);

    socket.on('playerAction', (data) => {
        if (data.action === 'hit') {
            const dealtCard = myDeck.dealCard();
            socket.emit('cardDealt', { card: dealtCard });
        }
    });

    socket.on('disconnect', () => {
        console.log('user disconnected');
    });
});

const PORT = 3000;
server.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});