const express = require('express');
const http = require('http');
const path = require('path');
const socketIO = require('socket.io');
const os = require('os');
const helmet = require('helmet');
const compression = require('compression');
const cors = require('cors');

// Definir la ruta base para el juego
const BASE_PATH = '/tictactoe';

const app = express();
const server = http.createServer(app);
const io = socketIO(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"],
        credentials: true
    },
    path: `${BASE_PATH}/socket.io`,
    transports: ['polling', 'websocket'],
    allowUpgrades: true,
    perMessageDeflate: {
        threshold: 32768
    },
    pingInterval: 25000,
    pingTimeout: 20000
});

// Configurar el puerto desde las variables de entorno o usar 4000 por defecto
const PORT = process.env.PORT || 4000;

// Configuración de seguridad adaptada para WebSockets
app.use(helmet({
    contentSecurityPolicy: false,
    crossOriginEmbedderPolicy: false,
    crossOriginResourcePolicy: false,
    crossOriginOpenerPolicy: false
}));
app.use(compression());
app.use(cors({
    origin: '*',
    credentials: true,
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));

// Middleware para manejar solicitudes OPTIONS pre-flight (importante para WebSockets)
app.options('*', cors());

// Middleware para logging
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
    next();
});

// Límite de tamaño para solicitudes y configuración para WebSockets
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// Habilitar proxy para detectar correctamente la IP del cliente detrás de ngrok
app.set('trust proxy', true);

// Servir archivos estáticos desde el directorio principal en la subruta /tictactoe
app.use(BASE_PATH, express.static(path.join(__dirname, '..'), {
    maxAge: '1d'
}));

// Redireccionar la raíz a la subruta /tictactoe
app.get('/', (req, res) => {
    res.redirect(BASE_PATH);
});

// Almacenar información sobre las salas de juego
const rooms = {};

// Configurar una ruta para verificar el estado del servidor
app.get(`${BASE_PATH}/health`, (req, res) => {
    res.status(200).json({ 
        status: 'ok',
        uptime: process.uptime(),
        timestamp: Date.now(),
        activeSessions: io.engine.clientsCount,
        activeRooms: Object.keys(rooms).length
    });
});

// Ruta para obtener estadísticas del servidor (podría estar protegida en un entorno real)
app.get(`${BASE_PATH}/stats`, (req, res) => {
    const stats = {
        memory: process.memoryUsage(),
        cpu: process.cpuUsage(),
        uptime: process.uptime(),
        rooms: Object.keys(rooms).length,
        players: io.engine.clientsCount,
        basePath: BASE_PATH,
        port: PORT
    };
    res.json(stats);
});

// Agregar endpoint específico para verificar la configuración de la subruta
app.get(`${BASE_PATH}/config`, (req, res) => {
    res.json({
        status: 'ok',
        basePath: BASE_PATH,
        socketPath: `${BASE_PATH}/socket.io`,
        port: PORT
    });
});

// Intervalo para limpiar salas inactivas (cada 30 minutos)
setInterval(() => {
    const now = Date.now();
    Object.keys(rooms).forEach(roomId => {
        if (rooms[roomId].lastActivity && now - rooms[roomId].lastActivity > 30 * 60 * 1000) {
            // Si la sala está inactiva por más de 30 minutos, eliminarla
            try {
                io.to(roomId).emit('roomClosed', { message: 'Sala cerrada por inactividad' });
            } catch (err) {
                console.error(`Error al notificar cierre de sala ${roomId}:`, err);
            }
            delete rooms[roomId];
            console.log(`Sala eliminada por inactividad: ${roomId}`);
        }
    });
}, 30 * 60 * 1000);

// Monitoreo de estado de sockets
setInterval(() => {
    console.log(`Estado del servidor: ${io.engine.clientsCount} clientes conectados | ${Object.keys(rooms).length} salas activas`);
}, 5 * 60 * 1000);

