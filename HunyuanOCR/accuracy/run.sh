#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG_NAME=${1:?usage: BENCH_ROOT=/path/to/HunyuanOCR-Bench $0 CONFIG.env}
BENCH_ROOT=${BENCH_ROOT:?set BENCH_ROOT to the pinned HunyuanOCR-Bench checkout}
PYTHON_BIN=${PYTHON_BIN:-python3}
EXPECTED_BENCH_COMMIT=1e320ce11a9cfa29f0ffa0f735a103deb1304d43

if [[ "$CONFIG_NAME" == */* ]]; then
    CONFIG=$CONFIG_NAME
else
    CONFIG=$ROOT/configs/$CONFIG_NAME
fi
[[ -f "$CONFIG" ]] || { printf 'ERROR: configuration not found: %s\n' "$CONFIG" >&2; exit 1; }

# Repository-controlled configuration files contain only shell assignments.
source "$CONFIG"
: "${MACHINE_PROFILE:?missing MACHINE_PROFILE in $CONFIG}"
: "${HOST:?missing HOST in $CONFIG}"
: "${PORTS:?missing PORTS in $CONFIG}"
: "${CONCURRENCY:?missing CONCURRENCY in $CONFIG}"
: "${RESULT_NAME:?missing RESULT_NAME in $CONFIG}"

for command in git curl jq docker python3; do
    command -v "$command" >/dev/null \
        || { printf 'ERROR: missing command: %s\n' "$command" >&2; exit 1; }
done
if [[ "$PYTHON_BIN" == */* ]]; then
    [[ -x "$PYTHON_BIN" ]] \
        || { printf 'ERROR: PYTHON_BIN is not executable: %s\n' "$PYTHON_BIN" >&2; exit 1; }
else
    command -v "$PYTHON_BIN" >/dev/null \
        || { printf 'ERROR: PYTHON_BIN not found: %s\n' "$PYTHON_BIN" >&2; exit 1; }
fi
[[ "$CONCURRENCY" =~ ^[1-9][0-9]*$ ]] \
    || { printf 'ERROR: invalid CONCURRENCY: %s\n' "$CONCURRENCY" >&2; exit 1; }

BENCH_ROOT=$(cd "$BENCH_ROOT" && pwd)
ACTUAL_COMMIT=$(git -C "$BENCH_ROOT" rev-parse HEAD)
[[ "$ACTUAL_COMMIT" == "$EXPECTED_BENCH_COMMIT" ]] || {
    printf 'ERROR: expected HunyuanOCR-Bench %s, found %s\n' \
        "$EXPECTED_BENCH_COMMIT" "$ACTUAL_COMMIT" >&2
    exit 1
}
[[ -z "$(git -C "$BENCH_ROOT" status --porcelain --untracked-files=no)" ]] || {
    printf 'ERROR: HunyuanOCR-Bench tracked files are modified\n' >&2
    exit 1
}

ASSETS_DIR=${ASSETS_DIR:-$BENCH_ROOT/assets}
WORK_DIR=${WORK_DIR:-$BENCH_ROOT/work}
MACHINE=$BENCH_ROOT/$MACHINE_PROFILE
MODEL=tencent/HunyuanOCR
RUN_ID=${RUN_ID:-accuracy-${RESULT_NAME}-$(date -u +%Y%m%dT%H%M%SZ)}
RUN_DIR=$WORK_DIR/$RUN_ID
PREDICTIONS=$RUN_DIR/predictions

[[ -f "$MACHINE" ]] \
    || { printf 'ERROR: machine profile not found: %s\n' "$MACHINE" >&2; exit 1; }
[[ ! -e "$RUN_DIR" ]] \
    || { printf 'ERROR: run directory already exists: %s\n' "$RUN_DIR" >&2; exit 1; }
mkdir -p "$RUN_DIR"

PYTHONPATH="$BENCH_ROOT/src" python3 -m hunyuanocr_bench.cli verify-assets \
    --assets-dir "$ASSETS_DIR" \
    --output "$RUN_DIR/assets-verification.json"

IFS=',' read -r -a accuracy_ports <<< "$PORTS"
for port in "${accuracy_ports[@]}"; do
    body=$(curl --noproxy '*' -fsS --max-time 10 "http://$HOST:$port/v1/models")
    jq -e --arg model "$MODEL" 'any(.data[]?; .id == $model)' <<< "$body" >/dev/null \
        || { printf 'ERROR: model %s not served on port %s\n' "$MODEL" "$port" >&2; exit 1; }
done
mkdir -p "$PREDICTIONS"

PYTHONDONTWRITEBYTECODE=1 "$PYTHON_BIN" \
    "$ASSETS_DIR/src/HunyuanOCR/inference/vLLM/batch_infer.py" \
    --image-dir "$ASSETS_DIR/data/OmniDocBench_v1_6/images" \
    --out-dir "$PREDICTIONS" \
    --host "$HOST" \
    --ports "$PORTS" \
    --model "$MODEL" \
    --task-type doc_parse \
    --max-tokens 32768 \
    --repetition-penalty 1.08 \
    --concurrency "$CONCURRENCY"

PYTHONPATH="$BENCH_ROOT/src" python3 -m hunyuanocr_bench.cli verify-predictions \
    --gt "$ASSETS_DIR/data/OmniDocBench_v1_6/OmniDocBench.json" \
    --prediction-dir "$PREDICTIONS" \
    --output "$RUN_DIR/prediction-verification.json"

ASSETS_DIR="$ASSETS_DIR" WORK_DIR="$WORK_DIR" \
    "$BENCH_ROOT/scripts/run-evaluation.sh" "$RUN_ID"
SUMMARY=$(<"$RUN_DIR/evaluator-summary.path")
PYTHONPATH="$BENCH_ROOT/src" python3 -m hunyuanocr_bench.cli accuracy-report \
    --machine "$MACHINE" \
    --source "$SUMMARY" \
    --output "$RUN_DIR/accuracy.json"

printf 'PASS: accuracy report written to %s\n' "$RUN_DIR/accuracy.json"
cat "$RUN_DIR/accuracy.json"
