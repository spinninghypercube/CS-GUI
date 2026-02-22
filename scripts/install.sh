#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_SECRETS_DIR="${CS_GUI_SECRETS_DIR:-/root/cross-seed-ui-secrets}"
DEFAULT_ENV_FILE="${CS_GUI_ENV_FILE:-$DEFAULT_SECRETS_DIR/.env.local}"
SERVICE_NAME="${CS_GUI_SERVICE_NAME:-cross-seed-ui.service}"
SERVICE_TEMPLATE="$REPO_DIR/deploy/cross-seed-ui.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"
NODE_BIN="$(command -v node || true)"
NPM_BIN="$(command -v npm || true)"
NON_INTERACTIVE="${NON_INTERACTIVE:-0}"
SKIP_SERVICE="${SKIP_SERVICE:-0}"

err() { printf 'ERROR: %s\n' "$*" >&2; }
info() { printf '==> %s\n' "$*"; }
read_env_key() {
  local file="$1" key="$2" line
  line=$(grep -E "^${key}=" "$file" 2>/dev/null | tail -n 1 || true)
  printf '%s' "${line#*=}"
}
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

existing_api_key="$(read_env_key "$DEFAULT_ENV_FILE" CROSS_SEED_API_KEY)"
existing_ui_user="$(read_env_key "$DEFAULT_ENV_FILE" CROSS_SEED_UI_USERNAME)"
existing_ui_pass="$(read_env_key "$DEFAULT_ENV_FILE" CROSS_SEED_UI_PASSWORD)"
existing_session_secret="$(read_env_key "$DEFAULT_ENV_FILE" CROSS_SEED_UI_SESSION_SECRET)"
existing_cs_host="$(read_env_key "$DEFAULT_ENV_FILE" CROSS_SEED_HOST)"
existing_cs_port="$(read_env_key "$DEFAULT_ENV_FILE" CROSS_SEED_PORT)"
existing_ui_port="$(read_env_key "$DEFAULT_ENV_FILE" PORT)"
existing_config_path="$(read_env_key "$DEFAULT_ENV_FILE" CROSS_SEED_CONFIG_PATH)"
existing_logs_path="$(read_env_key "$DEFAULT_ENV_FILE" CROSS_SEED_LOGS_DIR)"

api_key="${CS_GUI_API_KEY:-}"
if [ -z "$api_key" ]; then
  if [ "$NON_INTERACTIVE" = "1" ] && [ -n "$existing_api_key" ]; then api_key="$existing_api_key"; else api_key="$(prompt_default 'cross-seed API key' 'replace_with_cross_seed_api_key')"; fi
fi
ui_user="${CS_GUI_UI_USERNAME:-}"
if [ -z "$ui_user" ]; then
  if [ "$NON_INTERACTIVE" = "1" ] && [ -n "$existing_ui_user" ]; then ui_user="$existing_ui_user"; else ui_user="$(prompt_default 'UI username' 'admin')"; fi
fi
ui_pass="${CS_GUI_UI_PASSWORD:-}"
if [ -z "$ui_pass" ]; then
  if [ "$NON_INTERACTIVE" = "1" ] && [ -n "$existing_ui_pass" ]; then ui_pass="$existing_ui_pass"; else ui_pass="$(prompt_default 'UI password' 'change_me')"; fi
fi
session_default="$(random_secret)"
session_secret="${CS_GUI_SESSION_SECRET:-}"
if [ -z "$session_secret" ]; then
  if [ "$NON_INTERACTIVE" = "1" ] && [ -n "$existing_session_secret" ]; then session_secret="$existing_session_secret"; else session_secret="$(prompt_default 'UI session secret' "$session_default")"; fi
fi
cs_host="${CS_GUI_CROSS_SEED_HOST:-}"
if [ -z "$cs_host" ]; then
  if [ "$NON_INTERACTIVE" = "1" ] && [ -n "$existing_cs_host" ]; then cs_host="$existing_cs_host"; else cs_host="$(prompt_default 'cross-seed host' '127.0.0.1')"; fi
fi
cs_port="${CS_GUI_CROSS_SEED_PORT:-}"
if [ -z "$cs_port" ]; then
  if [ "$NON_INTERACTIVE" = "1" ] && [ -n "$existing_cs_port" ]; then cs_port="$existing_cs_port"; else cs_port="$(prompt_default 'cross-seed port' '2468')"; fi
fi
ui_port="${CS_GUI_PORT:-}"
if [ -z "$ui_port" ]; then
  if [ "$NON_INTERACTIVE" = "1" ] && [ -n "$existing_ui_port" ]; then ui_port="$existing_ui_port"; else ui_port="$(prompt_default 'CS-GUI listen port' '3000')"; fi
fi
config_path="${CS_GUI_CONFIG_PATH:-}"
if [ -z "$config_path" ]; then
  if [ "$NON_INTERACTIVE" = "1" ] && [ -n "$existing_config_path" ]; then config_path="$existing_config_path"; else config_path="$(prompt_default 'cross-seed config path' '/root/.cross-seed/config.js')"; fi
fi
logs_path="${CS_GUI_LOGS_DIR:-}"
if [ -z "$logs_path" ]; then
  if [ "$NON_INTERACTIVE" = "1" ] && [ -n "$existing_logs_path" ]; then logs_path="$existing_logs_path"; else logs_path="$(prompt_default 'cross-seed logs dir' '/root/.cross-seed/logs')"; fi
fi

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
