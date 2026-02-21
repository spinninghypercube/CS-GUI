# CS-GUI

![Node.js](https://img.shields.io/badge/node-%3E%3D18-339933?logo=node.js&logoColor=white)
![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)

`CS-GUI` is an **add-on web interface** for [`cross-seed`](https://github.com/cross-seed/cross-seed).
It gives you a browser UI for logs, jobs, and config management while your `cross-seed` daemon keeps doing the actual work.

<img width="429" height="933" alt="logs success" src="https://github.com/user-attachments/assets/42437e58-6b48-44d7-b5d0-241269256d1c" />

<img width="429" height="933" alt="config" src="https://github.com/user-attachments/assets/0e672e1e-9952-4182-91e4-5578e2ce0200" />


## Important

- This project is **not** `cross-seed` itself.
- This project does **not** replace or fork the `cross-seed` daemon.
- You still need a working `cross-seed` installation.

## Upstream cross-seed

- GitHub: https://github.com/cross-seed/cross-seed
- Website and docs: https://www.cross-seed.org

## Features

- Live log stream with filters (`verbose`, `error`, `success`)
- Correct last `N` behavior for filtered success/error views
- Stable tracker highlighting (same tracker, same color)
- Job triggers (`rss`, `search`, `inject`) from the UI
- Structured editor for `cross-seed` config fields
- Optional `Full help` toggle for config comments
- Light and dark mode with persisted preferences
- Persisted UI state for tab/filter/theme between reloads
- Display of detected `cross-seed` runtime version in config view

## Requirements

- Node.js `>=18`
- npm `>=9` (usually bundled with Node)
- A reachable `cross-seed` instance with API key enabled
- Access to `cross-seed` config/log files (or correct env overrides)

## Installation

### 1. Clone this repository

```bash
git clone https://github.com/spinninghypercube/CS-GUI.git
cd CS-GUI
```

### 2. Install dependencies

```bash
npm install
```

### 3. Create secrets environment file (recommended)

```bash
mkdir -p /root/cross-seed-ui-secrets
cp .env.example /root/cross-seed-ui-secrets/.env.local
```

### 4. Set required values in `/root/cross-seed-ui-secrets/.env.local`

At minimum set:

- `CROSS_SEED_API_KEY`
- `CROSS_SEED_UI_PASSWORD`
- `CROSS_SEED_UI_SESSION_SECRET`

### 5. Start the UI

```bash
npm start
```

Open `http://<host>:3000`.

## Dependencies Explained

### Runtime

- `Node.js >= 18`
  - Runs `server.js`
  - Provides built-in modules used directly (`fs`, `path`, `http`, `crypto`)

### npm packages

- `express`
  - Handles routes, static files, auth/session cookies, and API proxy endpoints
- `bulma`
  - Base CSS framework for UI styling

### External service dependency

- `cross-seed`
  - Needed for health checks, job triggers, logs, and config workflow

## Configuration

The app loads env files in this order:

1. `CROSS_SEED_UI_ENV_FILE` path (if set)
2. `/root/cross-seed-ui-secrets/.env.local`
3. `.env.local` (fallback for compatibility)
4. `.env`

OS-level environment variables override file values.

### Environment Variables

| Variable | Default | Purpose |
|---|---|---|
| `PORT` | `3000` | UI listen port |
| `CROSS_SEED_HOST` | `127.0.0.1` | `cross-seed` host |
| `CROSS_SEED_PORT` | `2468` | `cross-seed` API port |
| `CROSS_SEED_API_KEY` | none | API key used for `cross-seed` requests |
| `CROSS_SEED_UI_USERNAME` | `admin` | Username for UI login |
| `CROSS_SEED_UI_PASSWORD` | API key fallback, then `admin` | Password for UI login |
| `CROSS_SEED_UI_SESSION_SECRET` | API key fallback | Secret used to sign session cookie data |
| `CROSS_SEED_UI_ENV_FILE` | none | Optional explicit env file path |
| `CROSS_SEED_CONFIG_PATH` | `/root/.cross-seed/config.js` | Path to config file managed in UI |
| `CROSS_SEED_LOGS_DIR` | `/root/.cross-seed/logs` | Directory containing `cross-seed` logs |

## Usage

1. Log in to the UI.
2. Open **Logs** to inspect daemon output.
3. Use filter buttons and line limits to isolate events.
4. Open **Cross-seed Config** to edit settings through structured fields.
5. Save config, then trigger jobs (`rss`, `search`, `inject`) as needed.

## Systemd Example

```ini
[Unit]
Description=CS-GUI
After=network.target cross-seed.service
Wants=cross-seed.service

[Service]
Type=simple
User=root
WorkingDirectory=/root/cross-seed-ui
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
```

## Security Notes

- Never commit `.env.local` or any file with real secrets
- Keep secrets outside the repo when possible
- Use a strong `CROSS_SEED_UI_SESSION_SECRET`
- Rotate credentials if they were ever exposed
- Prefer LAN-only exposure or protect with a reverse proxy

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening PRs.
For responsible disclosure, see [SECURITY.md](SECURITY.md).

## License

MIT - see [LICENSE](LICENSE).
