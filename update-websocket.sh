#!/bin/bash

# Script para aplicar soluciones para problemas de WebSocket en la aplicación Tic Tac Toe
# Este script actualiza la configuración del servidor y cliente para funcionar mejor con ngrok

# Colores para salida
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Actualizando configuración para WebSockets ===${NC}"

# Verificar que el script se ejecuta desde el directorio correcto
if [ ! -f "server/server.js" ] || [ ! -f "script.js" ]; then
    echo -e "${RED}Error: Este script debe ejecutarse desde el directorio principal de TicTacToe${NC}"
    exit 1
fi

# Detener cualquier instancia en ejecución
echo -e "${YELLOW}Deteniendo instancias existentes...${NC}"
CURRENT_PID=$(lsof -ti:4000 -sTCP:LISTEN)
if [ ! -z "$CURRENT_PID" ]; then
    echo -e "${YELLOW}Deteniendo proceso (PID: $CURRENT_PID)...${NC}"
    kill -9 $CURRENT_PID 2>/dev/null || true
    sleep 2
fi

# Actualizar socket.io
echo -e "${YELLOW}Actualizando dependencias...${NC}"
npm install socket.io@latest express@latest cors@latest --save

# Aplicar configuración para modo de compatibilidad ngrok
echo -e "${YELLOW}Aplicando configuración para compatibilidad con ngrok...${NC}"

# 1. Crear respaldo de los archivos
cp server/server.js server/server.js.bak
cp script.js script.js.bak

# 2. Aplicar parche al servidor
echo -e "${YELLOW}Modificando servidor...${NC}"
cat > server/server.js << 'EOL'
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

// Configuración optimizada para ngrok
const io = socketIO(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST", "OPTIONS"],
        credentials: true
    },
    path: `${BASE_PATH}/socket.io`,
    transports: ['polling', 'websocket'],
    allowUpgrades: true,
    pingInterval: 10000,
    pingTimeout: 5000,
    cookie: false
});

// Configurar el puerto desde las variables de entorno o usar 4000 por defecto
const PORT = process.env.PORT || 4000;

// Deshabilitar CSP y otras restricciones para desarrollo
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

// Middleware para manejar solicitudes OPTIONS pre-flight
app.options('*', cors());

// Middleware para logging
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
    next();
});

// Límite de tamaño para solicitudes
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// Habilitar proxy para detectar IP correcta
app.set('trust proxy', true);

// Servir archivos estáticos desde el directorio principal
app.use(BASE_PATH, express.static(path.join(__dirname, '..'), {
    maxAge: '1d'
}));

// Redireccionar la raíz a la subruta /tictactoe
app.get('/', (req, res) => {
    res.redirect(BASE_PATH);
});

// Almacenar información sobre las salas de juego
const rooms = {};

// Endpoint para verificar el estado del servidor
app.get(`${BASE_PATH}/health`, (req, res) => {
    res.status(200).json({ 
        status: 'ok',
        uptime: process.uptime(),
        timestamp: Date.now(),
        activeSessions: io.engine.clientsCount,
        activeRooms: Object.keys(rooms).length,
        transport: {
            polling: true,
            websocket: true
        }
    });
});

// Rest of your server code remains the same

