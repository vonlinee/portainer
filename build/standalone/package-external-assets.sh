#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INVOCATION_DIR="$(pwd)"

ENVIRONMENT="production"
PLATFORM="linux"
ARCH="amd64"
OUTPUT_DIR="$INVOCATION_DIR/package"
SKIP_GO_GET="true"

log() {
  printf '[package-external-assets] %s\n' "$1"
}

resolve_invocation_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s\n' "$INVOCATION_DIR/$1" ;;
  esac
}

usage() {
  cat <<'EOF'
Usage:
  build/standalone/package-external-assets.sh [options]

Options:
  --env VALUE              Webpack environment. Default: production
  --platform VALUE         Go target OS. Default: linux
  --arch VALUE             Go target arch. Default: amd64
  --output-dir PATH        Package output directory. Default: ./package
  --skip-go-get VALUE      Skip go get during server build. Default: true
  -h, --help               Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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
    --output-dir)
      OUTPUT_DIR="$(resolve_invocation_path "$2")"
      shift 2
      ;;
    --skip-go-get)
      SKIP_GO_GET="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

binary_name="portainer"
if [[ "$PLATFORM" == "windows" ]]; then
  binary_name="portainer.exe"
fi

if [[ -f "$OUTPUT_DIR/$binary_name" ]]; then
  log "Package output already contains $OUTPUT_DIR/$binary_name."
  log "Stop any running process using that binary, or pass --output-dir to use a different package directory."
fi

cd "$PROJECT_ROOT"

log "Building frontend assets..."
CI="${CI:-true}" make build-client ENV="$ENVIRONMENT"

log "Building server binary..."
SKIP_GO_GET="$SKIP_GO_GET" PLATFORM="$PLATFORM" ARCH="$ARCH" "$SCRIPT_DIR/build-server.sh"

log "Creating package directory: $OUTPUT_DIR"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

cp "$PROJECT_ROOT/dist/$binary_name" "$OUTPUT_DIR/$binary_name"
cp -R "$PROJECT_ROOT/dist/public" "$OUTPUT_DIR/public"
cp -R "$PROJECT_ROOT/dist/mustache-templates" "$OUTPUT_DIR/mustache-templates"

cat >"$OUTPUT_DIR/README.txt" <<EOF
Portainer external-assets standalone package

Contents:
  $binary_name
  public/
  mustache-templates/

Run:
  ./$binary_name --assets . --data ./data
EOF

log "Package complete: $OUTPUT_DIR"
