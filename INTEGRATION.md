# Integración de Tic Tac Toe en tu Sitio Web Existente

Este documento explica cómo integrar el juego Tic Tac Toe Multijugador en un sitio web existente, específicamente bajo la ruta `/tictactoe`.

## Método 1: Usando ngrok como Proxy Inverso

Si ya tienes un sitio web funcionando con ngrok, puedes configurar ngrok para redirigir las solicitudes a `/tictactoe` a nuestro servidor de juego.

### Requisitos
- ngrok instalado
- Sitio web principal ya configurado
- Puerto 4000 disponible para el servidor del juego

### Pasos de Integración

1. **Inicia el servidor del juego en el puerto 4000**:
   ```bash
   chmod +x start-ngrok.sh
   ./start-ngrok.sh
   ```
   Este script iniciará el juego en el puerto 4000.

2. **Configuración de ngrok con archivo de configuración**:

   Crea/edita tu archivo de configuración de ngrok (normalmente `~/.ngrok2/ngrok.yml`):
   ```yaml
   version: "2"
   authtoken: "tu-token-de-ngrok"
   tunnels:
     website:
       addr: 80  # Puerto de tu sitio web principal
       proto: http
       host_header: "rewrite"
     tictactoe:
       addr: 4000  # Puerto del servidor de juego
       proto: http
       host_header: "rewrite"
   ```

3. **Crear configuración de ngrok para combinar ambos servicios**:

   Crea un archivo `ngrok-combined.yml`:
   ```yaml
   version: "2"
   authtoken: "tu-token-de-ngrok"
   tunnels:
     combined:
       proto: http
       domain: tu-dominio-de-ngrok.app  # Si tienes un dominio personalizado
       inspect: false
       bind_tls: true
       http_proxy:
         - path: "/tictactoe/"
           url: "http://localhost:4000/tictactoe/"
         - path: "/tictactoe/socket.io/"
           url: "http://localhost:4000/tictactoe/socket.io/"
         - path: "/"
           url: "http://localhost:80/"  # Tu sitio web principal
   ```

4. **Iniciar ngrok con la configuración combinada**:
   ```bash
   ngrok start --config=ngrok-combined.yml combined
   ```

## Método 2: Usando un Servidor Web como Proxy Inverso

Si estás utilizando un servidor web como Nginx o Apache, puedes configurarlo para actuar como proxy inverso.

### Configuración para Nginx

Añade este bloque a tu configuración de Nginx:

```nginx
server {
    listen 80;
    server_name mipagina.com;  # Reemplaza con tu dominio

    # Tu configuración existente para el sitio principal
    location / {
        # Configuración de tu sitio web principal...
    }

    # Configuración para el juego Tic Tac Toe
    location /tictactoe/ {
        proxy_pass http://localhost:4000/tictactoe/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # Configuración especial para WebSockets
    location /tictactoe/socket.io/ {
        proxy_pass http://localhost:4000/tictactoe/socket.io/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

### Configuración para Apache

Asegúrate de tener habilitados los módulos necesarios:
```bash
sudo a2enmod proxy proxy_http proxy_wstunnel
sudo systemctl restart apache2
```

Añade esta configuración a tu archivo de VirtualHost:

```apache
<VirtualHost *:80>
    ServerName mipagina.com  # Reemplaza con tu dominio

    # Tu configuración existente para el sitio principal...

    # Configuración para el juego Tic Tac Toe
    ProxyPreserveHost On

    # Ruta para archivos estáticos y API
    ProxyPass /tictactoe http://localhost:4000/tictactoe
    ProxyPassReverse /tictactoe http://localhost:4000/tictactoe

    # Configuración especial para WebSockets
    RewriteEngine On
    RewriteCond %{REQUEST_URI} ^/tictactoe/socket.io/ [NC]
    RewriteCond %{QUERY_STRING} transport=websocket [NC]
    RewriteRule /(.*) ws://localhost:4000/$1 [P,L]
</VirtualHost>
```

## Verificación de la Integración

1. Inicia el servidor del juego:
   ```bash
   PORT=4000 node server/server.js
   ```

2. Verifica que puedes acceder al juego en:
   ```
   https://mipagina.com/tictactoe/
   ```

3. Comprueba que las conexiones WebSocket funcionan iniciando una partida multijugador.

## Solución de Problemas

### WebSockets no funcionan
- Verifica que las reglas de proxy para WebSockets están configuradas correctamente
- Asegúrate de que no hay firewalls bloqueando las conexiones WebSocket

### No se puede acceder al juego
- Comprueba que el servidor del juego está ejecutándose en el puerto 4000
- Verifica los logs tanto del servidor del juego como del servidor web
- Asegúrate de que todas las rutas en la configuración del proxy son correctas

### El juego carga pero no funciona correctamente
- Comprueba la consola del navegador para ver errores
- Verifica que la etiqueta `<base href="/tictactoe/">` está presente en el HTML

## Notas Adicionales

- El servidor del juego está configurado para funcionar en la ruta `/tictactoe`. No cambies esta configuración.
- Para entornos de producción, considera ejecutar el servidor del juego con PM2.
- Recuerda ajustar los puertos y dominios según tu configuración específica.