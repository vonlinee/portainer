#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PLATFORM="${PLATFORM:-linux}"
ARCH="${ARCH:-amd64}"
SKIP_GO_GET="${SKIP_GO_GET:-true}"

log() {
  printf '[build-server] %s\n' "$1"
}

usage() {
  cat <<'EOF'
Usage:
  build/standalone/build-server.sh [options]

Options:
  --project-root PATH  Project root to build. Default: repository root

Environment variables:
  PLATFORM      Go target OS. Default: linux
  ARCH          Go target arch. Default: amd64
  SKIP_GO_GET   Skip go get during server build. Default: true
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root)
      PROJECT_ROOT="$2"
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

cd "$PROJECT_ROOT"

log "Building Portainer server for $PLATFORM/$ARCH..."
SKIP_GO_GET="$SKIP_GO_GET" ./build/build_binary.sh "$PLATFORM" "$ARCH"
