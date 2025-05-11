#!/bin/bash

# Script para iniciar el servidor de juego Tic Tac Toe en la subruta /tictactoe
# Configura el servidor para ejecutarse en el puerto especificado o 4000 por defecto

# Colores para salida
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Definir puerto (por defecto 4000 o el que se pase como argumento)
PORT=${1:-4000}

echo -e "${GREEN}=== Iniciando Tic Tac Toe en subruta /tictactoe (Puerto: $PORT) ===${NC}"

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

# Verificar si el puerto está en uso
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null ; then
    echo -e "${RED}El puerto $PORT ya está en uso. Por favor, especifica otro puerto.${NC}"
    exit 1
fi

echo -e "${YELLOW}Iniciando el servidor en puerto $PORT...${NC}"

# Iniciar el servidor
NODE_ENV=production PORT=$PORT node server/server.js