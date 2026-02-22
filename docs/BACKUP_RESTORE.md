# Backup and Restore

## What CS-GUI Does Automatically

Before saving config changes from the UI, CS-GUI creates an automatic backup of your `cross-seed` config file.

Backup filename pattern:

- `<config-path>.<timestamp>.bak`

Example:

- `/root/.cross-seed/config.js.2026-02-22T12-34-56.bak`

## Manual Backup (Recommended Before Major Changes)

```bash
cp /root/.cross-seed/config.js /root/.cross-seed/config.js.manual.$(date +%F-%H%M%S).bak
```

## Restore a Backup

1. Stop or pause changes in the UI.
2. Copy the backup back into place.
3. Reload config in the UI.
4. Trigger a `cross-seed` restart/job if needed.

Example:

```bash
cp /root/.cross-seed/config.js.2026-02-22T12-34-56.bak /root/.cross-seed/config.js
systemctl restart cross-seed
```

## Suggested Backup Scope for CS-GUI

For disaster recovery, back up at least:

- `/root/cross-seed-ui-secrets/.env.local`
- `/root/cross-seed-ui` (repo checkout, if locally modified)
- `/root/.cross-seed/config.js`
- `/root/.cross-seed/logs` (optional, for troubleshooting history)
