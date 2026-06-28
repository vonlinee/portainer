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
BUILD_WORK_DIR="$PROJECT_ROOT/dist/embedded-build-work"
KEEP_BUILD_WORK_DIR="false"

log() {
  printf '[package-embedded-assets] %s\n' "$1"
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
  build/standalone/package-embedded-assets.sh [options]

Options:
  --env VALUE              Webpack environment. Default: production
  --platform VALUE         Go target OS. Default: linux
  --arch VALUE             Go target arch. Default: amd64
  --output-dir PATH        Package output directory. Default: ./package
  --skip-go-get VALUE      Skip go get during server build. Default: true
  --keep-build-work-dir    Keep dist/embedded-build-work after successful packaging
  -h, --help               Show this help
EOF
}

cleanup_build_work_dir() {
  local exit_code=$?
  if [[ "$exit_code" -eq 0 && "$KEEP_BUILD_WORK_DIR" != "true" && -d "$BUILD_WORK_DIR" ]]; then
    log "Cleaning temporary embedded build workspace: $BUILD_WORK_DIR"
    rm -rf "$BUILD_WORK_DIR"
  elif [[ "$exit_code" -ne 0 && -d "$BUILD_WORK_DIR" ]]; then
    log "Keeping temporary embedded build workspace for troubleshooting: $BUILD_WORK_DIR"
  fi
}
trap cleanup_build_work_dir EXIT

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
    --keep-build-work-dir)
      KEEP_BUILD_WORK_DIR="true"
      shift
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

log "Preparing temporary embedded build workspace..."
rm -rf "$BUILD_WORK_DIR"
mkdir -p "$BUILD_WORK_DIR"
cp -R "$PROJECT_ROOT/api" "$BUILD_WORK_DIR/api"
cp -R "$PROJECT_ROOT/pkg" "$BUILD_WORK_DIR/pkg"
cp -R "$PROJECT_ROOT/mustache-templates" "$BUILD_WORK_DIR/mustache-templates"
cp "$PROJECT_ROOT/go.mod" "$BUILD_WORK_DIR/go.mod"
cp "$PROJECT_ROOT/go.sum" "$BUILD_WORK_DIR/go.sum"

rm -rf "$BUILD_WORK_DIR/api/embedded/public"
mkdir -p "$BUILD_WORK_DIR/api/embedded/public"
cp -R "$PROJECT_ROOT/dist/public/." "$BUILD_WORK_DIR/api/embedded/public/"

log "Building embedded server binary..."
(
  cd "$BUILD_WORK_DIR"
  SKIP_GO_GET="$SKIP_GO_GET" PLATFORM="$PLATFORM" ARCH="$ARCH" "$SCRIPT_DIR/build-server.sh" --project-root "$BUILD_WORK_DIR"
)

log "Creating package directory: $OUTPUT_DIR"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

cp "$BUILD_WORK_DIR/dist/$binary_name" "$OUTPUT_DIR/$binary_name"
cp -R "$BUILD_WORK_DIR/dist/mustache-templates" "$OUTPUT_DIR/mustache-templates"

cat >"$OUTPUT_DIR/README.txt" <<EOF
Portainer embedded-assets standalone package

Contents:
  $binary_name
  mustache-templates/

Frontend assets are embedded in the binary.

Run:
  ./$binary_name --assets-mode embedded --data ./data
EOF

log "Package complete: $OUTPUT_DIR"
