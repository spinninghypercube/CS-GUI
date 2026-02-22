# Common Setups

## 1. Same Host as cross-seed (Recommended)

Use this when CS-GUI runs on the same machine/container as `cross-seed`.

- `CROSS_SEED_HOST=127.0.0.1`
- `CROSS_SEED_PORT=2468`
- `CROSS_SEED_CONFIG_PATH=/root/.cross-seed/config.js`
- `CROSS_SEED_LOGS_DIR=/root/.cross-seed/logs`

Why this is easiest:

- No extra firewall rules
- No remote file mounting
- Lowest latency to API/logs

## 2. Separate Host (Remote cross-seed API)

Use this when CS-GUI runs on a different machine than `cross-seed`.

Set:

- `CROSS_SEED_HOST=<remote-ip-or-hostname>`
- `CROSS_SEED_PORT=<cross-seed-api-port>`
- `CROSS_SEED_API_KEY=<same key as remote cross-seed>`

Notes:

- The GUI can reach jobs/ping over the API, but config/log editing requires valid paths local to the CS-GUI host.
- If config/logs live only on the remote machine, mount them (NFS/SMB/SSHFS/bind mounts) or skip config/log features.

## 3. Reverse Proxy (Caddy / Nginx)

Expose CS-GUI through a reverse proxy when you need TLS or friendly hostnames.

Recommended:

- Keep CS-GUI bound to LAN/private network only
- Add auth/TLS at proxy layer if exposed outside LAN
- Preserve standard headers (`Host`, `X-Forwarded-*`)

## 4. Proxmox LXC

Common considerations for LXC deployments:

- Verify the container can read the `cross-seed` config and logs paths
- Keep `.env` secrets outside the repo (for example `/root/cross-seed-ui-secrets/.env.local`)
- Use `scripts/doctor.sh` after upgrades or path changes
- If using a bind mount for logs, confirm permissions and ownership inside the container
