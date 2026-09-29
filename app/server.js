const express = require('express');
const path = require('path');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 4500;
const ENV = process.env.NODE_ENV || 'development';
const VERSION = process.env.APP_VERSION || '1.0.0';

app.use(express.json());
app.use(express.static(path.join(__dirname, 'src')));

app.get('/health', (req, res) => res.json({
  status: 'healthy',
  version: VERSION,
  environment: ENV,
  uptime: process.uptime(),
  hostname: os.hostname(),
  timestamp: new Date().toISOString()
}));

app.get('/api/info', (req, res) => res.json({
  app: 'devops_mini_project',
  version: VERSION,
  environment: ENV,
  node: process.version,
  memory: {
    used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024) + 'MB',
    total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024) + 'MB'
  },
  uptime: Math.round(process.uptime()) + 's'
}));

app.get('*', (req, res) =>
  res.sendFile(path.join(__dirname, 'src', 'index.html')));

// Only bind the port when run directly (keeps Jest/supertest from opening a socket)
if (require.main === module) {
  app.listen(PORT, () =>
    console.log(`devops_mini_project running on port ${PORT} [${ENV}]`));
}

module.exports = app;