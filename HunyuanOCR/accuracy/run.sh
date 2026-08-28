#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROFILE_ID=${1:?usage: $0 PROFILE_ID}
PROFILE=$ROOT/profiles/${PROFILE_ID%.json}.json
PYTHON_BIN=${PYTHON_BIN:-python3}
[[ -f "$PROFILE" ]] || { printf 'ERROR: profile not found: %s\n' "$PROFILE" >&2; exit 1; }

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
HOST=$(jq -er .accuracy.host "$PROFILE")
PORTS=$(jq -er '.accuracy.ports | join(",")' "$PROFILE")
CONCURRENCY=$(jq -er .accuracy.concurrency "$PROFILE")
MODEL=$(jq -er .runtime.served_model_name "$PROFILE")
[[ "$CONCURRENCY" =~ ^[1-9][0-9]*$ ]] \
    || { printf 'ERROR: invalid CONCURRENCY: %s\n' "$CONCURRENCY" >&2; exit 1; }

ASSETS_DIR=${ASSETS_DIR:-$ROOT/assets}
WORK_DIR=${WORK_DIR:-$ROOT/work}
RUN_ID=${RUN_ID:-accuracy-${PROFILE_ID%.json}-$(date -u +%Y%m%dT%H%M%SZ)}
RUN_DIR=$WORK_DIR/$RUN_ID
PREDICTIONS=$RUN_DIR/predictions

[[ ! -e "$RUN_DIR" ]] \
    || { printf 'ERROR: run directory already exists: %s\n' "$RUN_DIR" >&2; exit 1; }
mkdir -p "$RUN_DIR"

python3 "$ROOT/scripts/accuracy_tool.py" verify-assets \
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

python3 "$ROOT/scripts/accuracy_tool.py" verify-predictions \
    --gt "$ASSETS_DIR/data/OmniDocBench_v1_6/OmniDocBench.json" \
    --prediction-dir "$PREDICTIONS" \
    --output "$RUN_DIR/prediction-verification.json"

ASSETS_DIR="$ASSETS_DIR" WORK_DIR="$WORK_DIR" \
    "$ROOT/scripts/run_evaluation.sh" "$RUN_ID"
SUMMARY=$(<"$RUN_DIR/evaluator-summary.path")
python3 "$ROOT/scripts/accuracy_tool.py" accuracy-report \
    --profile "$PROFILE" \
    --source "$SUMMARY" \
    --output "$RUN_DIR/accuracy.json"

printf 'PASS: accuracy report written to %s\n' "$RUN_DIR/accuracy.json"
cat "$RUN_DIR/accuracy.json"
