#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -n "${XDG_DATA_HOME:-}" ]]; then
  DATA_PATH="$XDG_DATA_HOME/portainer-ce/data"
else
  DATA_PATH="$HOME/.local/share/portainer-ce/data"
fi
ASSETS_PATH="$PROJECT_ROOT/dist"
BIND=":9000"
BIND_HTTPS=":9443"
TUNNEL_PORT="8000"
HOST_URL=""
BUILD=false
ENABLE_SETUP_TOKEN=false
EXTRA_ARGS=()

log_info() {
  printf '[local-server] %s\n' "$1"
}

usage() {
  cat <<'EOF'
Usage:
  dev/run_local_server.sh [options] [-- extra portainer args]

Options:
  --data PATH              Data directory. Default: ./data
  --assets PATH            Assets directory. Default: ./dist
  --bind ADDR              HTTP bind address. Default: :9000
  --bind-https ADDR        HTTPS bind address. Default: :9443
  --tunnel-port PORT       Edge tunnel port. Default: 8000
  --host URL               Docker/Kubernetes environment URL, for example unix:///var/run/docker.sock
  --build                  Build ./dist/portainer first, then run it
  --enable-setup-token     Do not pass --no-setup-token
  -h, --help               Show this help

Examples:
  dev/run_local_server.sh
  dev/run_local_server.sh --host unix:///var/run/docker.sock
  dev/run_local_server.sh --build
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --data)
      DATA_PATH="$2"
      shift 2
      ;;
    --assets)
      ASSETS_PATH="$2"
      shift 2
      ;;
    --bind)
      BIND="$2"
      shift 2
      ;;
    --bind-https)
      BIND_HTTPS="$2"
      shift 2
      ;;
    --tunnel-port)
      TUNNEL_PORT="$2"
      shift 2
      ;;
    --host)
      HOST_URL="$2"
      shift 2
      ;;
    --build)
      BUILD=true
      shift
      ;;
    --enable-setup-token)
      ENABLE_SETUP_TOKEN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      EXTRA_ARGS+=("$@")
      break
      ;;
    *)
      EXTRA_ARGS+=("$1")
      shift
      ;;
  esac
done

log_info "Preparing local Portainer server environment..."
mkdir -p "$DATA_PATH" "$ASSETS_PATH/public"

SERVER_ARGS=(
  "--data" "$DATA_PATH"
  "--assets" "$ASSETS_PATH"
  "--bind" "$BIND"
  "--bind-https" "$BIND_HTTPS"
  "--tunnel-port" "$TUNNEL_PORT"
)

if [[ "$ENABLE_SETUP_TOKEN" == false ]]; then
  SERVER_ARGS+=("--no-setup-token")
fi

if [[ -n "$HOST_URL" ]]; then
  SERVER_ARGS+=("--host" "$HOST_URL")
fi

if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
  SERVER_ARGS+=("${EXTRA_ARGS[@]}")
fi

log_info "Project root: $PROJECT_ROOT"
log_info "Data path: $DATA_PATH"
log_info "Assets path: $ASSETS_PATH"
log_info "HTTP bind address: $BIND"
log_info "HTTPS bind address: $BIND_HTTPS"
log_info "Tunnel port: $TUNNEL_PORT"
log_info "CSP environment value: false"
log_info "Build before start: $BUILD"
log_info "Setup token enabled: $ENABLE_SETUP_TOKEN"

if [[ -n "$HOST_URL" ]]; then
  log_info "Environment host URL: $HOST_URL"
else
  log_info "Environment host URL: not configured"
fi

if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
  log_info "Extra Portainer arguments: ${EXTRA_ARGS[*]}"
fi

cd "$PROJECT_ROOT"
export CSP=false

if [[ "$BUILD" == true ]]; then
  mkdir -p "$PROJECT_ROOT/dist"
  log_info "Building Portainer server binary..."
  go build -o "$PROJECT_ROOT/dist/portainer" ./api/cmd/portainer
  log_info "Starting Portainer server from binary: $PROJECT_ROOT/dist/portainer"
  "$PROJECT_ROOT/dist/portainer" "${SERVER_ARGS[@]}"
else
  log_info "Starting Portainer server with go run..."
  go run ./api/cmd/portainer "${SERVER_ARGS[@]}"
fi