io.on('connection', (socket) => {
    console.log('Usuario conectado:', socket.id);

    // Cuando un usuario crea una sala de juego
    socket.on('createRoom', (roomId) => {
        console.log(`Sala creada: ${roomId} por ${socket.id}`);
        
        // Crear la sala si no existe
        if (!rooms[roomId]) {
            rooms[roomId] = {
                id: roomId,
                players: [socket.id],
                gameState: ['', '', '', '', '', '', '', '', ''],
                currentPlayer: 'X',
                createdAt: Date.now(),
                lastActivity: Date.now()
            };
            socket.join(roomId);
            socket.emit('roomCreated', { roomId, player: 'X' });
            // Registrar analíticas
            console.log(`Sala creada: ${roomId} | Total salas: ${Object.keys(rooms).length}`);
        } else {
            socket.emit('error', { message: 'La sala ya existe' });
        }
    });

    // Cuando un usuario se une a una sala
    socket.on('joinRoom', (roomId) => {
        console.log(`Intento de unirse a sala: ${roomId} por ${socket.id}`);
        
        // Verificar si la sala existe y hay espacio
        if (rooms[roomId] && rooms[roomId].players.length === 1) {
            rooms[roomId].players.push(socket.id);
            rooms[roomId].lastActivity = Date.now();
            socket.join(roomId);
            socket.emit('roomJoined', { roomId, player: 'O' });
            
            // Notificar a ambos jugadores que la partida puede comenzar
            io.to(roomId).emit('gameStart', { roomId, gameState: rooms[roomId].gameState, currentPlayer: rooms[roomId].currentPlayer });
            
            // Registrar analíticas
            console.log(`Jugador unido a sala: ${roomId} | Sala completa y juego iniciado`);
        } else if (!rooms[roomId]) {
            socket.emit('error', { message: 'La sala no existe' });
        } else {
            socket.emit('error', { message: 'La sala está llena' });
        }
    });

    // Cuando un jugador hace un movimiento
    socket.on('makeMove', (data) => {
        const { roomId, cellIndex, player } = data;
        
        if (rooms[roomId] && 
            rooms[roomId].gameState[cellIndex] === '' && 
            rooms[roomId].currentPlayer === player) {
            
            // Actualizar el estado del juego
            rooms[roomId].gameState[cellIndex] = player;
            rooms[roomId].currentPlayer = player === 'X' ? 'O' : 'X';
            rooms[roomId].lastActivity = Date.now();
            
            // Enviar el estado actualizado a todos los jugadores en la sala
            io.to(roomId).emit('gameUpdate', {
                gameState: rooms[roomId].gameState,
                currentPlayer: rooms[roomId].currentPlayer,
                lastMove: { cellIndex, player }
            });
        }
    });

    // Cuando un jugador quiere reiniciar el juego
    socket.on('restartGame', (roomId) => {
        if (rooms[roomId]) {
            rooms[roomId].gameState = ['', '', '', '', '', '', '', '', ''];
            rooms[roomId].currentPlayer = 'X';
            rooms[roomId].lastActivity = Date.now();
            io.to(roomId).emit('gameRestart', {
                gameState: rooms[roomId].gameState,
                currentPlayer: rooms[roomId].currentPlayer
            });
            console.log(`Juego reiniciado en sala: ${roomId}`);
        }
    });

    // Obtener lista de salas disponibles
    socket.on('getRooms', () => {
        const availableRooms = {};
        
        Object.keys(rooms).forEach(roomId => {
            if (rooms[roomId].players.length === 1) {
                availableRooms[roomId] = {
                    id: roomId,
                    players: rooms[roomId].players.length,
                    createdAt: rooms[roomId].createdAt
                };
            }
        });
        
        socket.emit('roomsList', availableRooms);
        console.log(`Lista de salas enviada. Salas disponibles: ${Object.keys(availableRooms).length}`);
    });
    
    // Manejar ping para mantener activas las conexiones
    socket.on('ping', (data) => {
        const { roomId } = data;
        if (roomId && rooms[roomId]) {
            rooms[roomId].lastActivity = Date.now();
        }
        socket.emit('pong', { timestamp: Date.now() });
    });

    // Cuando un usuario se desconecta
    socket.on('disconnect', () => {
        console.log('Usuario desconectado:', socket.id);
        
        // Buscar y limpiar las salas donde estaba este jugador
        Object.keys(rooms).forEach(roomId => {
            const room = rooms[roomId];
            const playerIndex = room.players.indexOf(socket.id);
            
            if (playerIndex !== -1) {
                room.players.splice(playerIndex, 1);
                
                // Si no quedan jugadores, eliminar la sala
                if (room.players.length === 0) {
                    delete rooms[roomId];
                    console.log(`Sala eliminada: ${roomId}`);
                } else {
                    // Notificar al otro jugador que su oponente se desconectó
                    io.to(roomId).emit('playerDisconnected');
                }
            }
        });
    });
});

// Función para obtener la IP del servidor en la red
function getServerIP() {
    const interfaces = os.networkInterfaces();
    for (const devName in interfaces) {
        const iface = interfaces[devName];
        for (const alias of iface) {
            if (alias.family === 'IPv4' && !alias.internal) {
                return alias.address;
            }
        }
    }
    return 'localhost';
}

// Puerto ya definido al inicio (PORT = process.env.PORT || 4000)

// Manejar errores del servidor
server.on('error', (error) => {
    console.error('Error en el servidor:', error);
});

// Iniciar el servidor
server.listen(PORT, '0.0.0.0', () => {
    const serverIP = getServerIP();
    const nodeEnv = process.env.NODE_ENV || 'development';
    console.log('===========================================');
    console.log(`Servidor Tic Tac Toe en línea (Entorno: ${nodeEnv})`);
    console.log(`Puerto: ${PORT}`);
    console.log(`Ruta base: ${BASE_PATH}`);
    console.log(`Acceso local: http://localhost:${PORT}${BASE_PATH}`);
    console.log(`Acceso en red: http://${serverIP}:${PORT}${BASE_PATH}`);
    console.log(`URL para Socket.IO: ${BASE_PATH}/socket.io`);
    console.log(`Transportes Socket.IO: ${io.engine.opts.transports.join(', ')}`);
    console.log(`Memoria disponible: ${Math.round(os.freemem() / 1024 / 1024)}MB / ${Math.round(os.totalmem() / 1024 / 1024)}MB`);
    console.log(`Node.js ${process.version}`);
    console.log('===========================================');
});

// Manejar procesos de cierre
process.on('SIGINT', () => {
    console.log('Cerrando el servidor...');
    io.close();
    server.close();
    process.exit(0);
});

process.on('uncaughtException', (error) => {
    console.error('Error no capturado:', error);
    // Registrar el error pero mantener el servidor funcionando
    // En un entorno de producción real, podríamos querer reiniciar el proceso
    // o notificar a un servicio de monitoreo
});

// Manejar promesas rechazadas no capturadas
process.on('unhandledRejection', (reason, promise) => {
    console.error('Promesa rechazada no manejada:', reason);
});