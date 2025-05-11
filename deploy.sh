#!/bin/bash

# Script de instalación y despliegue para Tic Tac Toe Multiplayer Online
# Este script configura e inicia el servidor de juego en la máquina en la nube

# Colores para salida
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Instalación de Tic Tac Toe Multiplayer ===${NC}"
echo "Este script configurará el entorno de producción"

# Verificar que el script se ejecute como root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Por favor, ejecute este script como root${NC}"
  exit 1
fi

# Verificar Node.js
echo -e "${YELLOW}Verificando Node.js...${NC}"
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}Node.js no encontrado. Instalando...${NC}"
    
    # Añadir repositorio de Node.js
    curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
    
    # Instalar Node.js
    apt-get install -y nodejs
    
    # Verificar instalación
    node -v
    npm -v
else
    echo -e "${GREEN}Node.js ya está instalado:${NC} $(node -v)"
fi

# Instalar PM2 globalmente
echo -e "${YELLOW}Instalando PM2...${NC}"
npm install -g pm2

# Instalar dependencias del proyecto
echo -e "${YELLOW}Instalando dependencias del proyecto...${NC}"
cd "$(dirname "$0")"
npm install --production

# Configurar firewall para permitir puerto 80 y 443
echo -e "${YELLOW}Configurando firewall...${NC}"
if command -v ufw &> /dev/null; then
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 3000/tcp
    echo -e "${GREEN}Firewall configurado${NC}"
else
    echo -e "${YELLOW}ufw no encontrado. Instalándolo...${NC}"
    apt-get install -y ufw
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 3000/tcp
    ufw enable
fi

# Crear archivo de servicio systemd
echo -e "${YELLOW}Creando servicio systemd...${NC}"
cat > /etc/systemd/system/tictactoe.service <<EOL
[Unit]
Description=Tic Tac Toe Multiplayer Game Server
After=network.target

[Service]
Type=forking
User=root
WorkingDirectory=$(pwd)
ExecStart=/usr/local/bin/pm2 start ecosystem.config.js --env production
ExecReload=/usr/local/bin/pm2 reload tic-tac-toe
ExecStop=/usr/local/bin/pm2 stop tic-tac-toe
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

# Recargar configuración de systemd
systemctl daemon-reload

# Iniciar y habilitar el servicio para que se inicie con el sistema
echo -e "${YELLOW}Iniciando servicio...${NC}"
systemctl enable tictactoe.service
systemctl start tictactoe.service

# Verificar estado del servicio
echo -e "${YELLOW}Verificando estado del servicio...${NC}"
systemctl status tictactoe.service --no-pager

echo -e "\n${GREEN}=== Instalación completada ===${NC}"
echo -e "El servidor de Tic Tac Toe está ejecutándose en el puerto 80"
echo -e "También puede acceder a través del puerto 3000"
echo -e "Para ver los logs: ${YELLOW}pm2 logs tic-tac-toe${NC}"
echo -e "Para reiniciar el servicio: ${YELLOW}systemctl restart tictactoe.service${NC}"
echo -e "URL del servidor: ${GREEN}http://$(hostname -I | awk '{print $1}')${NC}"