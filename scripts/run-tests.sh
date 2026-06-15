#!/bin/bash
# scripts/run-tests.sh
# Convenience script to build and run Prometheus tests in Docker
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

IMAGE_NAME="${IMAGE_NAME:-prometheus-tests}"
N="${N:-10}"
DOCKER_EXTRA_ARGS=""

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Run Prometheus tests inside a Docker container with lua5.1 and luau.

Options:
  -n N          Number of iterations per test/preset (default: 10)
  -c FILE       Use custom config file instead of built-in presets
  -b            Build the Docker image (rebuilds if already exists)
  -v            Verbose output (show baseline captures and more detail)
  --pass-runners  Show baseline pass per runner
  --no-cache    Force Docker build with --no-cache
  --ci          Run in CI mode (errors surface more aggressively)
  -h, --help    Show this help

Runtimes available in the container:
  lua5.1, luau (built from source)

EOF
    exit 0
}

BUILD=0
CUSTOM_CONFIG=""
CI_FLAG=""
VERBOSE_FLAG=""
PASS_RUNNERS_FLAG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n)
            N="$2"
            shift 2
            ;;
        -c)
            CUSTOM_CONFIG="$2"
            shift 2
            ;;
        -b)
            BUILD=1
            shift
            ;;
        -v)
            VERBOSE_FLAG="--verbose"
            shift
            ;;
        --pass-runners)
            PASS_RUNNERS_FLAG="--pass-runners"
            shift
            ;;
        --no-cache)
            DOCKER_EXTRA_ARGS="$DOCKER_EXTRA_ARGS --no-cache"
            shift
            ;;
        --ci)
            CI_FLAG="--CI"
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Check if image exists; if not, build
if [[ $BUILD -eq 1 ]] || ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
    echo "=== Building Docker image '$IMAGE_NAME' ==="
    docker build $DOCKER_EXTRA_ARGS -t "$IMAGE_NAME" "$PROJECT_DIR"
    echo ""
fi

# Prepare config mount if custom config is specified
CONFIG_MOUNT=""
RUNNER_ARGS="--iterations=$N $CI_FLAG $VERBOSE_FLAG $PASS_RUNNERS_FLAG"
if [[ -n "$CUSTOM_CONFIG" ]]; then
    CONFIG_ABS="$(cd "$(dirname "$CUSTOM_CONFIG")" && pwd)/$(basename "$CUSTOM_CONFIG")"
    CONFIG_CONTAINER="/tmp/prometheus_custom_config.lua"
    CONFIG_MOUNT="-v $CONFIG_ABS:$CONFIG_CONTAINER:ro"
    RUNNER_ARGS="$RUNNER_ARGS --config=$CONFIG_CONTAINER"
fi

echo "=== Running Prometheus Tests ==="
echo "Iterations: $N"
[[ -n "$CUSTOM_CONFIG" ]] && echo "Custom config: $CUSTOM_CONFIG"

docker run --rm \
    $CONFIG_MOUNT \
    "$IMAGE_NAME" \
    $RUNNER_ARGS
