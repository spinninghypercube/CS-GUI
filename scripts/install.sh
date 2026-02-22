#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_SECRETS_DIR="/root/cross-seed-ui-secrets"
DEFAULT_ENV_FILE="$DEFAULT_SECRETS_DIR/.env.local"
SERVICE_NAME="cross-seed-ui.service"
SERVICE_TEMPLATE="$REPO_DIR/deploy/cross-seed-ui.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"
NODE_BIN="$(command -v node || true)"
NPM_BIN="$(command -v npm || true)"
NON_INTERACTIVE="${NON_INTERACTIVE:-0}"
SKIP_SERVICE="${SKIP_SERVICE:-0}"

err() { printf 'ERROR: %s\n' "$*" >&2; }
info() { printf '==> %s\n' "$*"; }
prompt_default() {
  local message="$1" default="$2" value
  if [ "$NON_INTERACTIVE" = "1" ]; then
    printf '%s\n' "$default"
    return
  fi
  read -r -p "$message [$default]: " value
  printf '%s\n' "${value:-$default}"
}
random_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  elif command -v node >/dev/null 2>&1; then
    node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
  else
    date +%s | sha256sum | awk '{print $1}'
  fi
}
set_env_key() {
  local file="$1" key="$2" value="$3"
  local esc_value
  esc_value=$(printf '%s' "$value" | sed 's/[\\&|]/\\&/g')
  if grep -qE "^${key}=" "$file"; then
    sed -i "s|^${key}=.*|${key}=${esc_value}|" "$file"
  else
    printf '%s=%s\n' "$key" "$value" >> "$file"
  fi
}

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  err "Run as root (needed for secrets path and optional systemd install)."
  exit 1
fi
if [ -z "$NODE_BIN" ] || [ -z "$NPM_BIN" ]; then
  err "Node.js and npm are required. Install Node.js >= 18 first."
  exit 1
fi
if [ ! -f "$REPO_DIR/package.json" ] || [ ! -f "$REPO_DIR/server.js" ]; then
  err "Run this script from inside the CS-GUI repository checkout."
  exit 1
fi
if [ ! -f "$REPO_DIR/.env.example" ]; then
  err "Missing .env.example in repository root."
  exit 1
fi

info "Installing npm dependencies"
(cd "$REPO_DIR" && npm install --omit=dev)

mkdir -p "$DEFAULT_SECRETS_DIR"
chmod 700 "$DEFAULT_SECRETS_DIR"
if [ ! -f "$DEFAULT_ENV_FILE" ]; then
  info "Creating secrets env file at $DEFAULT_ENV_FILE"
  cp "$REPO_DIR/.env.example" "$DEFAULT_ENV_FILE"
  chmod 600 "$DEFAULT_ENV_FILE"
else
  info "Using existing secrets env file at $DEFAULT_ENV_FILE"
fi

api_key="$(prompt_default 'cross-seed API key' 'replace_with_cross_seed_api_key')"
ui_user="$(prompt_default 'UI username' 'admin')"
ui_pass="$(prompt_default 'UI password' 'change_me')"
session_default="$(random_secret)"
session_secret="$(prompt_default 'UI session secret' "$session_default")"
cs_host="$(prompt_default 'cross-seed host' '127.0.0.1')"
cs_port="$(prompt_default 'cross-seed port' '2468')"
ui_port="$(prompt_default 'CS-GUI listen port' '3000')"
config_path="$(prompt_default 'cross-seed config path' '/root/.cross-seed/config.js')"
logs_path="$(prompt_default 'cross-seed logs dir' '/root/.cross-seed/logs')"

set_env_key "$DEFAULT_ENV_FILE" CROSS_SEED_UI_ENV_FILE "$DEFAULT_ENV_FILE"
set_env_key "$DEFAULT_ENV_FILE" CROSS_SEED_API_KEY "$api_key"
set_env_key "$DEFAULT_ENV_FILE" CROSS_SEED_UI_USERNAME "$ui_user"
set_env_key "$DEFAULT_ENV_FILE" CROSS_SEED_UI_PASSWORD "$ui_pass"
set_env_key "$DEFAULT_ENV_FILE" CROSS_SEED_UI_SESSION_SECRET "$session_secret"
set_env_key "$DEFAULT_ENV_FILE" CROSS_SEED_HOST "$cs_host"
set_env_key "$DEFAULT_ENV_FILE" CROSS_SEED_PORT "$cs_port"
set_env_key "$DEFAULT_ENV_FILE" PORT "$ui_port"
set_env_key "$DEFAULT_ENV_FILE" CROSS_SEED_CONFIG_PATH "$config_path"
set_env_key "$DEFAULT_ENV_FILE" CROSS_SEED_LOGS_DIR "$logs_path"
chmod 600 "$DEFAULT_ENV_FILE"

if [ "$SKIP_SERVICE" != "1" ] && command -v systemctl >/dev/null 2>&1 && [ -f "$SERVICE_TEMPLATE" ]; then
  install_service="Y"
  if [ "$NON_INTERACTIVE" != "1" ]; then
    read -r -p "Install/refresh systemd service ($SERVICE_NAME)? [Y/n]: " install_service
    install_service="${install_service:-Y}"
  fi
  case "$install_service" in
    Y|y|yes|YES)
      info "Installing systemd unit at $SERVICE_PATH"
      cp "$SERVICE_TEMPLATE" "$SERVICE_PATH"
      sed -i "s|^WorkingDirectory=.*|WorkingDirectory=$REPO_DIR|" "$SERVICE_PATH"
      sed -i "s|^ExecStart=.*|ExecStart=$NODE_BIN $REPO_DIR/server.js|" "$SERVICE_PATH"
      systemctl daemon-reload
      systemctl enable --now "$SERVICE_NAME"
      ;;
    *) info "Skipping systemd unit installation" ;;
  esac
fi

if [ -x "$REPO_DIR/scripts/doctor.sh" ]; then
  info "Running preflight checks"
  "$REPO_DIR/scripts/doctor.sh" "$DEFAULT_ENV_FILE" || true
fi

printf '\nCS-GUI install complete.\n'
printf 'Repo: %s\n' "$REPO_DIR"
printf 'Secrets: %s\n' "$DEFAULT_ENV_FILE"
printf 'Open: http://<host>:%s\n' "$ui_port"
printf '\nTip: run scripts/doctor.sh any time to verify the setup.\n'
