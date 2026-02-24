# CS-GUI

![Node.js](https://img.shields.io/badge/node-%3E%3D18-339933?logo=node.js&logoColor=white)
![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)
[![CI](https://github.com/spinninghypercube/CS-GUI/actions/workflows/ci.yml/badge.svg)](https://github.com/spinninghypercube/CS-GUI/actions/workflows/ci.yml)
![GitHub Release](https://img.shields.io/github/v/release/spinninghypercube/CS-GUI?sort=semver)
![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/spinninghypercube/CS-GUI/total)

`CS-GUI` is an **add-on web interface** for [`cross-seed`](https://github.com/cross-seed/cross-seed).
It gives you a browser UI for logs, jobs, and config management while your `cross-seed` daemon keeps doing the actual work.

## Copy/Paste Install (Guided)

```bash
git clone https://github.com/spinninghypercube/CS-GUI.git
cd CS-GUI
sudo bash scripts/install.sh
```

## Important (Read First)

- This project is **not** `cross-seed` itself.
- This project does **not** replace or fork the `cross-seed` daemon.
- You still need a working `cross-seed` installation.

## 2-Minute Quick Start

```bash
git clone https://github.com/spinninghypercube/CS-GUI.git
cd CS-GUI
npm install
mkdir -p /root/cross-seed-ui-secrets
cp .env.example /root/cross-seed-ui-secrets/.env.local
# edit /root/cross-seed-ui-secrets/.env.local (set API key + UI password + session secret)
npm start
```

Open `http://<host>:3000` and sign in with your configured UI credentials.

## Screenshots

<img width="429" height="933" alt="logs success" src="https://github.com/user-attachments/assets/42437e58-6b48-44d7-b5d0-241269256d1c" />

<img width="429" height="933" alt="config" src="https://github.com/user-attachments/assets/0e672e1e-9952-4182-91e4-5578e2ce0200" />

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
- Setup/onboarding checklist when API/config are unavailable
- Display of detected `cross-seed` runtime version in config view

## Compatibility Matrix

| Component | Tested / Target |
|---|---|
| OS | Debian 12 (including Proxmox LXC) |
| Node.js | >= 18 (CI uses Node 20) |
| npm | >= 9 |
| cross-seed | v6-style API (`/api/ping`, `/api/job`) |

## Requirements

- Node.js `>=18`
- npm `>=9` (usually bundled with Node)
- A reachable `cross-seed` instance with API key enabled
- Access to `cross-seed` config/log files (or correct env overrides)

## Installation Options

### Option A: Guided Install Script (Recommended)

```bash
sudo bash scripts/install.sh
```

What it does:

- installs npm dependencies
- creates `/root/cross-seed-ui-secrets/.env.local`
- prompts for required values
- optionally installs/enables `systemd` service
- runs `scripts/doctor.sh`

### Option B: Manual Install

#### 1. Clone this repository

```bash
git clone https://github.com/spinninghypercube/CS-GUI.git
cd CS-GUI
```

#### 2. Install dependencies

```bash
npm install
```

#### 3. Create secrets environment file (recommended)

```bash
mkdir -p /root/cross-seed-ui-secrets
cp .env.example /root/cross-seed-ui-secrets/.env.local
chmod 600 /root/cross-seed-ui-secrets/.env.local
```

#### 4. Set required values in `/root/cross-seed-ui-secrets/.env.local`

At minimum set:

- `CROSS_SEED_API_KEY`
- `CROSS_SEED_UI_PASSWORD`
- `CROSS_SEED_UI_SESSION_SECRET`

#### 5. Start the UI

```bash
npm start
```

## Preflight / Troubleshooting (Doctor)

Run this any time after changing paths, keys, or host settings:

```bash
bash scripts/doctor.sh
```

It checks:

- Node/npm versions
- local Bulma asset presence
- env file and permissions
- required values (API key / UI credentials)
- config/log path existence
- cross-seed API reachability
- `npm run check`
- systemd service status (if installed)

## Docker (Optional)

Included files:

- `Dockerfile`
- `docker-compose.yml`

Quick start:

```bash
mkdir -p docker
cp .env.example docker/cs-gui.env
# edit docker/cs-gui.env

docker compose up -d --build
```

Notes:

- `docker-compose.yml` expects bind mounts for `cross-seed` config and logs.
- API actions can work remotely, but config/log features require mounted readable paths.

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

`CROSS_SEED_HOST` is the address CS-GUI uses to reach the `cross-seed` API. It does not change the `cross-seed` daemon bind address in `config.js`.

### Recommended cross-seed daemon bind (same-host installs)

If CS-GUI and `cross-seed` run on the same machine/container, set the `cross-seed` daemon `host` in its config (usually `/root/.cross-seed/config.js`) to:

```js
host: "127.0.0.1",
```

This prevents the raw `cross-seed` API port (default `2468`) from being reachable by other LAN devices while CS-GUI still works normally through localhost.

## Running as a Service (systemd)

- Template unit file: `deploy/cross-seed-ui.service`
- Guided script can install it for you: `sudo bash scripts/install.sh`

Manual install:

```bash
sudo cp deploy/cross-seed-ui.service /etc/systemd/system/cross-seed-ui.service
sudo systemctl daemon-reload
sudo systemctl enable --now cross-seed-ui.service
```

## Common Setups

See [`docs/COMMON_SETUPS.md`](docs/COMMON_SETUPS.md) for:

- same-host setup (recommended)
- remote cross-seed host
- reverse proxy deployment
- Proxmox LXC notes

## Backup / Restore

See [`docs/BACKUP_RESTORE.md`](docs/BACKUP_RESTORE.md).

CS-GUI creates an automatic backup before saving config changes, but manual backups are still recommended before major edits.

## Known Limitations

See [`docs/KNOWN_LIMITATIONS.md`](docs/KNOWN_LIMITATIONS.md).

This project is early-stage and optimized for practical local/self-hosted use first.

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

## Security Notes

- Never commit `.env.local` or any file with real secrets
- Keep secrets outside the repo when possible
- Use a strong `CROSS_SEED_UI_SESSION_SECRET`
- Rotate credentials if they were ever exposed
- Prefer LAN-only exposure or protect with a reverse proxy
- For same-host installs, prefer `cross-seed` config `host: "127.0.0.1"` instead of `0.0.0.0`
- If using a reverse proxy (Caddy / Nginx Proxy Manager), proxy CS-GUI (`:3000`) and avoid exposing the raw `cross-seed` API (`:2468`) unless required

## Project Health / Automation

Included in this repo:

- GitHub Actions CI (`.github/workflows/ci.yml`) for install + syntax checks
- Dependabot (`.github/dependabot.yml`) for npm and GitHub Actions updates
- Issue and PR templates for easier contributions

## Releases and Changelog

- Changelog: [`CHANGELOG.md`](CHANGELOG.md)
- Release process notes: [`docs/RELEASING.md`](docs/RELEASING.md)

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening PRs.
For responsible disclosure, see [SECURITY.md](SECURITY.md).

## License

MIT - see [LICENSE](LICENSE).
