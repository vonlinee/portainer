#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INVOCATION_DIR="$(pwd)"

INSTALL_DIR="$INVOCATION_DIR"
PACKAGE_DIR=""
DATA_DIR=""
LOGS_DIR=""
BIND=":9000"
BIND_HTTPS=":9443"
TUNNEL_PORT="8000"
HOST_URL=""
ADMIN_PASSWORD_FILE=""
ADMIN_PASSWORD_HASH=""
ENABLE_SETUP_TOKEN="false"
KEEP_BUILD_WORK_DIR="false"
EXTRA_ARGS=()

log() {
  printf '[deploy-embedded-assets] %s\n' "$1"
}

resolve_invocation_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s\n' "$INVOCATION_DIR/$1" ;;
  esac
}

normalize_path() {
  (cd "$1" 2>/dev/null && pwd) || printf '%s\n' "$1"
}

assert_install_dir_safe() {
  local install_dir
  local project_root
  install_dir="$(normalize_path "$1")"
  project_root="$(normalize_path "$PROJECT_ROOT")"

  if [[ "$install_dir" == "$project_root" ]]; then
    printf 'Install directory cannot be the source project root: %s\n' "$1" >&2
    printf 'Choose a deployment directory, for example --install-dir ../portainer-runtime, or run this script from the desired install directory.\n' >&2
    exit 1
  fi
}

usage() {
  cat <<'EOF'
Usage:
  build/standalone/deploy-embedded-assets.sh [options] [-- extra portainer args]

Options:
  --package-dir PATH       Packaged artifact directory. Default: <install-dir>/package
  --install-dir PATH       Installation directory. Default: current directory
  --data-dir PATH          Portainer data directory. Default: <install-dir>/data
  --logs-dir PATH          Logs directory created by the script. Default: <install-dir>/logs
  --env VALUE              Webpack environment for packaging. Default: production
  --platform VALUE         Go target OS for packaging. Default: linux
  --arch VALUE             Go target arch for packaging. Default: amd64
  --skip-go-get VALUE      Skip go get during server build. Default: true
  --bind ADDR              HTTP bind address. Default: :9000
  --bind-https ADDR        HTTPS bind address. Default: :9443
  --tunnel-port PORT       Edge tunnel port. Default: 8000
  --host URL               Initial environment URL. Not configured by default
  --admin-password-file    Plain-text initial admin password file
  --admin-password-hash    Hashed initial admin password
  --enable-setup-token     Keep setup token enabled
  --keep-build-work-dir    Keep dist/embedded-build-work after successful packaging
  -h, --help               Show this help
EOF
}

generate_password() {
  dd if=/dev/urandom bs=24 count=1 2>/dev/null | base64 | tr -d '\n'
}

ENVIRONMENT="production"
PLATFORM="linux"
ARCH="amd64"
SKIP_GO_GET="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --package-dir)
      PACKAGE_DIR="$(resolve_invocation_path "$2")"
      shift 2
      ;;
    --install-dir)
      INSTALL_DIR="$(resolve_invocation_path "$2")"
      shift 2
      ;;
    --data-dir)
      DATA_DIR="$(resolve_invocation_path "$2")"
      shift 2
      ;;
    --logs-dir)
      LOGS_DIR="$(resolve_invocation_path "$2")"
      shift 2
      ;;
    --env)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --platform)
      PLATFORM="$2"
      shift 2
      ;;
    --arch)
      ARCH="$2"
      shift 2
      ;;
    --skip-go-get)
      SKIP_GO_GET="$2"
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
    --admin-password-file)
      ADMIN_PASSWORD_FILE="$2"
      shift 2
      ;;
    --admin-password-hash)
      ADMIN_PASSWORD_HASH="$2"
      shift 2
      ;;
    --enable-setup-token)
      ENABLE_SETUP_TOKEN="true"
      shift
      ;;
    --keep-build-work-dir)
      KEEP_BUILD_WORK_DIR="true"
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
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -n "$ADMIN_PASSWORD_FILE" && -n "$ADMIN_PASSWORD_HASH" ]]; then
  printf 'Use only one of --admin-password-file or --admin-password-hash.\n' >&2
  exit 1
fi

if [[ -z "$PACKAGE_DIR" ]]; then
  PACKAGE_DIR="$INSTALL_DIR/package"
fi
if [[ -z "$DATA_DIR" ]]; then
  DATA_DIR="$INSTALL_DIR/data"
