#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PROTOCOL=$ROOT/protocol/accuracy-v1.json
RUN_ID=${1:?usage: run_evaluation.sh RUN_ID}
ASSETS_DIR=${ASSETS_DIR:-$ROOT/assets}
WORK_DIR=${WORK_DIR:-$ROOT/work}
PREDICTIONS=$WORK_DIR/$RUN_ID/predictions
OUTPUT=$WORK_DIR/$RUN_ID/evaluation
EVALUATOR_IMAGE=$(jq -er .evaluator.image "$PROTOCOL")
CONFIG_RELATIVE=$(jq -er .evaluator.config "$PROTOCOL")
CONFIG=$ROOT/$CONFIG_RELATIVE
DATA_REVISION=$(jq -er .dataset.revision "$PROTOCOL")
EVALUATOR_REVISION=$(jq -er .evaluator.revision "$PROTOCOL")

[[ "$(jq -r .status "$WORK_DIR/$RUN_ID/prediction-verification.json")" == PASS ]] \
    || { printf 'ERROR: prediction gate is not PASS\n' >&2; exit 1; }
[[ ! -e "$OUTPUT" ]] \
    || { printf 'ERROR: evaluation output already exists: %s\n' "$OUTPUT" >&2; exit 1; }
mkdir -p "$OUTPUT"

docker image inspect "$EVALUATOR_IMAGE" >/dev/null 2>&1 || docker pull "$EVALUATOR_IMAGE"
docker run --rm \
    --entrypoint bash \
    --ipc=host \
    --shm-size=8g \
    --user "$(id -u):$(id -g)" \
    -e HOME=/tmp/home \
    -v "$ASSETS_DIR/src/OmniDocBench:/source:ro" \
    -v "$ASSETS_DIR/data/OmniDocBench_v1_6:/benchmark_data:ro" \
    -v "$PREDICTIONS:/predictions:ro" \
    -v "$CONFIG:/benchmark_config.yaml:ro" \
    -v "$OUTPUT:/evaluation_output" \
    "$EVALUATOR_IMAGE" \
    -lc '
        mkdir -p "$HOME" /tmp/OmniDocBench
        cp -a /source/. /tmp/OmniDocBench/
        cd /tmp/OmniDocBench
        python tools/test_environment_and_smoke.py
        python pdf_validation.py --config /benchmark_config.yaml
        cp -a result/. /evaluation_output/
    ' | tee "$WORK_DIR/$RUN_ID/evaluation.log"

SUMMARY=$(find "$OUTPUT" -maxdepth 1 -type f -name '*_run_summary.json' -print -quit)
[[ -n "$SUMMARY" ]] \
    || { printf 'ERROR: complete evaluator run summary not found\n' >&2; exit 1; }

python3 - "$SUMMARY" "$WORK_DIR/$RUN_ID/evaluator-summary.json" \
    "$DATA_REVISION" "$EVALUATOR_REVISION" "$EVALUATOR_IMAGE" "$CONFIG" \
    "$ASSETS_DIR/data/OmniDocBench_v1_6/OmniDocBench.json" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

source, output, data_revision, evaluator_revision, image, config, gt = sys.argv[1:]

def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for chunk in iter(lambda: handle.read(8 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()

payload = json.loads(Path(source).read_text(encoding="utf-8"))
payload["benchmark_provenance"] = {
    "protocol_id": "hunyuanocr-1.5-omnidocbench-1.6-accuracy-v1",
    "dataset_revision": data_revision,
    "dataset_pages": 1651,
    "gt_sha256": sha256(gt),
    "evaluator_revision": evaluator_revision,
    "evaluator_image": image,
    "config_sha256": sha256(config),
}
Path(output).write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
PY
printf '%s\n' "$WORK_DIR/$RUN_ID/evaluator-summary.json" > "$WORK_DIR/$RUN_ID/evaluator-summary.path"
