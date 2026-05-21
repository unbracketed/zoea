#!/usr/bin/env bash
# Clone (or update) all Zoea child repos and run per-repo bootstrap.
# Idempotent: re-running pulls latest main instead of failing.
#
# Usage:
#   scripts/install.sh              # clone/update + bootstrap
#   scripts/install.sh --no-bootstrap # just clone/update
#   scripts/install.sh --clone-only   # alias for --no-bootstrap

set -euo pipefail

# Repo list. Order matters only insofar as later bootstrap steps may depend
# on earlier ones (zoea-tools' `pi install` wants zoea-tools already cloned).
# Each entry: "<dir>:<git-url>"
REPOS=(
  "zoea-server:https://github.com/unbracketed/zoea-server.git"
  "zoea-core:https://github.com/unbracketed/zoea-core.git"
  "zoea-tools:https://github.com/unbracketed/zoea-tools.git"
  "zoea-web-ui:https://github.com/unbracketed/zoea-web-ui.git"
  "zoea-deploy:https://github.com/unbracketed/zoea-deploy.git"
  # Optional
  "gateway-tui-client:https://github.com/unbracketed/gateway-tui-client.git"
)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BOOTSTRAP=1
for arg in "$@"; do
  case "$arg" in
    --no-bootstrap|--clone-only) BOOTSTRAP=0 ;;
    -h|--help)
      sed -n '2,9p' "$0"
      exit 0
      ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

log() { printf "\033[1;34m[install]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[install]\033[0m %s\n" "$*" >&2; }

clone_or_update() {
  local dir="$1" url="$2"
  if [ -d "$dir/.git" ]; then
    log "updating $dir"
    git -C "$dir" pull --ff-only --rebase=false
  elif [ -e "$dir" ]; then
    warn "$dir exists but is not a git repo — skipping"
    return 1
  else
    log "cloning $dir"
    git clone "$url" "$dir"
  fi
}

bootstrap_zoea_server() {
  command -v go >/dev/null || { warn "go not found, skipping zoea-server bootstrap"; return; }
  log "zoea-server: go mod download"
  (cd zoea-server && go mod download)
}

bootstrap_zoea_core() {
  command -v uv >/dev/null || { warn "uv not found, skipping zoea-core bootstrap"; return; }
  log "zoea-core: uv sync"
  (cd zoea-core && uv sync)
}

bootstrap_zoea_tools() {
  command -v npm >/dev/null || { warn "npm not found, skipping zoea-tools bootstrap"; return; }
  log "zoea-tools: npm install"
  (cd zoea-tools && npm install)
  if command -v pi >/dev/null; then
    log "zoea-tools: pi install"
    (cd "$ROOT" && pi install ./zoea-tools) || warn "pi install failed (continuing)"
  else
    warn "pi not found, skipping 'pi install ./zoea-tools'"
  fi
}

bootstrap_zoea_web_ui() {
  command -v npm >/dev/null || { warn "npm not found, skipping zoea-web-ui bootstrap"; return; }
  log "zoea-web-ui: npm install"
  (cd zoea-web-ui && npm install)
}

bootstrap_zoea_deploy() {
  command -v uv >/dev/null || { warn "uv not found, skipping zoea-deploy bootstrap"; return; }
  log "zoea-deploy: uv sync"
  (cd zoea-deploy && uv sync)
}

bootstrap_gateway_tui_client() {
  command -v go >/dev/null || { warn "go not found, skipping gateway-tui-client bootstrap"; return; }
  log "gateway-tui-client: go mod download"
  (cd gateway-tui-client && go mod download)
}

for entry in "${REPOS[@]}"; do
  dir="${entry%%:*}"
  url="${entry#*:}"
  clone_or_update "$dir" "$url" || true
done

if [ "$BOOTSTRAP" -eq 1 ]; then
  bootstrap_zoea_server
  bootstrap_zoea_core
  bootstrap_zoea_tools
  bootstrap_zoea_web_ui
  bootstrap_zoea_deploy
  bootstrap_gateway_tui_client
fi

log "done"
if [ ! -f process-compose.yaml ] && [ -f process-compose.yaml.example ]; then
  log "next: cp process-compose.yaml.example process-compose.yaml && edit, then run process-compose"
fi
