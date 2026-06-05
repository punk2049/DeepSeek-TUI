#!/usr/bin/env bash
# run-pinchbench.sh — Run CodeWhale through PinchBench.
#
# PinchBench evaluates agent performance on real-world tasks. It normally
# targets OpenClaw, but this script adapts the workflow for CodeWhale by
# leveraging the OpenRouter-compatible model routing.
#
# Usage:
#   ./scripts/benchmarks/run-pinchbench.sh --help
#   ./scripts/benchmarks/run-pinchbench.sh --model deepseek/deepseek-chat
#
# Prerequisites:
#   - PinchBench cloned (or install via this script)
#   - Python 3.10+ with uv
#   - OPENROUTER_API_KEY or DEEPSEEK_API_KEY set
#   - A running OpenClaw instance (PinchBench's default runtime)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Defaults
MODEL="deepseek/deepseek-chat"
SUITE="all"
PINCHBENCH_DIR="${PINCHBENCH_DIR:-/tmp/pinchbench}"
RESULTS_DIR="./results/pinchbench"
INSTALL_PINCHBENCH=false
RUNS=1
JUDGE_MODEL=""
NO_UPLOAD=true
EXTRA_ARGS=()

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Run PinchBench benchmarks with CodeWhale-compatible model routing.

Options:
  --model MODEL           Model in provider/name format (default: deepseek/deepseek-chat)
  --suite SUITE           Task suite: all, automated-only, or comma-separated IDs (default: all)
  --runs N                Runs per task for averaging (default: 1)
  --judge MODEL           Judge model for LLM grading
  --pinchbench-dir DIR    PinchBench install directory (default: /tmp/pinchbench)
  --results-dir DIR       Local results directory (default: ./results/pinchbench)
  --install               Install/clone PinchBench before running
  --upload                Upload results to pinchbench.com leaderboard
  -- [EXTRA_ARGS...]      Additional arguments passed to PinchBench
  -h, --help              Show this help

Examples:
  # Basic run with DeepSeek
  $(basename "$0") --model deepseek/deepseek-chat

  # Install and run
  $(basename "$0") --install --model deepseek/deepseek-chat

  # Specific tasks only
  $(basename "$0") --suite task_calendar,task_stock --model deepseek/deepseek-chat
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --model) MODEL="$2"; shift 2 ;;
        --suite) SUITE="$2"; shift 2 ;;
        --runs) RUNS="$2"; shift 2 ;;
        --judge) JUDGE_MODEL="$2"; shift 2 ;;
        --pinchbench-dir) PINCHBENCH_DIR="$2"; shift 2 ;;
        --results-dir) RESULTS_DIR="$2"; shift 2 ;;
        --install) INSTALL_PINCHBENCH=true; shift ;;
        --upload) NO_UPLOAD=false; shift ;;
        --) shift; EXTRA_ARGS=("$@"); break ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
done

# Install PinchBench if requested
if [[ "$INSTALL_PINCHBENCH" == true || ! -d "$PINCHBENCH_DIR" ]]; then
    echo "Installing PinchBench to $PINCHBENCH_DIR ..."
    if [[ -d "$PINCHBENCH_DIR" ]]; then
        cd "$PINCHBENCH_DIR" && git pull
    else
        git clone https://github.com/pinchbench/skill.git "$PINCHBENCH_DIR"
    fi
    cd "$PINCHBENCH_DIR"
    uv venv .venv 2>/dev/null || true
    source .venv/bin/activate
    uv pip install -e .
fi

# Verify PinchBench is available
if [[ ! -d "$PINCHBENCH_DIR" ]]; then
    echo "Error: PinchBench not found at $PINCHBENCH_DIR" >&2
    echo "Run with --install to clone it automatically." >&2
    exit 1
fi

cd "$PINCHBENCH_DIR"

# Activate venv if it exists
if [[ -f ".venv/bin/activate" ]]; then
    source .venv/bin/activate
fi

mkdir -p "$RESULTS_DIR"

# Record metadata
METADATA_FILE="$RESULTS_DIR/run_metadata.json"
cat > "$METADATA_FILE" <<META
{
    "codewhale_version": "$(codewhale --version 2>/dev/null || echo unknown)",
    "git_commit": "$(cd "$REPO_ROOT" && git rev-parse HEAD 2>/dev/null || echo unknown)",
    "pinchbench_commit": "$(git rev-parse HEAD 2>/dev/null || echo unknown)",
    "model": "$MODEL",
    "suite": "$SUITE",
    "runs": $RUNS,
    "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "platform": "$(uname -s)/$(uname -m)"
}
META
echo "Run metadata: $METADATA_FILE"

# Build PinchBench command
PB_ARGS=("--model" "$MODEL" "--suite" "$SUITE" "--runs" "$RUNS" "--output-dir" "$RESULTS_DIR")

if [[ -n "$JUDGE_MODEL" ]]; then
    PB_ARGS+=("--judge" "$JUDGE_MODEL")
fi

if [[ "$NO_UPLOAD" == true ]]; then
    PB_ARGS+=("--no-upload")
fi

PB_ARGS+=("${EXTRA_ARGS[@]}")

echo "Running PinchBench..."
echo "  Model:  $MODEL"
echo "  Suite:  $SUITE"
echo "  Runs:   $RUNS"
echo "  Output: $RESULTS_DIR"
echo ""

./scripts/run.sh "${PB_ARGS[@]}"

echo ""
echo "Results written to $RESULTS_DIR"
