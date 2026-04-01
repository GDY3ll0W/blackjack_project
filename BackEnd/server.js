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
    console.log('a user connected', 
socket.id);
        
    socket.on('join_room', (data) => {
        socket.join(data.room);
        console.log(`User joined room: ${data.room}`);
        
io.to(data.room).emit('system message', `$
{data.nickname} has joined the room.`);
     });
     socket.on(`disconnect`, () => {
        console.log('user disconnected');
    });
});

const PORT = 3000;
server.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});