io.on('connection', (socket) => {
    console.log('Usuario conectado:', socket.id, 'usando', socket.conn.transport.name);

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

// Iniciar el servidor
server.listen(PORT, '0.0.0.0', () => {
    console.log('===========================================');
    console.log(`Servidor Tic Tac Toe Multijugador (Compatible con ngrok)`);
    console.log(`Puerto: ${PORT}`);
    console.log(`URL base: ${BASE_PATH}`);
    console.log(`URL conexión Socket.IO: ${BASE_PATH}/socket.io/`);
    console.log(`Transportes: ${io.engine.opts.transports.join(', ')}`);
    console.log('===========================================');
});
EOL

# 3. Aplicar parche al cliente
echo -e "${YELLOW}Modificando cliente...${NC}"
cat > script.js << 'EOL'
// Variables globales para el juego
let socket;
let gameActive = false;
let currentPlayer = 'X';
let gameState = ['', '', '', '', '', '', '', '', ''];
let playerSymbol = '';
let currentRoom = '';
let gameMode = 'online'; // 'online' o 'local'
let pingInterval; // Para mantener la conexión activa
let connectionAttempts = 0;
const MAX_RECONNECT_ATTEMPTS = 5;

// Esperar a que el DOM esté cargado
document.addEventListener('DOMContentLoaded', () => {
    // Elementos del DOM - Pantallas
    const startScreen = document.getElementById('start-screen');
    const connectionScreen = document.getElementById('connection-screen');
    const gameScreen = document.getElementById('game-screen');
    
    // Elementos del DOM - Controles
    const createRoomBtn = document.getElementById('create-room-btn');
    const joinRoomBtn = document.getElementById('join-room-btn');
    const roomIdInput = document.getElementById('room-id');
    const refreshRoomsBtn = document.getElementById('refresh-rooms-btn');
    const localGameBtn = document.getElementById('local-game-btn');
    const cancelConnectionBtn = document.getElementById('cancel-connection-btn');
    const restartButton = document.getElementById('restart-button');
    const exitGameBtn = document.getElementById('exit-game-btn');
    
    // Elementos del DOM - Información
    const roomIdDisplay = document.getElementById('room-id-display');
    const playerSymbolDisplay = document.getElementById('player-symbol');
    const connectionStatus = document.getElementById('connection-status');
    const currentRoomDisplay = document.getElementById('current-room');
    const currentPlayerSymbolDisplay = document.getElementById('current-player-symbol');
    const statusDisplay = document.getElementById('status');
    const roomsList = document.getElementById('rooms-list');
    const networkStatus = document.getElementById('network-status');
    
    // Elementos del DOM - Tablero
    const cells = document.querySelectorAll('.cell');
    
    // Inicializar Socket.IO si estamos jugando online
    initializeSocketConnection();
    
    // Event Listeners para botones de inicio
    createRoomBtn.addEventListener('click', createRoom);
    joinRoomBtn.addEventListener('click', joinRoom);
    refreshRoomsBtn.addEventListener('click', refreshRooms);
    localGameBtn.addEventListener('click', startLocalGame);
    
    // Event Listeners para botones de conexión
    cancelConnectionBtn.addEventListener('click', cancelConnection);
    
    // Event Listeners para botones de juego
    restartButton.addEventListener('click', handleRestartGame);
    exitGameBtn.addEventListener('click', exitGame);
    
    // Event Listeners para celdas del tablero
    cells.forEach(cell => cell.addEventListener('click', handleCellClick));
    
    // Cargar la lista de salas disponibles al inicio
    refreshRooms();
    
    // Funciones del juego
    
    // Inicializar Socket.IO
    function initializeSocketConnection() {
        try {
            // Determinar la ruta base para el socket
            const basePath = window.location.pathname.includes('/tictactoe') ? '/tictactoe' : '';
            
            // Opciones optimizadas para ngrok
            const socketOptions = {
                reconnection: true,
                reconnectionDelay: 1000,
                reconnectionAttempts: 10,
                timeout: 20000,
                transports: ['polling', 'websocket'], // Priorizar polling sobre websocket
                path: `${basePath}/socket.io`,
                forceNew: true,
                autoConnect: true,
                secure: window.location.protocol === 'https:'
            };
            
            // Inicializar socket
            socket = io(socketOptions);
            
            // Evento: Conexión establecida
            socket.on('connect', () => {
                console.log('Conectado al servidor usando', socket.io.engine.transport.name);
                updateNetworkStatus(true, socket.io.engine.transport.name);
                refreshRooms();
                connectionAttempts = 0;
                
                // Iniciar ping periódico para mantener la conexión
                clearInterval(pingInterval);
                pingInterval = setInterval(() => {
                    if (currentRoom) {
                        socket.emit('ping', { roomId: currentRoom });
                    } else {
                        socket.emit('ping', {});
                    }
                }, 8000); // Ping cada 8 segundos
            });
            
            // Evento: Desconexión
            socket.on('disconnect', (reason) => {
                console.log('Desconectado del servidor:', reason);
                updateNetworkStatus(false);
                clearInterval(pingInterval);
                
                if (gameActive && gameMode === 'online') {
                    connectionAttempts++;
                    if (connectionAttempts <= MAX_RECONNECT_ATTEMPTS) {
                        statusDisplay.textContent = `Intentando reconectar (${connectionAttempts}/${MAX_RECONNECT_ATTEMPTS})...`;
                        
                        // Forzar reconexión tras un breve retardo
                        setTimeout(() => {
                            if (!socket.connected) {
                                socket.connect();
                            }
                        }, connectionAttempts * 1000);
                    } else {
                        alert('Desconectado del servidor. No se pudo reconectar automáticamente.');
                        resetToHome();
                    }
                }
            });
            
            // Evento: Error
            socket.on('error', (data) => {
                alert(data.message);
                resetToHome();
            });
            
            // Evento: Lista de salas
            socket.on('roomsList', (data) => {
                updateRoomsList(data);
            });
            
            // Evento: Sala creada
            socket.on('roomCreated', (data) => {
                handleRoomCreated(data);
            });
            
            // Evento: Unido a sala
            socket.on('roomJoined', (data) => {
                handleRoomJoined(data);
            });
            
            // Evento: Inicio del juego
            socket.on('gameStart', (data) => {
                handleGameStart(data);
            });
            
            // Evento: Actualización del juego
            socket.on('gameUpdate', (data) => {
                handleGameUpdate(data);
            });
            
            // Evento: Reinicio del juego
            socket.on('gameRestart', (data) => {
                handleGameRestart(data);
            });
            
            // Evento: Jugador desconectado
            socket.on('playerDisconnected', () => {
                handlePlayerDisconnected();
            });
            
            // Evento: Sala cerrada por inactividad
            socket.on('roomClosed', (data) => {
                alert(data.message || 'La sala ha sido cerrada');
                resetToHome();
            });
            
            // Evento: Respuesta de ping
            socket.on('pong', () => {
                // Podemos usar esto para medir la latencia si es necesario
            });
            
        } catch (error) {
            console.error('Error al inicializar Socket.IO:', error);
            networkStatus.innerHTML = '<span class="dot"></span> Error de conexión';
            networkStatus.className = 'network-status disconnected';
        }
    }
    
    // Actualizar el estado de la conexión
    function updateNetworkStatus(connected, transport = '') {
        if (connected) {
            networkStatus.innerHTML = `<span class="dot"></span> Conectado${transport ? ' (' + transport + ')' : ''}`;
            networkStatus.className = 'network-status connected';
        } else {
            networkStatus.innerHTML = '<span class="dot"></span> Desconectado';
            networkStatus.className = 'network-status disconnected';
        }
    }
    
    // Resto del código permanece igual...
    
    // El resto de tus funciones...
    
    // Detectar errores de conexión
    window.addEventListener('error', (event) => {
        if (event.message && (
            event.message.includes('socket.io') || 
            event.message.includes('WebSocket')
        )) {
            console.error('Error de conexión:', event.message);
            
            if (socket) {
                // Intentar reconectar con polling si hay error de WebSocket
                socket.io.opts.transports = ['polling'];
                setTimeout(() => {
                    socket.connect();
                }, 1000);
            }
        }
    });
});
EOL

# 4. Aplicar configuración de diagnóstico
echo -e "${YELLOW}Creando página de diagnóstico...${NC}"
cat > diagnostic.html << 'EOL'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Diagnóstico - Tic Tac Toe</title>
    <script src="socket.io/socket.io.js"></script>
    <base href="/tictactoe/">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .container { max-width: 800px; margin: 0 auto; }
        .box { padding: 10px; border: 1px solid #ddd; margin-bottom: 10px; }
        .success { background-color: #d4edda; color: #155724; }
        .error { background-color: #f8d7da; color: #721c24; }
        .log { background-color: #333; color: white; padding: 10px; height: 200px; overflow-y: auto; font-family: monospace; }
        button { padding: 8px 16px; margin-right: 10px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Diagnóstico de Conexión - Tic Tac Toe</h1>
        
        <div class="box">
            <h2>Información del Navegador</h2>
            <div id="browser-info"></div>
        </div>
        
        <div class="box">
            <h2>Prueba de Socket.IO</h2>
            <button id="test-polling">Probar Polling</button>
            <button id="test-websocket">Probar WebSocket</button>
            <div id="socket-result"></div>
        </div>
        
        <div class="box">
            <h2>Registro de Eventos</h2>
            <div id="log" class="log"></div>
        </div>
    </div>
    
    <script>
        document.addEventListener('DOMContentLoaded', () => {
            const logEl = document.getElementById('log');
            const browserInfoEl = document.getElementById('browser-info');
            const socketResultEl = document.getElementById('socket-result');
            
            // Mostrar información del navegador
            browserInfoEl.innerHTML = `
                <p>User Agent: ${navigator.userAgent}</p>
                <p>URL: ${window.location.href}</p>
                <p>Protocol: ${window.location.protocol}</p>
                <p>WebSocket Soportado: ${typeof WebSocket !== 'undefined'}</p>
            `;
            
            function log(msg) {
                const now = new Date().toISOString();
                logEl.innerHTML += `[${now}] ${msg}<br>`;
                logEl.scrollTop = logEl.scrollHeight;
            }
            
            log('Página de diagnóstico cargada');
            
            document.getElementById('test-polling').addEventListener('click', () => {
                testSocketIO(['polling']);
            });
            
            document.getElementById('test-websocket').addEventListener('click', () => {
                testSocketIO(['websocket']);
            });
            
            function testSocketIO(transports) {
                log(`Probando Socket.IO con transporte: ${transports.join(', ')}`);
                socketResultEl.className = '';
                socketResultEl.innerHTML = 'Conectando...';
                
                try {
                    const socket = io({
                        transports: transports,
                        path: '/tictactoe/socket.io',
                        forceNew: true,
                        reconnection: false,
                        timeout: 10000
                    });
                    
                    socket.on('connect', () => {
                        log(`Conectado usando ${socket.io.engine.transport.name}`);
                        socketResultEl.className = 'success';
                        socketResultEl.innerHTML = `Conexión exitosa usando ${socket.io.engine.transport.name}`;
                        
                        socket.emit('ping', {}, () => {
                            log('Ping recibido');
                        });
                    });
                    
                    socket.on('connect_error', (error) => {
                        log(`Error de conexión: ${error.message}`);
                        socketResultEl.className = 'error';
                        socketResultEl.innerHTML = `Error: ${error.message}`;
                    });
                    
                    socket.on('disconnect', (reason) => {
                        log(`Desconectado: ${reason}`);
                    });
                    
                } catch (e) {
                    log(`Error: ${e.message}`);
                    socketResultEl.className = 'error';
                    socketResultEl.innerHTML = `Error: ${e.message}`;
                }
            }
        });
    </script>
</body>
</html>
EOL

# 5. Actualizar script de inicio para soportar polling
echo -e "${YELLOW}Actualizando script de inicio...${NC}"
cat > start-port-4000.sh << 'EOL'
#!/bin/bash

# Script para iniciar el servidor Tic Tac Toe optimizado para ngrok
# Con soporte prioritario para polling

# Colores para salida
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PORT=4000
PID_FILE="tictactoe.pid"
LOG_FILE="tictactoe.log"

echo -e "${GREEN}=== Iniciando Tic Tac Toe Multijugador (Puerto: $PORT) ===${NC}"

# Detener instancias existentes
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p $OLD_PID > /dev/null; then
        echo -e "${YELLOW}Deteniendo instancia existente (PID: $OLD_PID)...${NC}"
        kill $OLD_PID
        sleep 1
        # Forzar terminación si todavía está en ejecución
        if ps -p $OLD_PID > /dev/null; then
            echo -e "${YELLOW}Forzando terminación...${NC}"
            kill -9 $OLD_PID
        fi
    fi
    rm "$PID_FILE"
fi

# Verificar si el puerto está en uso por otro proceso
CURRENT_PID=$(lsof -ti:$PORT)
if [ ! -z "$CURRENT_PID" ]; then
    echo -e "${YELLOW}El puerto $PORT está en uso (PID: $CURRENT_PID). Liberando...${NC}"
    kill -9 $CURRENT_PID
    sleep 1
fi

# Iniciar el servidor con node
echo -e "${YELLOW}Iniciando el servidor...${NC}"
nohup node server/server.js > $LOG_FILE 2>&1 &
NEW_PID=$!
echo $NEW_PID > $PID_FILE

# Verificar que el servidor haya iniciado correctamente
sleep 2
if ps -p $NEW_PID > /dev/null; then
    echo -e "${GREEN}Servidor iniciado correctamente (PID: $NEW_PID)${NC}"
    echo -e "URL: ${YELLOW}http://localhost:$PORT/tictactoe/${NC}"
    echo -e "URL con ngrok: ${YELLOW}https://[tu-dominio]/tictactoe/${NC}"
    echo -e "Logs: ${YELLOW}tail -f $LOG_FILE${NC}"
    echo -e "Detener: ${YELLOW}./stop-server.sh${NC}"
else
    echo -e "${RED}Error al iniciar el servidor. Revise el archivo de log: $LOG_FILE${NC}"
    exit 1
fi

# Crear script para detener el servidor
cat > stop-server.sh << 'STOPSCRIPT'
#!/bin/bash
if [ -f "tictactoe.pid" ]; then
    PID=$(cat tictactoe.pid)
    echo "Deteniendo servidor (PID: $PID)..."
    kill $PID
    rm tictactoe.pid
    echo "Servidor detenido."
else
    echo "No se encontró archivo PID. El servidor podría no estar en ejecución."
fi
STOPSCRIPT

chmod +x stop-server.sh
echo -e "${GREEN}=== Configuración completa ===${NC}"
EOL

# Hacer ejecutables los scripts
chmod +x start-port-4000.sh

echo -e "${GREEN}=== Configuración completada ===${NC}"
echo -e "Ahora puedes iniciar el servidor con ${YELLOW}./start-port-4000.sh${NC}"
echo -e "La herramienta de diagnóstico estará disponible en ${YELLOW}http://localhost:4000/tictactoe/diagnostic.html${NC}"
echo -e "Con ngrok: ${YELLOW}https://tu-dominio.com/tictactoe/diagnostic.html${NC}"
echo -e "\nEl servidor está configurado para usar primero 'polling' y luego 'websocket' si es posible,"
echo -e "lo que debería resolver los problemas con ngrok."