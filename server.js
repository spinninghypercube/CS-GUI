'use strict';

const express = require('express');
const fs = require('fs');
const path = require('path');
const http = require('http');
const crypto = require('crypto');

function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) return;
  const lines = fs.readFileSync(filePath, 'utf8').split(/\r?\n/);
  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;
    const eq = line.indexOf('=');
    if (eq <= 0) continue;
    const key = line.slice(0, eq).trim();
    if (!key || process.env[key] !== undefined) continue;
    let value = line.slice(eq + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    process.env[key] = value;
  }
}

const EXTERNAL_ENV_LOCAL = process.env.CROSS_SEED_UI_ENV_FILE || '/root/cross-seed-ui-secrets/.env.local';
loadEnvFile(EXTERNAL_ENV_LOCAL);
loadEnvFile(path.join(__dirname, '.env.local'));
loadEnvFile(path.join(__dirname, '.env'));

const app = express();
const PORT = Number(process.env.PORT) || 3000;
const CROSS_SEED_HOST = process.env.CROSS_SEED_HOST || '127.0.0.1';
const CROSS_SEED_PORT = Number(process.env.CROSS_SEED_PORT) || 2468;
const API_KEY = process.env.CROSS_SEED_API_KEY || '';
const UI_USERNAME = process.env.CROSS_SEED_UI_USERNAME || 'admin';
const UI_PASSWORD = process.env.CROSS_SEED_UI_PASSWORD || API_KEY || 'admin';
const SESSION_SECRET = process.env.CROSS_SEED_UI_SESSION_SECRET || API_KEY || 'change-me-session-secret';
const SESSION_COOKIE_NAME = 'cross_seed_ui_session';
const SESSION_TTL_SECONDS = 60 * 60 * 24 * 30;
const CONFIG_PATH = process.env.CROSS_SEED_CONFIG_PATH || '/root/.cross-seed/config.js';
const CONFIG_TEMPLATE_CANDIDATES = [
  '/usr/lib/node_modules/cross-seed/dist/config.template.cjs',
  '/usr/local/lib/node_modules/cross-seed/dist/config.template.cjs',
];
const CROSS_SEED_PACKAGE_CANDIDATES = [
  '/usr/lib/node_modules/cross-seed/package.json',
  '/usr/local/lib/node_modules/cross-seed/package.json',
];
const LOGS_DIR = process.env.CROSS_SEED_LOGS_DIR || '/root/.cross-seed/logs';
const VALID_JOBS = ['cleanup', 'inject', 'rss', 'search', 'updateIndexerCaps'];

if (!process.env.CROSS_SEED_API_KEY) {
  console.warn('[cross-seed-ui] CROSS_SEED_API_KEY is not set; API requests to cross-seed may fail.');
}

function safeEqual(a, b) {
  const aa = Buffer.from(String(a));
  const bb = Buffer.from(String(b));
  if (aa.length !== bb.length) return false;
  return crypto.timingSafeEqual(aa, bb);
}

function signPayload(payload) {
  return crypto.createHmac('sha256', SESSION_SECRET).update(payload).digest('hex');
}

function createSessionToken(username) {
  const expiresAt = Date.now() + SESSION_TTL_SECONDS * 1000;
  const nonce = crypto.randomBytes(16).toString('hex');
  const payload = `${username}|${expiresAt}|${nonce}`;
  const sig = signPayload(payload);
  return Buffer.from(`${payload}|${sig}`, 'utf8').toString('base64url');
}

function verifySessionToken(token) {
  if (!token) return false;
  let decoded;
  try {
    decoded = Buffer.from(token, 'base64url').toString('utf8');
  } catch (_) {
    return false;
  }

  const parts = decoded.split('|');
  if (parts.length !== 4) return false;

  const [username, expiresAtStr, nonce, sig] = parts;
  if (!safeEqual(username, UI_USERNAME)) return false;

  const expiresAt = Number(expiresAtStr);
  if (!Number.isFinite(expiresAt) || Date.now() > expiresAt) return false;

  const payload = `${username}|${expiresAtStr}|${nonce}`;
  const expectedSig = signPayload(payload);
  return safeEqual(sig, expectedSig);
}