fi
if [[ -z "$LOGS_DIR" ]]; then
  LOGS_DIR="$INSTALL_DIR/logs"
fi

assert_install_dir_safe "$INSTALL_DIR"

expected_binary_name="portainer"
if [[ "$PLATFORM" == "windows" ]]; then
  expected_binary_name="portainer.exe"
fi

if [[ -f "$INSTALL_DIR/$expected_binary_name" ]]; then
  log "Install directory already contains $INSTALL_DIR/$expected_binary_name."
  log "Stop any running process using that binary before redeploying, or pass --install-dir to use a different directory."
fi

log "Packaging embedded-assets artifact..."
package_args=(
  --env "$ENVIRONMENT"
  --platform "$PLATFORM"
  --arch "$ARCH"
  --output-dir "$PACKAGE_DIR"
  --skip-go-get "$SKIP_GO_GET"
)
if [[ "$KEEP_BUILD_WORK_DIR" == "true" ]]; then
  package_args+=(--keep-build-work-dir)
fi
"$SCRIPT_DIR/package-embedded-assets.sh" "${package_args[@]}"

binary_name="portainer"
if [[ -f "$PACKAGE_DIR/portainer.exe" ]]; then
  binary_name="portainer.exe"
fi

if [[ ! -f "$PACKAGE_DIR/$binary_name" ]]; then
  printf 'Package binary not found: %s\n' "$PACKAGE_DIR/$binary_name" >&2
  printf 'Packaging did not produce the expected binary.\n' >&2
  exit 1
fi

log "Installing package to: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR" "$DATA_DIR" "$LOGS_DIR"
cp "$PACKAGE_DIR/$binary_name" "$INSTALL_DIR/$binary_name"
rm -rf "$INSTALL_DIR/mustache-templates"
if [[ -d "$PACKAGE_DIR/mustache-templates" ]]; then
  cp -R "$PACKAGE_DIR/mustache-templates" "$INSTALL_DIR/mustache-templates"
fi

if [[ -z "$ADMIN_PASSWORD_FILE" && -z "$ADMIN_PASSWORD_HASH" && "$ENABLE_SETUP_TOKEN" != "true" ]]; then
  ADMIN_PASSWORD_FILE="$INSTALL_DIR/admin-password.txt"
  if [[ ! -f "$ADMIN_PASSWORD_FILE" ]]; then
    (umask 077 && generate_password >"$ADMIN_PASSWORD_FILE")
    log "Generated initial admin password file: $ADMIN_PASSWORD_FILE"
  else
    log "Using existing initial admin password file: $ADMIN_PASSWORD_FILE"
  fi
  log "Initial administrator username: admin"
fi

if [[ -n "$ADMIN_PASSWORD_FILE" && ! -f "$ADMIN_PASSWORD_FILE" ]]; then
  printf 'Admin password file not found: %s\n' "$ADMIN_PASSWORD_FILE" >&2
  exit 1
fi

chmod +x "$INSTALL_DIR/$binary_name" 2>/dev/null || true

SERVER_ARGS=(
  "--assets-mode" "embedded"
  "--assets" "$INSTALL_DIR"
  "--data" "$DATA_DIR"
  "--bind" "$BIND"
  "--bind-https" "$BIND_HTTPS"
  "--tunnel-port" "$TUNNEL_PORT"
)

if [[ -n "$ADMIN_PASSWORD_FILE" ]]; then
  SERVER_ARGS+=("--admin-password-file" "$ADMIN_PASSWORD_FILE")
elif [[ -n "$ADMIN_PASSWORD_HASH" ]]; then
  SERVER_ARGS+=("--admin-password" "$ADMIN_PASSWORD_HASH")
elif [[ "$ENABLE_SETUP_TOKEN" != "true" ]]; then
  SERVER_ARGS+=("--no-setup-token")
fi

if [[ -n "$HOST_URL" ]]; then
  SERVER_ARGS+=("--host" "$HOST_URL")
fi

SERVER_ARGS+=("${EXTRA_ARGS[@]}")

log "Starting Portainer embedded-assets deployment..."
log "HTTP bind address: $BIND"
log "HTTPS bind address: $BIND_HTTPS"
log "Logs directory: $LOGS_DIR"
exec "$INSTALL_DIR/$binary_name" "${SERVER_ARGS[@]}"
