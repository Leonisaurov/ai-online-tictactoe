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
const MAX_RECONNECT_ATTEMPTS = 3;

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
    
    // Inicializar la conexión Socket.IO
    // Inicializar Socket.IO
    function initializeSocketConnection() {
        try {
            // Intentar conectar al servidor - adaptado para funcionar con ngrok
            const protocol = window.location.protocol.includes('https') ? 'wss' : 'ws';
            const host = window.location.hostname;
            // Usar el mismo puerto que la página actual - ngrok se encargará de redirigir
            const port = window.location.port || (protocol === 'wss' ? 443 : 80);
            
            // Determinar la ruta base para el socket - asegurar que funcione correctamente con la subruta
            const pathParts = window.location.pathname.split('/');
            const basePath = pathParts.includes('tictactoe') ? '/tictactoe' : '';
            
            // Opciones de conexión para mejor rendimiento y reconexión
            const socketOptions = {
                reconnection: true,
                reconnectionDelay: 1000,
                reconnectionDelayMax: 5000,
                reconnectionAttempts: 5,
                timeout: 20000,
                transports: ['polling', 'websocket'], // Priorizar polling sobre websocket
                path: `${basePath}/socket.io`,
                forceNew: true,
                upgrade: false, // Evitar actualización automática a WebSocket
            };
            
            // Para compatibilidad con ngrok - usar el mismo host y puerto con opciones de fallback
            socket = io({
                ...socketOptions,
                rejectUnauthorized: false, // Aceptar certificados auto-firmados
                secure: window.location.protocol === 'https:'
            });
            
            // Evento: Conexión establecida
            socket.on('connect', () => {
                console.log('Conectado al servidor');
                console.log('Usando transporte:', socket.io.engine.transport.name);
                updateNetworkStatus(true);
                refreshRooms();
                connectionAttempts = 0;
                
                // Mostrar el tipo de transporte utilizado
                networkStatus.innerHTML = `<span class="dot"></span> Conectado (${socket.io.engine.transport.name})`;
                
                // Iniciar ping periódico para mantener la conexión
                clearInterval(pingInterval);
                pingInterval = setInterval(() => {
                    if (currentRoom) {
                        socket.emit('ping', { roomId: currentRoom });
                    } else {
                        socket.emit('ping', {});
                    }
                }, 10000); // Ping cada 10 segundos para mayor fiabilidad
            });
            
            // Evento: Desconexión
            socket.on('disconnect', (reason) => {
                console.log('Desconectado del servidor:', reason);
                updateNetworkStatus(false);
                clearInterval(pingInterval);
                
                if (gameActive && gameMode === 'online') {
                    connectionAttempts++;
                    if (connectionAttempts <= MAX_RECONNECT_ATTEMPTS) {
                        statusDisplay.textContent = `Intentando reconectar (${connectionAttempts}/${MAX_RECONNECT_ATTEMPTS})... (${reason})`;
                        
                        // Forzar reconexión manualmente tras un breve retardo
                        setTimeout(() => {
                            if (!socket.connected) {
                                socket.connect();
                            }
                        }, 1000);
                    } else {
                        alert('Desconectado del servidor: ' + reason + '. El juego ha terminado.');
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
                // console.log('Ping-pong: latencia de ', Date.now() - data.timestamp, 'ms');
            });
            
            // Evento: Error de reconexión
            socket.on('reconnect_failed', () => {
                console.error('No se pudo reconectar al servidor');
                alert('No se pudo reconectar al servidor. Por favor, recarga la página.');
                resetToHome();
            });
            
        } catch (error) {
            console.error('Error al inicializar Socket.IO:', error);
            alert('No se pudo conectar al servidor. El multijugador no está disponible.');
            
            // Mostrar opciones de juego local para que los usuarios puedan jugar sin conexión
            networkStatus.innerHTML = '<span class="dot"></span> Sin conexión - Solo modo local disponible';
            networkStatus.className = 'network-status disconnected';
        }
    }
    
    // Actualizar el estado de la conexión
    function updateNetworkStatus(connected) {
        if (connected) {
            networkStatus.innerHTML = '<span class="dot"></span> Conectado';
            networkStatus.className = 'network-status connected';
        } else {
            networkStatus.innerHTML = '<span class="dot"></span> Desconectado';
            networkStatus.className = 'network-status disconnected';
        }
    }
    
    // Crear una sala de juego
    function createRoom() {
        const roomId = roomIdInput.value.trim();
        if (roomId === '') {
            alert('Por favor, ingresa un nombre para la sala');
            return;
        }
        
        gameMode = 'online';
        showConnectionScreen();
        roomIdDisplay.textContent = roomId;
        connectionStatus.textContent = 'Creando sala...';
        
        socket.emit('createRoom', roomId);
    }
    
    // Unirse a una sala de juego
    function joinRoom() {
        const roomId = roomIdInput.value.trim();
        if (roomId === '') {
            alert('Por favor, ingresa el nombre de la sala');
            return;
        }
        
        gameMode = 'online';
        showConnectionScreen();
        roomIdDisplay.textContent = roomId;
        connectionStatus.textContent = 'Uniéndose a la sala...';
        
        socket.emit('joinRoom', roomId);
    }
    
    // Refrescar la lista de salas disponibles
    function refreshRooms() {
        roomsList.innerHTML = '<p>Cargando salas...</p>';
        socket.emit('getRooms');
    }
    
    // Actualizar la lista de salas disponibles
    function updateRoomsList(rooms) {
        if (Object.keys(rooms).length === 0) {
            roomsList.innerHTML = '<p>No hay salas disponibles</p>';
            return;
        }
        
        // Ordenar salas por tiempo de creación (las más recientes primero)
        const sortedRooms = Object.keys(rooms).sort((a, b) => {
            return rooms[b].createdAt - rooms[a].createdAt;
        });
        
        let html = '';
        for (const roomId of sortedRooms) {
            const timeAgo = getTimeAgo(rooms[roomId].createdAt);
            html += `<div class="room-item" data-room-id="${roomId}">
                        <div class="room-name">${roomId}</div>
                        <div class="room-info">${rooms[roomId].players}/2 jugadores • Creada ${timeAgo}</div>
                     </div>`;
        }
        
        roomsList.innerHTML = html;
        
        // Agregar event listeners a las salas
        document.querySelectorAll('.room-item').forEach(room => {
            room.addEventListener('click', (e) => {
                const roomId = e.currentTarget.getAttribute('data-room-id');
                roomIdInput.value = roomId;
            });
        });
    }
    
    // Función para obtener tiempo relativo
    function getTimeAgo(timestamp) {
        const seconds = Math.floor((Date.now() - timestamp) / 1000);
        
        if (seconds < 60) return 'hace unos segundos';
        
        const minutes = Math.floor(seconds / 60);
        if (minutes < 60) return `hace ${minutes} ${minutes === 1 ? 'minuto' : 'minutos'}`;
        
        const hours = Math.floor(minutes / 60);
        if (hours < 24) return `hace ${hours} ${hours === 1 ? 'hora' : 'horas'}`;
        
        const days = Math.floor(hours / 24);
        return `hace ${days} ${days === 1 ? 'día' : 'días'}`;
    }
    
    // Iniciar juego local
    function startLocalGame() {
        gameMode = 'local';
        currentPlayer = 'X';
        playerSymbol = 'X'; // En modo local, siempre comenzamos como X
        gameState = ['', '', '', '', '', '', '', '', ''];
        gameActive = true;
        
        // Resetear el tablero
        cells.forEach(cell => {
            cell.textContent = '';
            cell.classList.remove('x');
            cell.classList.remove('o');
        });
        
        showGameScreen();
        currentRoomDisplay.textContent = 'Juego Local';
        currentPlayerSymbolDisplay.textContent = playerSymbol;
        updateStatus();
    }
    
    // Cancelar la conexión
    function cancelConnection() {
        resetToHome();
    }
    
    // Manejar evento: Sala creada
    function handleRoomCreated(data) {
        currentRoom = data.roomId;
        playerSymbol = data.player;
        playerSymbolDisplay.textContent = playerSymbol;
        connectionStatus.textContent = 'Esperando a otro jugador...';
    }
    
    // Manejar evento: Unido a sala
    function handleRoomJoined(data) {
        currentRoom = data.roomId;
        playerSymbol = data.player;
        playerSymbolDisplay.textContent = playerSymbol;
        connectionStatus.textContent = 'Conectado! Iniciando juego...';
    }
    
    // Manejar evento: Inicio del juego
    function handleGameStart(data) {
        gameState = data.gameState;
        currentPlayer = data.currentPlayer;
        gameActive = true;
        
        showGameScreen();
        currentRoomDisplay.textContent = currentRoom;
        currentPlayerSymbolDisplay.textContent = playerSymbol;
        updateStatus();
    }
    
    // Manejar evento: Actualización del juego
    function handleGameUpdate(data) {
        gameState = data.gameState;
        currentPlayer = data.currentPlayer;
        
        // Actualizar la celda que se jugó
        const { cellIndex, player } = data.lastMove;
        const cell = document.querySelector(`.cell[data-cell-index="${cellIndex}"]`);
        cell.textContent = player;
        cell.classList.add(player.toLowerCase());
        
        checkGameResult();
        updateStatus();
    }
    
    // Manejar evento: Reinicio del juego
    function handleGameRestart(data) {
        gameState = data.gameState;
        currentPlayer = data.currentPlayer;
        gameActive = true;
        
        cells.forEach(cell => {
            cell.textContent = '';
            cell.classList.remove('x');
            cell.classList.remove('o');
        });
        
        updateStatus();
    }
    
    // Manejar evento: Jugador desconectado
    function handlePlayerDisconnected() {
        alert('El otro jugador se ha desconectado');
        resetToHome();
    }
    
    // Manejar clic en una celda
    function handleCellClick(event) {
        const clickedCell = event.target;
        const cellIndex = parseInt(clickedCell.getAttribute('data-cell-index'));
        
        // Verificar si la celda ya está ocupada o si el juego ha terminado
        if (gameState[cellIndex] !== '' || !gameActive) {
            return;
        }
        
        // En modo online, solo permitir jugadas cuando sea el turno del jugador
        if (gameMode === 'online' && currentPlayer !== playerSymbol) {
            return;
        }
        
        // En modo local, actualizar directamente
        if (gameMode === 'local') {
            gameState[cellIndex] = currentPlayer;
            clickedCell.textContent = currentPlayer;
            clickedCell.classList.add(currentPlayer.toLowerCase());
            
            checkGameResult();
            if (gameActive) {
                currentPlayer = currentPlayer === 'X' ? 'O' : 'X';
            }
            updateStatus();
        } 
        // En modo online, enviar la jugada al servidor
        else {
            socket.emit('makeMove', {
                roomId: currentRoom,
                cellIndex: cellIndex,
                player: playerSymbol
            });
        }
    }
    
    // Manejar reinicio del juego
    function handleRestartGame() {
        if (gameMode === 'local') {
            startLocalGame();
        } else {
            socket.emit('restartGame', currentRoom);
        }
    }
    
    // Salir del juego
    function exitGame() {
        resetToHome();
    }
    
    // Verificar el resultado del juego
    function checkGameResult() {
        const winningConditions = [
            [0, 1, 2], [3, 4, 5], [6, 7, 8], // filas
            [0, 3, 6], [1, 4, 7], [2, 5, 8], // columnas
            [0, 4, 8], [2, 4, 6]             // diagonales
        ];
        
        let roundWon = false;
        
        for (let i = 0; i < winningConditions.length; i++) {
            const [a, b, c] = winningConditions[i];
            if (gameState[a] && gameState[a] === gameState[b] && gameState[a] === gameState[c]) {
                roundWon = true;
                break;
            }
        }
        
        if (roundWon) {
            gameActive = false;
            return;
        }
        
        // Verificar empate
        if (!gameState.includes('')) {
            gameActive = false;
        }
    }
    
    // Actualizar el mensaje de estado
    function updateStatus() {
        // Verificar si hay un ganador
        const winningConditions = [
            [0, 1, 2], [3, 4, 5], [6, 7, 8], // filas
            [0, 3, 6], [1, 4, 7], [2, 5, 8], // columnas
            [0, 4, 8], [2, 4, 6]             // diagonales
        ];
        
        let winner = null;
        
        for (let i = 0; i < winningConditions.length; i++) {
            const [a, b, c] = winningConditions[i];
            if (gameState[a] && gameState[a] === gameState[b] && gameState[a] === gameState[c]) {
                winner = gameState[a];
                break;
            }
        }
        
        if (winner) {
            statusDisplay.textContent = `¡Jugador ${winner} ha ganado!`;
            return;
        }
        
        // Verificar empate
        if (!gameState.includes('')) {
            statusDisplay.textContent = '¡Juego empatado!';
            return;
        }
        
        // Si no hay ganador ni empate, mostrar de quién es el turno
        statusDisplay.textContent = `¡Es turno de ${currentPlayer}!`;
        
        // En modo online, indicar si es tu turno o no
        if (gameMode === 'online') {
            if (currentPlayer === playerSymbol) {
                statusDisplay.textContent += ' (Es tu turno)';
            } else {
                statusDisplay.textContent += ' (Esperando al otro jugador)';
            }
        }
    }
    
    // Mostrar pantalla de conexión
    function showConnectionScreen() {
        startScreen.classList.add('hidden');
        connectionScreen.classList.remove('hidden');
        gameScreen.classList.add('hidden');
        
        // Establecer conexión continua para evitar desconexiones con ngrok
        if (pingInterval) clearInterval(pingInterval);
        pingInterval = setInterval(() => {
            if (socket && socket.connected) {
                socket.emit('ping', { roomId: currentRoom || '' });
            }
        }, 15000); // Cada 15 segundos
    }
    
    // Mostrar pantalla de juego
    function showGameScreen() {
        startScreen.classList.add('hidden');
        connectionScreen.classList.add('hidden');
        gameScreen.classList.remove('hidden');
    }
    
    // Resetear a la pantalla de inicio
    function resetToHome() {
        startScreen.classList.remove('hidden');
        connectionScreen.classList.add('hidden');
        gameScreen.classList.add('hidden');
        
        // Limpiar estado
        currentRoom = '';
        playerSymbol = '';
        gameActive = false;
        
        // Actualizar lista de salas
        refreshRooms();
        
        // Detener pings si se estaba en una sala
        if (currentRoom) {
            clearInterval(pingInterval);
            pingInterval = setInterval(() => {
                socket.emit('ping', {});
            }, 30000);
        }
    }
    
    // Función para cerrar recursos cuando se cierra la ventana
    window.addEventListener('beforeunload', () => {
        if (socket && socket.connected) {
            socket.disconnect();
        }
        clearInterval(pingInterval);
    });
    
    // Manejar errores de conexión Socket.IO
    window.addEventListener('error', (event) => {
        if (event.message && (
            event.message.includes('socket.io') || 
            event.message.includes('WebSocket') || 
            event.message.includes('network'))
        ) {
            console.error('Error de conexión:', event.message);
            updateNetworkStatus(false);
            
            if (socket) {
                // Intentar reconectar con polling si hay error de WebSocket
                console.log('Intentando reconectar con polling...');
                socket.io.opts.transports = ['polling'];
                socket.connect();
            }
        }
    });
    
    // Detectar errores de conexión
    window.addEventListener('unhandledrejection', (event) => {
        if (event.reason && typeof event.reason.message === 'string' && 
            (event.reason.message.includes('socket') || event.reason.message.includes('network'))) {
            console.error('Error no manejado:', event.reason.message);
            updateNetworkStatus(false);
        }
    });
});