function parseCookies(req) {
  const header = req.headers.cookie || '';
  const cookies = {};
  for (const part of header.split(';')) {
    const trimmed = part.trim();
    if (!trimmed) continue;
    const eq = trimmed.indexOf('=');
    if (eq < 0) continue;
    const key = trimmed.slice(0, eq);
    const val = trimmed.slice(eq + 1);
    cookies[key] = decodeURIComponent(val);
  }
  return cookies;
}

function readConfigTemplateContent() {
  for (const templatePath of CONFIG_TEMPLATE_CANDIDATES) {
    try {
      if (fs.existsSync(templatePath)) {
        return fs.readFileSync(templatePath, 'utf8');
      }
    } catch (_) {}
  }
  return '';
}

function readCrossSeedVersion() {
  for (const packagePath of CROSS_SEED_PACKAGE_CANDIDATES) {
    try {
      if (!fs.existsSync(packagePath)) continue;
      const pkg = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
      if (pkg && typeof pkg.version === 'string' && pkg.version.trim()) {
        return pkg.version.trim();
      }
    } catch (_) {}
  }
  return null;
}

function setSessionCookie(res, token) {
  const cookie = `${SESSION_COOKIE_NAME}=${encodeURIComponent(token)}; Path=/; HttpOnly; SameSite=Lax; Max-Age=${SESSION_TTL_SECONDS}`;
  res.setHeader('Set-Cookie', cookie);
}

