#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
REPO_ROOT=$(cd "$ROOT/../.." && pwd)

bash -n "$ROOT/run.sh" "$ROOT/scripts/prepare_assets.sh" "$ROOT/scripts/run_evaluation.sh"
python3 -m json.tool "$ROOT/protocol/accuracy-v1.json" >/dev/null
for profile in "$ROOT"/profiles/*.json; do
    python3 -m json.tool "$profile" >/dev/null
done

python3 - "$ROOT" "$REPO_ROOT" <<'PY'
from pathlib import Path
import hashlib
import json
import re
import sys

root = Path(sys.argv[1])
repo = Path(sys.argv[2])
protocol = json.loads((root / "protocol/accuracy-v1.json").read_text(encoding="utf-8"))
profiles = ("nvidia-rtx4090", "amd-w7900d", "amd-strix-halo-c2", "amd-r9700")
keys = ("overall", "text_edit", "formula_cdm", "table_teds", "table_teds_s", "order_edit")
labels = ("Overall↑", "TextEdit↓", "FormulaCDM↑", "TableTEDS↑", "TableTEDS_S↑", "OrderEdit↓")
formats = (2, 3, 2, 2, 2, 3)
documents = [repo / "README.md", repo / "HunyuanOCR/README.md", *root.rglob("*.md")]

for document in documents:
    text = document.read_text(encoding="utf-8")
    if "github.com/zihaomu/HunyuanOCR-Bench" in text:
        raise AssertionError(f"old repository link in {document}")
    for target in re.findall(r"\[[^]]+\]\(([^)]+)\)", text):
        if "://" not in target and not target.startswith("#"):
            path = (document.parent / target).resolve()
            if not path.exists():
                raise AssertionError(f"broken link in {document}: {target}")

root_readme = (repo / "README.md").read_text(encoding="utf-8")
detail = (root / "results.md").read_text(encoding="utf-8")
for key, label, places in zip(keys, labels, formats):
    local = [json.loads((root / f"evidence/{name}/accuracy.json").read_text())["metrics"][key] for name in profiles]
    values = [protocol["paper_reference"][key], *local]
    row = "| " + label + " | " + " | ".join(
        f"{value:.{places if index == 0 else 6}f}" for index, value in enumerate(values)
    ) + " |"
    if row not in root_readme or row not in detail:
        raise AssertionError(f"accuracy row drift: {label}")

manifest = json.loads((root / "evidence/manifest.json").read_text(encoding="utf-8"))
for relative, expected in manifest["files"].items():
    path = root / "evidence" / relative
    if path.stat().st_size != expected["bytes"]:
        raise AssertionError(f"evidence size mismatch: {relative}")
    if hashlib.sha256(path.read_bytes()).hexdigest() != expected["sha256"]:
        raise AssertionError(f"evidence SHA-256 mismatch: {relative}")

print("PASS: accuracy tables, local links, and evidence hashes")
PY

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
for profile in nvidia-rtx4090 amd-w7900d amd-strix-halo-c2 amd-r9700; do
    PYTHONDONTWRITEBYTECODE=1 python3 "$ROOT/scripts/accuracy_tool.py" accuracy-report \
        --profile "$ROOT/profiles/$profile.json" \
        --source "$ROOT/evidence/$profile/evaluator-summary.json" \
        --output "$TMP/$profile.json" >/dev/null
    python3 - "$ROOT/evidence/$profile/accuracy.json" "$TMP/$profile.json" <<'PY'
import json
import sys

expected = json.load(open(sys.argv[1], encoding="utf-8"))["metrics"]
actual = json.load(open(sys.argv[2], encoding="utf-8"))["metrics"]
if actual != expected:
    raise SystemExit(f"metric mismatch: {sys.argv[1]}")
PY
done
printf 'PASS: all four raw evaluator summaries reproduce their published metrics\n'
