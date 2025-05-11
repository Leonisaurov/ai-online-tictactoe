#!/bin/bash

# Script para iniciar el servidor de juego Tic Tac Toe y exponerlo a través de ngrok
# Este script configura ngrok para exponer el juego en la subruta /tictactoe

# Colores para salida
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Iniciando Tic Tac Toe con ngrok ===${NC}"

# Verificar que ngrok está instalado
if ! command -v ngrok &> /dev/null; then
    echo -e "${RED}ngrok no está instalado. Por favor, instálalo desde https://ngrok.com/download${NC}"
    exit 1
fi

# Puerto para el servidor de juego
PORT=4000

# Comprobar si Node.js está instalado
if ! command -v node &> /dev/null; then
    echo -e "${RED}Node.js no está instalado. Por favor, instálalo para continuar.${NC}"
    exit 1
fi

# Comprobar si las dependencias están instaladas
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}Instalando dependencias...${NC}"
    npm install
fi

# Crear archivo de configuración temporal para ngrok
cat > ngrok-tictactoe.yml <<EOL
version: "2"
authtoken: ""  # Puedes agregar tu token manualmente aquí
tunnels:
  tictactoe:
    addr: $PORT
    proto: http
EOL

echo -e "${YELLOW}Iniciando el servidor en puerto $PORT...${NC}"

# Iniciar el servidor en segundo plano
NODE_ENV=production PORT=$PORT node server/server.js > server.log 2>&1 &
SERVER_PID=$!

echo -e "${YELLOW}Esperando a que el servidor inicie...${NC}"
sleep 5

# Comprobar si el servidor está funcionando
if ! curl -s http://localhost:$PORT/tictactoe/health > /dev/null; then
    echo -e "${RED}El servidor no se inició correctamente. Verifica el archivo server.log${NC}"
    kill $SERVER_PID
    exit 1
fi

echo -e "${GREEN}Servidor iniciado correctamente (PID: $SERVER_PID)${NC}"

# Iniciar ngrok
echo -e "${YELLOW}Iniciando ngrok...${NC}"
ngrok start --config=ngrok-tictactoe.yml tictactoe

# Cuando ngrok se detiene, detener también el servidor
echo -e "${YELLOW}Deteniendo el servidor...${NC}"
kill $SERVER_PID

echo -e "${GREEN}Servidor detenido${NC}"
rm ngrok-tictactoe.yml

echo -e "${GREEN}=== Finalizado ===${NC}"