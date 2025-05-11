# Tic Tac Toe Multijugador Online

Este es un juego de Tic Tac Toe (Tres en Raya) que permite jugar tanto de forma local como en multijugador a través de Internet o red local (LAN).

## Características

- Juego local para 2 jugadores en el mismo dispositivo
- Modo multijugador online (Internet/LAN)
- Creación y unión a salas de juego
- Lista de salas disponibles en tiempo real
- Interfaz responsive y amigable
- Gestión automática de desconexiones y reconexiones
- Limpieza de salas inactivas para optimizar recursos

## Requisitos

- Node.js (v14 o superior)
- Navegador web moderno
- Para despliegue en producción: Servidor Linux con acceso root

## Instalación

### Desarrollo local

1. Clona o descarga este repositorio
2. Abre una terminal en la carpeta del proyecto
3. Instala las dependencias:

```
npm install
```

### Despliegue en producción (servidor en la nube)

1. Sube los archivos al servidor
2. Otorga permisos de ejecución al script de despliegue:

```
chmod +x deploy.sh
```

3. Ejecuta el script de despliegue:

```
sudo ./deploy.sh
```

El script automatizará todo el proceso de instalación y configuración.

## Uso

### Iniciar el servidor en modo desarrollo

Para iniciar el servidor de juego multijugador en modo desarrollo:

```
npm run dev
```

El servidor se iniciará en el puerto 3000 por defecto. Puedes abrir el juego en tu navegador usando la URL:

```
http://localhost:3000
```

### Iniciar el servidor en producción

Para entornos de producción, se recomienda usar PM2:

```
npm run deploy
```

o manualmente:

```
pm2 start ecosystem.config.js --env production
```

### Jugar online (Internet)

1. Accede a la URL del servidor donde está alojado el juego
2. Crea una sala y comparte la URL con amigos, o únete a una sala existente
3. ¡Disfruta del juego!

### Jugar en red local (LAN)

1. Inicia el servidor como se indicó anteriormente
2. Abre la IP de tu computadora en el navegador de otros dispositivos en la misma red
   - Ejemplo: `http://192.168.1.5:3000` (la IP puede variar según tu red)
3. Crear una sala o unirse a una existente

### Modos de juego

#### Juego Local

- Selecciona "Juego Local (2 Jugadores)" en la pantalla principal
- Los jugadores X y O alternan turnos en el mismo dispositivo

#### Juego Multijugador

- **Crear una sala**: Ingresa un nombre para la sala y haz clic en "Crear Sala"
- **Unirse a una sala**: Ingresa el nombre de la sala existente y haz clic en "Unirse a Sala", o selecciona una de las salas disponibles en la lista

## Cómo jugar

1. El primer jugador es X, el segundo es O
2. Los jugadores se turnan para colocar su símbolo en el tablero
3. El objetivo es conseguir tres símbolos en línea (horizontal, vertical o diagonal)
4. Si se llenan todas las casillas sin un ganador, el juego termina en empate

## Monitoreo y administración (producción)

### Comandos útiles para PM2

- Ver logs: `pm2 logs tic-tac-toe`
- Reiniciar servidor: `pm2 restart tic-tac-toe`
- Ver estado: `pm2 status`
- Parar servidor: `pm2 stop tic-tac-toe`

### Endpoints de monitoreo

- `/health` - Verificar estado del servidor
- `/stats` - Estadísticas detalladas (memoria, CPU, sesiones activas)

## Solución de problemas

- Si no puedes conectarte al servidor, verifica que el firewall permita conexiones a los puertos 80 y 3000
- Si el juego se desconecta, espera a que intente reconectar automáticamente
- Para salas inactivas, el sistema las limpiará automáticamente después de 30 minutos
- Para reiniciar un juego, usa el botón "Reiniciar Juego"

## Tecnologías utilizadas

- HTML, CSS y JavaScript para el frontend
- Node.js y Express para el servidor
- Socket.IO para la comunicación en tiempo real
- PM2 para gestión de procesos en producción
- Helmet, Compression y CORS para seguridad y optimización