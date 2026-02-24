#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT_ENV_FILE="${1:-}"
DEFAULT_ENV_FILE="/root/cross-seed-ui-secrets/.env.local"
FALLBACK_ENV_FILE="$REPO_DIR/.env.local"
ENV_FILE=""
FAILS=0
WARNS=0

pass() { printf '[PASS] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; WARNS=$((WARNS+1)); }
fail() { printf '[FAIL] %s\n' "$*"; FAILS=$((FAILS+1)); }
note() { printf '[INFO] %s\n' "$*"; }
read_env_value() {
  local key="$1" file="$2" line value
  line=$(grep -E "^${key}=" "$file" 2>/dev/null | tail -n 1 || true)
  value="${line#*=}"
  printf '%s' "$value"
}
looks_placeholder() {
  case "$1" in
    ''|change_me|change_me_with_a_long_random_secret|replace_with_cross_seed_api_key|your_*|example|example.com) return 0 ;;
    *) return 1 ;;
  esac
}

cd "$REPO_DIR"
note "Repo: $REPO_DIR"

if command -v node >/dev/null 2>&1; then
  node_ver=$(node -v)
  node_major=$(node -p "Number(process.versions.node.split('.')[0])")
  if [ "$node_major" -ge 18 ]; then
    pass "Node.js $node_ver (>= 18)"
  else
    fail "Node.js $node_ver detected (need >= 18)"
  fi
else
  fail "Node.js not found"
fi

if command -v npm >/dev/null 2>&1; then
  pass "npm $(npm -v)"
else
  fail "npm not found"
fi

[ -f package.json ] && pass "package.json present" || fail "package.json missing"
[ -f server.js ] && pass "server.js present" || fail "server.js missing"
[ -f public/index.html ] && pass "public/index.html present" || fail "public/index.html missing"
[ -f public/vendor/bulma.min.css ] && pass "local Bulma stylesheet present" || fail "public/vendor/bulma.min.css missing"
[ -d node_modules/express ] && pass "npm dependencies installed (express present)" || warn "node_modules/express not found (run npm install)"

if [ -n "$INPUT_ENV_FILE" ] && [ -f "$INPUT_ENV_FILE" ]; then
  ENV_FILE="$INPUT_ENV_FILE"
elif [ -f "$DEFAULT_ENV_FILE" ]; then
  ENV_FILE="$DEFAULT_ENV_FILE"
elif [ -f "$FALLBACK_ENV_FILE" ]; then
  ENV_FILE="$FALLBACK_ENV_FILE"
fi

if [ -z "$ENV_FILE" ]; then
  fail "No env file found (checked $DEFAULT_ENV_FILE and $FALLBACK_ENV_FILE)"
else
  pass "Env file found: $ENV_FILE"
  perms=$(stat -c '%a' "$ENV_FILE" 2>/dev/null || echo '?')
  if [ "$perms" = "600" ] || [ "$perms" = "400" ]; then
    pass "Env file permissions are restrictive ($perms)"
  else
    warn "Env file permissions are $perms (recommended: 600)"
  fi

  CS_HOST="$(read_env_value CROSS_SEED_HOST "$ENV_FILE")"; CS_HOST="${CS_HOST:-127.0.0.1}"
  CS_PORT="$(read_env_value CROSS_SEED_PORT "$ENV_FILE")"; CS_PORT="${CS_PORT:-2468}"
  UI_PORT="$(read_env_value PORT "$ENV_FILE")"; UI_PORT="${UI_PORT:-3000}"
  API_KEY="$(read_env_value CROSS_SEED_API_KEY "$ENV_FILE")"
  UI_USER="$(read_env_value CROSS_SEED_UI_USERNAME "$ENV_FILE")"; UI_USER="${UI_USER:-admin}"
  UI_PASS="$(read_env_value CROSS_SEED_UI_PASSWORD "$ENV_FILE")"
  UI_SECRET="$(read_env_value CROSS_SEED_UI_SESSION_SECRET "$ENV_FILE")"
  CFG_PATH="$(read_env_value CROSS_SEED_CONFIG_PATH "$ENV_FILE")"; CFG_PATH="${CFG_PATH:-/root/.cross-seed/config.js}"
  LOGS_DIR="$(read_env_value CROSS_SEED_LOGS_DIR "$ENV_FILE")"; LOGS_DIR="${LOGS_DIR:-/root/.cross-seed/logs}"

  if looks_placeholder "$API_KEY"; then fail "CROSS_SEED_API_KEY is missing or placeholder"; else pass "CROSS_SEED_API_KEY is set"; fi
  if looks_placeholder "$UI_PASS"; then warn "CROSS_SEED_UI_PASSWORD looks like a placeholder"; else pass "CROSS_SEED_UI_PASSWORD is set"; fi
  if looks_placeholder "$UI_SECRET"; then warn "CROSS_SEED_UI_SESSION_SECRET looks like a placeholder"; else pass "CROSS_SEED_UI_SESSION_SECRET is set"; fi
  note "UI username: $UI_USER"
  note "Target cross-seed API: http://$CS_HOST:$CS_PORT"
  note "CS-GUI listen port: $UI_PORT"

  if [ -f "$CFG_PATH" ]; then
    pass "Config file exists: $CFG_PATH"
    if [ "$CS_HOST" = "127.0.0.1" ] || [ "$CS_HOST" = "localhost" ]; then
      if grep -Eq '^[[:space:]]*host[[:space:]]*:[[:space:]]*.*0\.0\.0\.0' "$CFG_PATH"; then
        warn "cross-seed config appears to bind host 0.0.0.0 while CS-GUI targets localhost; set cross-seed config host to 127.0.0.1 unless you intentionally need remote API access"
      fi
    fi
  else
    fail "Config file missing: $CFG_PATH"
  fi

  [ -d "$LOGS_DIR" ] && pass "Logs directory exists: $LOGS_DIR" || fail "Logs directory missing: $LOGS_DIR"

  if command -v curl >/dev/null 2>&1 && ! looks_placeholder "$API_KEY"; then
    code=$(curl -sS -o /tmp/cs_gui_doctor_ping.json -w '%{http_code}' --max-time 5 -H "X-Api-Key: $API_KEY" "http://$CS_HOST:$CS_PORT/api/ping" || true)
    if [ "$code" = "200" ]; then
      pass "cross-seed API /api/ping reachable"
    elif [ -n "$code" ] && [ "$code" != "000" ]; then
      fail "cross-seed API /api/ping returned HTTP $code"
    else
      fail "cross-seed API /api/ping not reachable"
    fi
  else
    warn "curl missing or API key placeholder; skipped live API check"
  fi
fi

if npm run check >/tmp/cs_gui_doctor_check.log 2>&1; then
  pass "npm run check passed"
else
  fail "npm run check failed (see /tmp/cs_gui_doctor_check.log)"
fi

if command -v systemctl >/dev/null 2>&1; then
  load_state=$(systemctl show -p LoadState --value cross-seed-ui.service 2>/dev/null || true)
  if [ "$load_state" = "loaded" ]; then
    state=$(systemctl is-active cross-seed-ui.service || true)
    if [ "$state" = "active" ]; then
      pass "cross-seed-ui.service is active"
    else
      warn "cross-seed-ui.service is $state"
    fi
  else
    warn "cross-seed-ui.service not installed"
  fi
fi

printf '\nSummary: %s fail, %s warn\n' "$FAILS" "$WARNS"
if [ "$FAILS" -gt 0 ]; then
  exit 1
fi
