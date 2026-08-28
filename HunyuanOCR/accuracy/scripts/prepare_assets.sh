#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PROTOCOL=$ROOT/protocol/accuracy-v1.json
ASSETS_DIR=${ASSETS_DIR:-$ROOT/assets}
HF_ENDPOINT=${HF_ENDPOINT:-https://huggingface.co}
DOWNLOAD_WORKERS=${DOWNLOAD_WORKERS:-4}
HUNYUANOCR_GIT_URL=${HUNYUANOCR_GIT_URL:-https://github.com/Tencent-Hunyuan/HunyuanOCR.git}
OMNIDOCBENCH_GIT_URL=${OMNIDOCBENCH_GIT_URL:-https://github.com/opendatalab/OmniDocBench.git}

for command in git jq python3 curl; do
    command -v "$command" >/dev/null \
        || { printf 'ERROR: missing command: %s\n' "$command" >&2; exit 1; }
done

value() { jq -er "$1" "$PROTOCOL"; }
HUNYUANOCR_CODE_REVISION=$(value .model.code_revision)
HUNYUANOCR_MODEL_REVISION=$(value .model.weights_revision)
HUNYUANOCR_MODEL_REPOSITORY=$(value .model.weights_repository)
HUNYUANOCR_MODEL_FILES=$(value .model.expected_files)
OMNIDOCBENCH_CODE_REVISION=$(value .evaluator.revision)
OMNIDOCBENCH_DATA_REVISION=$(value .dataset.revision)
OMNIDOCBENCH_DATA_REPOSITORY=$(value .dataset.repository)
OMNIDOCBENCH_DATA_FILES=$(value .dataset.expected_files)
OMNIDOCBENCH_IMAGES=$(value .dataset.expected_images)

clone_fixed() {
    local url=$1 destination=$2 revision=$3
    if [[ -d "$destination/.git" ]]; then
        [[ "$(git -C "$destination" rev-parse HEAD)" == "$revision" ]] \
            || { printf 'ERROR: revision mismatch in %s\n' "$destination" >&2; return 1; }
        [[ -z "$(git -C "$destination" status --porcelain)" ]] \
            || { printf 'ERROR: source checkout is dirty: %s\n' "$destination" >&2; return 1; }
        return
    fi
    [[ ! -e "$destination" ]] \
        || { printf 'ERROR: refusing to overwrite %s\n' "$destination" >&2; return 1; }
    git clone --no-checkout "$url" "$destination"
    git -C "$destination" checkout --detach "$revision"
}

mkdir -p "$ASSETS_DIR/src" "$ASSETS_DIR/models" "$ASSETS_DIR/data" "$ASSETS_DIR/manifests"
clone_fixed "$HUNYUANOCR_GIT_URL" "$ASSETS_DIR/src/HunyuanOCR" "$HUNYUANOCR_CODE_REVISION"
clone_fixed "$OMNIDOCBENCH_GIT_URL" "$ASSETS_DIR/src/OmniDocBench" "$OMNIDOCBENCH_CODE_REVISION"

python3 "$ROOT/scripts/download_snapshot.py" \
    --repo "$HUNYUANOCR_MODEL_REPOSITORY" \
    --repo-type model \
    --revision "$HUNYUANOCR_MODEL_REVISION" \
    --destination "$ASSETS_DIR/models/HunyuanOCR" \
    --endpoint "$HF_ENDPOINT" \
    --workers "$DOWNLOAD_WORKERS" \
    --expected-files "$HUNYUANOCR_MODEL_FILES" \
    --expected-images 0 \
    --exclude-prefix v1.0/

python3 "$ROOT/scripts/download_snapshot.py" \
    --repo "$OMNIDOCBENCH_DATA_REPOSITORY" \
    --repo-type dataset \
    --revision "$OMNIDOCBENCH_DATA_REVISION" \
    --destination "$ASSETS_DIR/data/OmniDocBench_v1_6" \
    --endpoint "$HF_ENDPOINT" \
    --workers "$DOWNLOAD_WORKERS" \
    --expected-files "$OMNIDOCBENCH_DATA_FILES" \
    --expected-images "$OMNIDOCBENCH_IMAGES"

python3 "$ROOT/scripts/accuracy_tool.py" verify-assets \
    --assets-dir "$ASSETS_DIR" \
    --output "$ASSETS_DIR/manifests/assets-verification.json"
