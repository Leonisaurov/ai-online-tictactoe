#!/bin/bash

# Script optimizado para iniciar el servidor Tic Tac Toe en el puerto 4000
# Para funcionar con redirección ngrok en /tictactoe/

# Colores para salida
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PORT=4000
BASE_PATH="/tictactoe"

echo -e "${GREEN}=== Iniciando Tic Tac Toe en puerto $PORT (Ruta: $BASE_PATH) ===${NC}"

# Comprobar si Node.js está instalado
if ! command -v node &> /dev/null; then
    echo -e "${RED}Node.js no está instalado. Por favor, instálalo para continuar.${NC}"
    exit 1
fi

# Comprobar si las dependencias están instaladas
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}Instalando dependencias...${NC}"
    npm install --production
fi

# Verificar si el puerto está en uso
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null ; then
    echo -e "${RED}El puerto $PORT ya está en uso. Deteniendo proceso...${NC}"
    kill $(lsof -t -i:$PORT) || true
    sleep 2
fi

# Asegurarse de que todos los procesos existentes en el puerto estén detenidos
echo -e "${YELLOW}Verificando si hay procesos usando el puerto $PORT...${NC}"
CURRENT_PID=$(lsof -ti:$PORT -sTCP:LISTEN)
if [ ! -z "$CURRENT_PID" ]; then
    echo -e "${YELLOW}Deteniendo proceso existente (PID: $CURRENT_PID)...${NC}"
    kill -9 $CURRENT_PID 2>/dev/null || true
    sleep 2
fi

# Iniciar el servidor en segundo plano usando nohup o pm2 si está disponible
if command -v pm2 &> /dev/null; then
    echo -e "${YELLOW}Iniciando el servidor con PM2...${NC}"
    pm2 delete tictactoe 2>/dev/null || true
    PORT=$PORT pm2 start server/server.js --name tictactoe
    echo -e "${GREEN}Servidor iniciado con PM2 (nombre: tictactoe)${NC}"
    echo -e "Logs: ${YELLOW}pm2 logs tictactoe${NC}"
    echo -e "Detener: ${YELLOW}pm2 stop tictactoe${NC}"
else
    echo -e "${YELLOW}Iniciando el servidor con nohup...${NC}"
    # Matar cualquier proceso existente registrado en PID_FILE
    PID_FILE="tictactoe.pid"
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        kill -9 $OLD_PID 2>/dev/null || true
        rm "$PID_FILE"
    fi
    
    # Iniciar el nuevo proceso
    nohup PORT=$PORT NODE_ENV=production node server/server.js > tictactoe.log 2>&1 &
    SERVER_PID=$!
    echo $SERVER_PID > "$PID_FILE"
    echo -e "${GREEN}Servidor iniciado en segundo plano (PID: $SERVER_PID)${NC}"
    echo -e "Logs: ${YELLOW}tail -f tictactoe.log${NC}"
    echo -e "Detener: ${YELLOW}kill \$(cat $PID_FILE)${NC}"
fi

echo -e "${GREEN}=== Servidor Tic Tac Toe iniciado ===${NC}"
echo -e "URL local: ${YELLOW}http://localhost:$PORT$BASE_PATH/${NC}"
echo -e "Con ngrok: ${YELLOW}https://tu-dominio.com$BASE_PATH/${NC}"
echo -e "Estado: ${YELLOW}curl http://localhost:$PORT$BASE_PATH/health${NC}"