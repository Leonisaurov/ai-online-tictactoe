# Implementación de Tic Tac Toe Online en Internet

Este documento detalla el proceso completo para implementar el juego Tic Tac Toe Multiplayer en un servidor en la nube, permitiendo que jugadores de todo el mundo puedan jugar online.

## Requisitos del Servidor

- Sistema operativo: Linux (Ubuntu/Debian recomendado)
- RAM: Mínimo 1GB (recomendado 2GB+)
- CPU: 1 núcleo (mínimo)
- Almacenamiento: 5GB mínimo
- Acceso root o sudo
- Puerto 80/443 abierto para tráfico HTTP/HTTPS
- Nombre de dominio (opcional, pero recomendado para SSL)

## Pasos de Implementación

### 1. Preparación Inicial

1. Accede a tu servidor mediante SSH:
   ```
   ssh usuario@tu_ip_servidor
   ```

2. Actualiza el sistema:
   ```
   sudo apt update && sudo apt upgrade -y
   ```

3. Instala Git si no está instalado:
   ```
   sudo apt install git -y
   ```

### 2. Clonación del Repositorio

1. Clona el repositorio del juego:
   ```
   git clone [URL_DEL_REPOSITORIO] TicTacToe
   cd TicTacToe
   ```

### 3. Despliegue Automatizado

El método más sencillo es usar nuestro script de despliegue automático:

1. Otorga permisos de ejecución:
   ```
   chmod +x deploy.sh
   ```

2. Ejecuta el script:
   ```
   sudo ./deploy.sh
   ```

El script realizará automáticamente las siguientes tareas:
- Instalación de Node.js (si no está instalado)
- Instalación de PM2 (gestor de procesos para Node.js)
- Instalación de dependencias del proyecto
- Configuración del firewall
- Configuración como servicio del sistema
- Inicio automático del servidor

### 4. Configuración SSL/TLS (HTTPS)

Para una implementación segura, se recomienda configurar SSL:

1. Asegúrate de tener un dominio apuntando a la IP de tu servidor

2. Otorga permisos de ejecución al script SSL:
   ```
   chmod +x setup-ssl.sh
   ```

3. Ejecuta el script:
   ```
   sudo ./setup-ssl.sh
   ```

4. Sigue las instrucciones para ingresar tu nombre de dominio

### 5. Verificación del Despliegue

1. Comprueba que el servidor está funcionando:
   ```
   pm2 status
   ```

2. Verifica los logs en caso de problemas:
   ```
   pm2 logs tic-tac-toe
   ```

3. Comprueba el acceso a la aplicación visitando:
   - http://tu_ip_servidor (sin SSL)
   - https://tu_dominio (con SSL configurado)

## Gestión del Servidor

### Comandos Útiles de PM2

- **Ver estado**: `pm2 status`
- **Ver logs**: `pm2 logs tic-tac-toe`
- **Reiniciar servidor**: `pm2 restart tic-tac-toe`
- **Detener servidor**: `pm2 stop tic-tac-toe`
- **Iniciar servidor**: `pm2 start tic-tac-toe`

### Endpoints de Monitoreo

El servidor proporciona endpoints para monitorear su estado:

- **/health**: Estado básico del servidor
  ```
  curl http://tu_ip_servidor/health
  ```

- **/stats**: Estadísticas detalladas (uso de memoria, CPU, sesiones activas)
  ```
  curl http://tu_ip_servidor/stats
  ```

## Solución de Problemas

### El servidor no inicia

1. Verifica los logs:
   ```
   pm2 logs tic-tac-toe
   ```

2. Comprueba si el puerto está en uso:
   ```
   sudo netstat -tulpn | grep 3000
   ```

### Problemas con la conexión

1. Verifica que el firewall permite conexiones:
   ```
   sudo ufw status
   ```

2. Asegúrate de que los puertos 80, 443 y 3000 están abiertos:
   ```
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw allow 3000/tcp
   ```

### Problemas con SSL

1. Verifica la configuración de Nginx:
   ```
   sudo nginx -t
   ```

2. Comprueba el estado del certificado:
   ```
   sudo certbot certificates
   ```

## Actualización del Juego

Para actualizar a una nueva versión:

1. Detén el servidor:
   ```
   pm2 stop tic-tac-toe
   ```

2. Actualiza el código:
   ```
   git pull
   ```

3. Reinstala dependencias:
   ```
   npm install --production
   ```

4. Reinicia el servidor:
   ```
   pm2 restart tic-tac-toe
   ```

## Información Adicional

- El juego está configurado para limpiar automáticamente las salas inactivas después de 30 minutos
- La configuración del servidor se encuentra en `ecosystem.config.js`
- Los logs se guardan en `~/.pm2/logs/`

---

Para cualquier otra consulta o problema, consulta la documentación completa en el archivo README.md o abre un issue en el repositorio del proyecto.