// server.js
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const fs = require('fs');
const path = require('path');

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: '*' } });

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Simple persistence file
const STORAGE = path.join(__dirname, 'public', 'content.html');
function readContent() {
  try { return fs.readFileSync(STORAGE, 'utf8'); } catch { return '<p>Welcome</p>'; }
}
function writeContent(html) { fs.writeFileSync(STORAGE, html, 'utf8'); }

// Socket.IO connections
io.on('connection', (socket) => {
  // Send current content to newly connected client
  socket.emit('content', readContent());

  // Optionally log
  console.log('Client connected:', socket.id);
});

app.post('/admin/save', (req, res) => {
  // Basic auth-like check: require a secret token in header (improve for prod)
  const token = req.get('x-admin-token');
  if (token !== process.env.ADMIN_TOKEN) return res.status(401).json({ error: 'Unauthorized' });

  const html = req.body.html || '';
  writeContent(html);

  // Broadcast to all clients
  io.emit('content', html);

  res.json({ ok: true });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log('Server running on', PORT));
