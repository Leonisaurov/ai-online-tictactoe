module.exports = {
  apps: [{
    name: 'tic-tac-toe',
    script: 'server/server.js',
    instances: 'max',
    exec_mode: 'cluster',
    autorestart: true,
    watch: false,
    max_memory_restart: '512M',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    env_production: {
      NODE_ENV: 'production',
      PORT: 80
    },
    log_date_format: 'YYYY-MM-DD HH:mm:ss',
    combine_logs: true
  }]
};