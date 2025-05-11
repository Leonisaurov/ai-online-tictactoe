#!/bin/bash

# Script para configurar SSL/TLS con Certbot para Tic Tac Toe Multiplayer
# Este script obtiene certificados SSL gratuitos de Let's Encrypt

# Colores para salida
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Configuración de SSL/TLS para Tic Tac Toe Multiplayer ===${NC}"

# Verificar que el script se ejecute como root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Por favor, ejecute este script como root${NC}"
  exit 1
fi

# Solicitar el dominio
echo -e "${YELLOW}Ingrese el dominio para el certificado SSL (ej: juego.tudominio.com):${NC}"
read domain_name

# Verificar que se ingresó un dominio
if [ -z "$domain_name" ]; then
  echo -e "${RED}Debe ingresar un dominio válido${NC}"
  exit 1
fi

# Verificar que Certbot esté instalado
echo -e "${YELLOW}Verificando Certbot...${NC}"
if ! command -v certbot &> /dev/null; then
  echo -e "${YELLOW}Certbot no encontrado. Instalando...${NC}"
  
  # Instalar certbot y plugin para Nginx
  apt-get update
  apt-get install -y certbot python3-certbot-nginx
else
  echo -e "${GREEN}Certbot ya está instalado${NC}"
fi

# Verificar si Nginx está instalado
echo -e "${YELLOW}Verificando Nginx...${NC}"
if ! command -v nginx &> /dev/null; then
  echo -e "${YELLOW}Nginx no encontrado. Instalando...${NC}"
  apt-get install -y nginx
else
  echo -e "${GREEN}Nginx ya está instalado${NC}"
fi

# Configurar Nginx como proxy inverso para la aplicación Node.js
echo -e "${YELLOW}Configurando Nginx como proxy inverso...${NC}"

# Crear configuración de Nginx
cat > /etc/nginx/sites-available/$domain_name <<EOL
server {
    listen 80;
    server_name $domain_name;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

# Activar la configuración
ln -sf /etc/nginx/sites-available/$domain_name /etc/nginx/sites-enabled/

# Verificar configuración de Nginx
nginx -t

# Reiniciar Nginx
systemctl restart nginx

# Obtener certificado SSL
echo -e "${YELLOW}Obteniendo certificado SSL para $domain_name...${NC}"
certbot --nginx -d $domain_name --non-interactive --agree-tos --email admin@$domain_name --redirect

# Configurar renovación automática de certificados
echo -e "${YELLOW}Configurando renovación automática de certificados...${NC}"
echo "0 3 * * * certbot renew --quiet" | crontab -

echo -e "\n${GREEN}=== Configuración SSL/TLS completada ===${NC}"
echo -e "Tu juego Tic Tac Toe ahora está disponible en: ${GREEN}https://$domain_name${NC}"
echo -e "El certificado se renovará automáticamente cada 90 días"
echo -e "Para probar la renovación: ${YELLOW}certbot renew --dry-run${NC}"