function clearSessionCookie(res) {
  res.setHeader('Set-Cookie', `${SESSION_COOKIE_NAME}=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0`);
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function renderLoginPage(errorMessage = '', username = '') {
  const error = errorMessage
    ? `<div class="error" role="alert">${escapeHtml(errorMessage)}</div>`
    : '';

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>cross-seed login</title>
  <style>
    :root {
      --bg: #0d1117;
      --surface: #161b22;
      --surface2: #21262d;
      --border: #30363d;
      --text: #e6edf3;
      --muted: #8b949e;
      --accent: #58a6ff;
      --success: #3fb950;
      --error: #f85149;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      background: var(--bg);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      display: flex;
      flex-direction: column;
    }
    header {
      background: var(--surface);
      border-bottom: 1px solid var(--border);
      padding: 0 20px;
      display: flex;
      align-items: center;
      gap: 10px;
      height: 52px;
      flex-shrink: 0;
    }
    .logo {
      font-weight: 700;
      font-size: 16px;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .logo-icon {
      color: var(--success);
      font-size: 18px;
    }
    .version-tag {
      margin-left: auto;
      font-size: 11px;
      color: var(--muted);
      background: var(--surface2);
      border: 1px solid var(--border);
      padding: 2px 8px;
      border-radius: 12px;
    }
    main {
      flex: 1;
      display: grid;
      place-items: center;
      padding: 20px;
    }
    .card {
      width: min(430px, 100%);
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 24px;
    }
    h1 {
      margin: 0 0 8px;
      font-size: 22px;
    }
    p {
      margin: 0 0 18px;
      color: var(--muted);
      font-size: 13px;
    }
    label {
      display: block;
      margin: 14px 0 6px;
      font-size: 13px;
      color: var(--muted);
    }
    input {
      width: 100%;
      border: 1px solid var(--border);
      background: var(--bg);
      color: var(--text);
      border-radius: 8px;
      padding: 10px 12px;
      font-size: 14px;
      outline: none;
    }
    input:focus {
      border-color: var(--accent);
      box-shadow: 0 0 0 2px rgba(88,166,255,.2);
    }
    button {
      width: 100%;
      margin-top: 16px;
      border: 0;
      border-radius: 8px;
      padding: 10px 12px;
      font-size: 14px;
      font-weight: 600;
      background: var(--accent);
      color: #fff;
      cursor: pointer;
    }
    .error {
      margin: 10px 0 0;
      color: var(--error);
      font-size: 13px;
    }
  </style>
</head>
<body>
  <header>
    <div class="logo"><span class="logo-icon">⟳</span>CS-GUI</div>
    <span class="version-tag">login</span>
  </header>
  <main>
    <form id="login-form" class="card" action="/login" method="post" autocomplete="on">
      <h1>Sign in</h1>
      <p>Use your cross-seed UI credentials.</p>
      ${error}

      <label for="username">Username</label>
      <input
        id="username"
        name="username"
        type="text"
        inputmode="text"
        autocapitalize="none"
        spellcheck="false"
        autocomplete="username"
        value="${escapeHtml(username)}"
        required
      />

      <label for="password">Password</label>
      <input
        id="password"
        name="password"
        type="password"
        autocomplete="current-password"
        required
      />

      <button type="submit" name="action" value="login">Sign in</button>
    </form>
  </main>
</body>
</html>`;
}

function requireLogin(req, res, next) {
  if (req.path === '/login') return next();

  const cookies = parseCookies(req);
  const token = cookies[SESSION_COOKIE_NAME];
  if (verifySessionToken(token)) return next();

  if (req.path.startsWith('/api/')) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  return res.redirect('/login');
}

app.use(express.urlencoded({ extended: false }));
app.use(express.json({ limit: '2mb' }));

app.get('/login', (req, res) => {
  const token = parseCookies(req)[SESSION_COOKIE_NAME];
  if (verifySessionToken(token)) return res.redirect('/');
  res.setHeader('Cache-Control', 'no-store');
  return res.status(200).send(renderLoginPage());
});

app.post('/login', (req, res) => {
  const username = req.body?.username ?? req.body?.email ?? req.body?.login ?? '';
  const password = req.body?.password ?? '';

  if (!safeEqual(username, UI_USERNAME) || !safeEqual(password, UI_PASSWORD)) {
    res.setHeader('Cache-Control', 'no-store');
    return res.status(200).send(renderLoginPage('Invalid username or password.', username));
  }

  const token = createSessionToken(UI_USERNAME);
  setSessionCookie(res, token);
  return res.redirect(303, '/');
});

app.post('/logout', (req, res) => {
  clearSessionCookie(res);
  return res.redirect(303, '/login');
});

app.use(requireLogin);
app.use(express.static(path.join(__dirname, 'public')));

function csRequest(method, urlPath, onResponse) {
  const opts = {
    hostname: CROSS_SEED_HOST,
    port: CROSS_SEED_PORT,
    path: urlPath,
    method,
    headers: { 'X-Api-Key': API_KEY, 'Content-Type': 'application/json' },
    timeout: 5000,
  };

  let settled = false;
  const respondOnce = (response, err) => {
    if (settled) return;
    settled = true;
    onResponse(response, err);
  };

  const req = http.request(opts, (response) => respondOnce(response, null));
  req.on('error', (err) => respondOnce(null, err));
  req.on('timeout', () => {
    req.destroy(new Error('timeout'));
  });
  req.end();
}

// Daemon health check — uses cross-seed's own /api/ping endpoint
app.get('/api/ping', (req, res) => {
  csRequest('GET', '/api/ping', (response, err) => {
    if (err) return res.json({ status: 'down', error: err.message });
    response.resume();
    res.json({ status: 'up', code: response.statusCode });
  });
});

app.get('/api/version', (_req, res) => {
  res.json({ crossSeedVersion: readCrossSeedVersion() });
});

// Trigger a job — cross-seed v6 uses POST /api/job with body { name }
app.post('/api/job/:name', (req, res) => {
  const { name } = req.params;
  if (!VALID_JOBS.includes(name)) return res.status(400).json({ error: 'Invalid job name' });

  const payload = JSON.stringify({ name });
  const opts = {
    hostname: CROSS_SEED_HOST,
    port: CROSS_SEED_PORT,
    path: '/api/job',
    method: 'POST',
    headers: {
      'X-Api-Key': API_KEY,
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(payload),
    },
    timeout: 8000,
  };
  let responded = false;
  const sendJobResponse = (status, body) => {
    if (responded || res.headersSent) return;
    responded = true;
    res.status(status).json(body);
  };

  const req2 = http.request(opts, (response) => {
    let body = '';
    response.on('data', chunk => body += chunk);
    response.on('end', () => {
      try { body = JSON.parse(body); } catch (_) {}
      sendJobResponse(response.statusCode || 500, { triggered: true, response: body });
    });
  });
  req2.on('error', (err) => sendJobResponse(err.message === 'timeout' ? 504 : 500, { error: err.message }));
  req2.on('timeout', () => {
    req2.destroy(new Error('timeout'));
  });
  req2.write(payload);
  req2.end();
});

const SINCE_SECONDS = { '1h': 3600, '5h': 18000, '1d': 86400, '1w': 604800, '1m': 2592000 };
const SUCCESS_RE = /\binfo:.*\bMATCH(_PARTIAL)?\b.*- injected/;

function getLogFiles(type) {
  if (!fs.existsSync(LOGS_DIR)) return [];
  return fs.readdirSync(LOGS_DIR)
    .filter(f => f.startsWith(type + '.') && f.endsWith('.log') && /\d{4}-\d{2}-\d{2}/.test(f))
    .sort();
}

function parseLogTs(str) {
  // "2026-02-19 09:28:58" or "2026-02-19 09:28:58.003" — add T to make valid ISO
  return new Date(str.replace(' ', 'T')).getTime();
}

// For lines mode: gather from newest log files so "last N" means last matching entries overall.
function getLinesInitial(type, linesParam, filter) {
  const files = getLogFiles(type);
  if (!files.length) return [];

  const n = linesParam === 'all' ? Infinity : (parseInt(linesParam, 10) || 300);
  const applyFilter = (line) => !(filter === 'success' && !SUCCESS_RE.test(line));

  if (n === Infinity) {
    const out = [];
    for (const file of files) {
      const content = fs.readFileSync(path.join(LOGS_DIR, file), 'utf8');
      for (const line of content.split('\n')) {
        if (!line) continue;
        if (!applyFilter(line)) continue;
        out.push(line);
      }
    }
    return out;
  }

  let collected = [];
  for (let i = files.length - 1; i >= 0 && collected.length < n; i--) {
    const content = fs.readFileSync(path.join(LOGS_DIR, files[i]), 'utf8');
    let lines = content.split('\n').filter(Boolean).filter(applyFilter);
    if (!lines.length) continue;

    const needed = n - collected.length;
    if (lines.length > needed) lines = lines.slice(-needed);
    collected = lines.concat(collected);
  }

  return collected;
}

// For since mode: stream file-by-file, async so the event loop can flush writes between reads
async function streamSinceLines(type, sinceParam, filter, res) {
  const files = getLogFiles(type);
  const cutoffMs = sinceParam === 'all' ? 0 : Date.now() - (SINCE_SECONDS[sinceParam] || 0) * 1000;
  let count = 0;

  for (const file of files) {
    if (res.destroyed) break;
    if (sinceParam !== 'all') {
      const fileDateStr = file.slice(type.length + 1, -4);
      const fileStartMs = new Date(fileDateStr).getTime(); // date-only → UTC midnight, fine for skipping whole days
      if (fileStartMs + 86400000 < cutoffMs) continue;
    }
    const content = await fs.promises.readFile(path.join(LOGS_DIR, file), 'utf8');
    let i = 0;
    for (const line of content.split('\n')) {
      if (!line) continue;
      if (res.destroyed) break; // stop immediately — don't block the event loop
      if (sinceParam !== 'all') {
        const m = line.match(/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})/);
        if (!m || parseLogTs(m[1]) < cutoffMs) continue;
      }
      if (filter === 'success' && !SUCCESS_RE.test(line)) continue;
      res.write(`data: ${JSON.stringify(line)}\n\n`);
      count++;
      // Yield every 10k lines so the event loop can flush writes to the client
      if (++i % 10000 === 0) await new Promise(r => setImmediate(r));
    }
    if (res.destroyed) break; // also break outer loop
  }
  return count;
}

// SSE: stream log file
app.get('/api/logs/stream', async (req, res) => {
  const type = req.query.type === 'error' ? 'error' : 'verbose';
  const linesParam = req.query.lines || '300';
  const sinceParam = req.query.since || null;
  const filter = req.query.filter || null;

  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache, no-transform');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('X-Accel-Buffering', 'no');
  res.flushHeaders();
  if (req.socket) req.socket.setNoDelay(true); // disable Nagle so SSE chunks flush immediately

  // Push an initial padding comment so proxies flush low-volume streams quickly.
  res.write(': ' + ' '.repeat(2048) + '\n\n');

  function getLogFile() {
    const today = new Date().toISOString().split('T')[0];
    return path.join(LOGS_DIR, `${type}.${today}.log`);
  }

  // Signal immediately that the connection is live
  res.write(`event: start\ndata: {}\n\n`);

  // Register close handler before any awaits so cleanup works if client disconnects mid-stream
  let interval = null;
  const keepalive = setInterval(() => {
    if (!res.destroyed) res.write(': keepalive\n\n');
  }, 15000);
  req.on('close', () => {
    if (interval) clearInterval(interval);
    clearInterval(keepalive);
  });

  // For since queries: async stream file-by-file — event loop can flush writes between reads
  // For lines queries: read today's file only (fast)
  let initialCount;
  if (sinceParam) {
    initialCount = await streamSinceLines(type, sinceParam, filter, res);
  } else {
    const lines = getLinesInitial(type, linesParam, filter);
    for (const line of lines) res.write(`data: ${JSON.stringify(line)}\n\n`);
    initialCount = lines.length;
  }

  if (res.destroyed) return;
  res.write(`event: ready\ndata: ${JSON.stringify({ count: initialCount })}\n\n`);

  const logFile = getLogFile();
  let pos = fs.existsSync(logFile) ? fs.statSync(logFile).size : 0;
  let currentDate = new Date().toISOString().split('T')[0];

  interval = setInterval(() => {
    const newDate = new Date().toISOString().split('T')[0];
    if (newDate !== currentDate) {
      currentDate = newDate;
      pos = 0;
    }

    const file = getLogFile();
    if (!fs.existsSync(file)) return;

    const stat = fs.statSync(file);
    if (stat.size <= pos) return;

    const buf = Buffer.alloc(stat.size - pos);
    const fd = fs.openSync(file, 'r');
    fs.readSync(fd, buf, 0, buf.length, pos);
    fs.closeSync(fd);
    pos = stat.size;

    const lines = buf.toString('utf8').split('\n').filter(Boolean);
    for (const line of lines) {
      res.write(`data: ${JSON.stringify(line)}\n\n`);
    }
  }, 500);
});

// List available log files
app.get('/api/logs/files', (req, res) => {
  try {
    const files = fs.readdirSync(LOGS_DIR)
      .filter(f => f.endsWith('.log'))
      .sort()
      .reverse()
      .slice(0, 30);
    res.json(files);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Read config
app.get('/api/config', (req, res) => {
  try {
    const content = fs.readFileSync(CONFIG_PATH, 'utf8');
    const templateContent = readConfigTemplateContent();
    res.json({ content, templateContent });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Write config (auto-backup before saving)
app.post('/api/config', (req, res) => {
  const { content } = req.body;
  if (!content || typeof content !== 'string') {
    return res.status(400).json({ error: 'No content provided' });
  }
  try {
    const ts = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
    const backup = `${CONFIG_PATH}.${ts}.bak`;
    fs.copyFileSync(CONFIG_PATH, backup);
    fs.writeFileSync(CONFIG_PATH, content, 'utf8');
    res.json({ success: true, backup: path.basename(backup) });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Restart cross-seed daemon
app.post('/api/restart', (req, res) => {
  const { execFile } = require('child_process');
  execFile('systemctl', ['restart', 'cross-seed'], { timeout: 10000 }, (err) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ success: true });
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`cross-seed UI running → http://0.0.0.0:${PORT}`);
  console.log(`Form login enabled (user: ${UI_USERNAME})`);
});
