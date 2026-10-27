#!/bin/bash
# Build and run the complete Lua semantic suite in Docker.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGE_NAME="${IMAGE_NAME:-prometheus-tests}"
N="${N:-10}"
BUILD=0
CUSTOM_CONFIG=""
ARTIFACT_DIR="${ARTIFACT_DIR:-$PROJECT_DIR/test-results}"
BUILD_ARGS=()
RUNNER_ARGS=()
if [[ -n "${TEST_CA_BUNDLE:-}" ]]; then
    BUILD_ARGS+=(--secret "id=ca-bundle,src=$TEST_CA_BUNDLE")
fi

usage() {
    cat <<HELP
Usage: $0 [OPTIONS]

Run existing tests on lua5.1 and Luau, and adapted official tests on lua5.1.

Options:
  -n N              Iterations per test/preset (default: 10)
  -c FILE           Custom config instead of built-in presets
  -b                Build/rebuild the Docker image
  -v                Verbose baseline reporting
  --pass-runners    Show passing baselines
  --no-cache        Build without cached layers
  --ci              CI invocation (same failure policy)
  --suite NAME      all (default), existing, or upstream
  --case NAME       One case, e.g. lua51/closure.lua
  --preset NAME     One preset
  --runtime NAME    lua5.1 or luau (lua51 alias accepted)
  --seed N          First obfuscation seed (default: 1)
  --timeout N       Seconds per subprocess (default: 60)
  --baseline-only   Run originals without obfuscation
  --artifacts DIR   Host artifact directory (default: test-results)
  -h, --help        Show this help

All applicable cases/presets/iterations run even after failures. Logs and
failure artifacts persist in the host artifact directory. AntiTamper is
removed from presets, matching the existing suite's convention.
HELP
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|-c|--suite|--case|--preset|--runtime|--seed|--timeout|--artifacts)
            [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 2; }
            case "$1" in
                -n) N="$2" ;;
                -c) CUSTOM_CONFIG="$2" ;;
                --artifacts) ARTIFACT_DIR="$2" ;;
                *) RUNNER_ARGS+=("$1=$2") ;;
            esac
            shift 2 ;;
        -b) BUILD=1; shift ;;
        -v) RUNNER_ARGS+=(--verbose); shift ;;
        --pass-runners|--baseline-only) RUNNER_ARGS+=("$1"); shift ;;
        --no-cache) BUILD_ARGS+=(--no-cache); BUILD=1; shift ;;
        --ci) RUNNER_ARGS+=(--ci); shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [[ $BUILD -eq 1 ]] || ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
    docker build "${BUILD_ARGS[@]}" -t "$IMAGE_NAME" "$PROJECT_DIR"
fi

mkdir -p "$ARTIFACT_DIR"
ARTIFACT_ABS="$(cd "$ARTIFACT_DIR" && pwd)"
MOUNTS=(-v "$ARTIFACT_ABS:/artifacts")
RUNNER_ARGS+=("--iterations=$N" --artifacts=/artifacts)
if [[ -n "$CUSTOM_CONFIG" ]]; then
    CONFIG_ABS="$(cd "$(dirname "$CUSTOM_CONFIG")" && pwd)/$(basename "$CUSTOM_CONFIG")"
    MOUNTS+=(-v "$CONFIG_ABS:/tmp/prometheus_custom_config.lua:ro")
    RUNNER_ARGS+=(--config=/tmp/prometheus_custom_config.lua)
fi

echo "Running Prometheus tests ($N iterations); artifacts: $ARTIFACT_ABS"
# Running as the invoking user keeps mounted artifacts readable and writable.
docker run --rm --user "$(id -u):$(id -g)" "${MOUNTS[@]}" "$IMAGE_NAME" "${RUNNER_ARGS[@]}"
