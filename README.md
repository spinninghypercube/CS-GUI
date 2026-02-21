# CS-GUI

![Node.js](https://img.shields.io/badge/node-%3E%3D18-339933?logo=node.js&logoColor=white)
![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)

`CS-GUI` is an **add-on web interface** for [`cross-seed`](https://github.com/cross-seed/cross-seed).
It gives you a browser UI for logs, jobs, and config management while your normal `cross-seed` daemon keeps doing the actual work.

## Important

- This project is **not** `cross-seed` itself.
- This project does **not** replace or fork the `cross-seed` daemon.
- You still need a working `cross-seed` installation.

## Upstream cross-seed

- GitHub: https://github.com/cross-seed/cross-seed
- Website and docs: https://www.cross-seed.org

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Dependencies Explained](#dependencies-explained)
- [Configuration](#configuration)
- [Usage](#usage)
- [Systemd Example](#systemd-example)
- [Troubleshooting](#troubleshooting)
- [Security Notes](#security-notes)
- [Project Structure](#project-structure)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

## Features

- Live log stream with filters (`verbose`, `error`, `success`)
- Correct last `N` behavior for filtered success/error views
- Stable tracker highlighting (same tracker, same color)
- Job triggers (`rss`, `search`, `inject`) from the UI
- Structured editor for `cross-seed` config fields
- Optional `Full help` toggle to show field explanations from config comments
- Light and dark mode with persisted preferences
- Persisted UI state for tab/filter/theme between reloads
- Display of detected `cross-seed` runtime version in config view

## Requirements

- Node.js `>=18`
- npm `>=9` (usually bundled with Node)
- A reachable `cross-seed` instance with API key enabled
- Access to your `cross-seed` config/log files (or correct env overrides)

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

### 3. Create local environment file

```bash
cp .env.example .env.local
```

### 4. Set required values in `.env.local`

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

1. `.env.local`
2. `.env`

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
| `CROSS_SEED_CONFIG_PATH` | `/root/.cross-seed/config.js` | Path to config file managed in UI |
| `CROSS_SEED_LOGS_DIR` | `/root/.cross-seed/logs` | Directory containing `cross-seed` logs |

## Usage

1. Log in to the UI.
2. Open the **Logs** tab to inspect daemon output.
3. Use filter buttons and line limits to isolate relevant events.
4. Open **Cross-seed Config** to edit settings through structured fields.
5. Save config, then trigger relevant jobs (`rss`, `search`, `inject`) as needed.

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

## Troubleshooting

- Login works but API calls fail:
  - Verify `CROSS_SEED_API_KEY`, host, and port values.
- Filtered logs show less data than expected:
  - Verify `CROSS_SEED_LOGS_DIR` points to actual `cross-seed` log files.
- Config view is empty after startup:
  - Confirm `CROSS_SEED_CONFIG_PATH` is valid and readable.
- UI does not load:
  - Check service logs and ensure the configured `PORT` is open.

## Security Notes

- Never commit `.env.local`
- Rotate credentials if they were ever exposed
- Use a strong `CROSS_SEED_UI_SESSION_SECRET`
- Prefer LAN-only exposure or protect with a reverse proxy

## Project Structure

```text
.
├── public/
│   ├── index.html
│   └── vendor/
├── server.js
├── .env.example
├── package.json
├── README.md
└── .github/
```

## Roadmap

- waiting for comments

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening PRs.

For responsible disclosure, see [SECURITY.md](SECURITY.md).

## License

MIT - see [LICENSE](LICENSE).
