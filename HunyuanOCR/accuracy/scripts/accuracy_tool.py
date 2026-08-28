#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping


ACCURACY_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PROTOCOL = ACCURACY_ROOT / "protocol" / "accuracy-v1.json"


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected a JSON object: {path}")
    return value


def write_json(path: Path, value: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(8 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def git_blob_sha1(path: Path) -> str:
    try:
        digest = hashlib.sha1(usedforsecurity=False)
    except TypeError:
        digest = hashlib.sha1()
    digest.update(f"blob {path.stat().st_size}\0".encode("ascii"))
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(8 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_protocol(path: Path) -> dict[str, Any]:
    protocol = read_json(path)
    config_path = ACCURACY_ROOT / protocol["evaluator"]["config"]
    if sha256_file(config_path) != protocol["evaluator"]["config_sha256"]:
        raise ValueError(f"evaluator config SHA-256 mismatch: {config_path}")
    return protocol


def git_output(path: Path, *args: str) -> str | None:
    completed = subprocess.run(
        ["git", "-C", str(path), *args],
        capture_output=True,
        text=True,
        check=False,
    )
    return completed.stdout.strip() if completed.returncode == 0 else None


def verify_snapshot(
    root: Path,
    repository: str,
    revision: str,
    expected_files: int,
    expected_images: int,
    errors: list[str],
) -> dict[str, int]:
    manifest_path = root / ".download-manifest.json"
    if not manifest_path.is_file():
        errors.append(f"snapshot manifest is missing: {root}")
        return {"verified_files": 0, "verified_bytes": 0}
    manifest = read_json(manifest_path)
    for key, expected in (
        ("repository", repository),
        ("revision", revision),
        ("file_count", expected_files),
        ("image_count", expected_images),
    ):
        if manifest.get(key) != expected:
            errors.append(f"snapshot manifest {key} mismatch: {root}")
    records = manifest.get("files") or []
    if len(records) != expected_files:
        errors.append(f"snapshot file record count mismatch: {root}")

    verified_files = 0
    verified_bytes = 0
    for record in records:
        relative = Path(record.get("path", ""))
        if not record.get("path") or relative.is_absolute() or ".." in relative.parts:
            errors.append(f"unsafe snapshot path in {root}: {record.get('path')}")
            continue
        path = root / relative
        if not path.is_file():
            errors.append(f"snapshot file is missing: {path}")
            continue
        size = path.stat().st_size
        if record.get("size") is not None and size != record["size"]:
            errors.append(f"snapshot file size mismatch: {path}")
            continue
        if record.get("sha256") and sha256_file(path) != record["sha256"]:
            errors.append(f"snapshot file SHA-256 mismatch: {path}")
            continue
        if record.get("git_blob_sha1") and git_blob_sha1(path) != record["git_blob_sha1"]:
            errors.append(f"snapshot file Git blob SHA-1 mismatch: {path}")
            continue
        verified_files += 1
        verified_bytes += size
    return {"verified_files": verified_files, "verified_bytes": verified_bytes}


def verify_assets(assets_dir: Path, protocol: dict[str, Any]) -> dict[str, Any]:
    errors: list[str] = []
    model = protocol["model"]
    dataset = protocol["dataset"]
    evaluator = protocol["evaluator"]
    hunyuan_source = assets_dir / "src" / "HunyuanOCR"
    evaluator_source = assets_dir / "src" / "OmniDocBench"
    model_dir = assets_dir / "models" / "HunyuanOCR"
    data_dir = assets_dir / "data" / "OmniDocBench_v1_6"
    gt_path = data_dir / dataset["gt_file"]
    image_dir = data_dir / "images"

    source_revisions = {
        "hunyuanocr": git_output(hunyuan_source, "rev-parse", "HEAD"),
        "omnidocbench": git_output(evaluator_source, "rev-parse", "HEAD"),
    }
    if source_revisions["hunyuanocr"] != model["code_revision"]:
        errors.append("HunyuanOCR source revision mismatch")
    if source_revisions["omnidocbench"] != evaluator["revision"]:
        errors.append("OmniDocBench source revision mismatch")
    source_dirty = {
        "hunyuanocr": bool(git_output(hunyuan_source, "status", "--porcelain")),
        "omnidocbench": bool(git_output(evaluator_source, "status", "--porcelain")),
    }
    if any(source_dirty.values()):
        errors.append(f"source checkout is dirty: {source_dirty}")

    marker = model_dir / ".snapshot-revision"
    if not marker.is_file() or marker.read_text().strip() != model["weights_revision"]:
        errors.append("HunyuanOCR model revision marker mismatch")
    if not (model_dir / "config.json").is_file():
        errors.append("HunyuanOCR model config.json is missing")
    weight_files = sorted(model_dir.glob("*.safetensors"))
    if not weight_files:
        errors.append("HunyuanOCR model weights are missing")

    model_snapshot = verify_snapshot(
        model_dir,
        model["weights_repository"],
        model["weights_revision"],
        model["expected_files"],
        0,
        errors,
    )
    data_snapshot = verify_snapshot(
        data_dir,
        dataset["repository"],
        dataset["revision"],
        dataset["expected_files"],
        dataset["expected_images"],
        errors,
    )

    pages: list[dict[str, Any]] = []
    gt_sha256 = None
    gt_bytes = None
    if not gt_path.is_file():
        errors.append("OmniDocBench ground truth is missing")
    else:
        gt_sha256 = sha256_file(gt_path)
        gt_bytes = gt_path.stat().st_size
        if gt_sha256 != dataset["gt_sha256"]:
            errors.append("OmniDocBench ground-truth SHA-256 mismatch")
        if gt_bytes != dataset["gt_bytes"]:
            errors.append("OmniDocBench ground-truth byte count mismatch")
        try:
            pages = json.loads(gt_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError) as exc:
            errors.append(f"OmniDocBench ground truth is invalid: {exc}")

    expected_names = [Path(page["page_info"]["image_path"]).name for page in pages]
    if len(pages) != dataset["expected_images"]:
        errors.append(f"expected {dataset['expected_images']} GT pages, found {len(pages)}")
    if len(expected_names) != len(set(expected_names)):
        errors.append("ground truth contains duplicate image names")
    actual_names = sorted(path.name for path in image_dir.iterdir() if path.is_file()) if image_dir.is_dir() else []
    if set(actual_names) != set(expected_names):
        errors.append(
            f"image inventory mismatch: missing={len(set(expected_names) - set(actual_names))} "
            f"extra={len(set(actual_names) - set(expected_names))}"
        )
    subsets = Counter(
        page.get("page_info", {}).get("page_attribute", {}).get("subset") for page in pages
    )
    if dict(subsets) != dataset["subsets"]:
        errors.append(f"dataset subset distribution mismatch: {dict(subsets)}")

    return {
        "status": "PASS" if not errors else "FAIL",
        "source_revisions": source_revisions,
        "source_dirty": source_dirty,
        "model": {
            "revision": model["weights_revision"],
            "weight_files": len(weight_files),
            "weight_bytes": sum(path.stat().st_size for path in weight_files),
            "snapshot": model_snapshot,
        },
        "dataset": {
            "revision": dataset["revision"],
            "gt_sha256": gt_sha256,
            "gt_bytes": gt_bytes,
            "pages": len(pages),
            "images": len(actual_names),
            "subsets": dict(subsets),
            "snapshot": data_snapshot,
        },
        "errors": errors,
    }


def verify_predictions(gt_path: Path, prediction_dir: Path) -> dict[str, Any]:
    pages = json.loads(gt_path.read_text(encoding="utf-8"))
    image_names = [Path(page["page_info"]["image_path"]).name for page in pages]
    expected = {f"{Path(name).stem}.md" for name in image_names}
    errors: list[str] = []
    if len(expected) != len(image_names):
        errors.append("image stems collide and cannot map one-to-one to Markdown")
    actual_paths = {path.name: path for path in prediction_dir.glob("*.md") if path.is_file()}
    missing = sorted(expected - set(actual_paths))
    extra = sorted(set(actual_paths) - expected)
    if missing:
        errors.append(f"missing Markdown predictions: {len(missing)}")
    if extra:
        errors.append(f"unexpected Markdown predictions: {len(extra)}")

    records_path = prediction_dir / "results.jsonl"
    latest: dict[str, dict[str, Any]] = {}
    record_count = 0
    malformed: list[int] = []
    if not records_path.is_file():
        errors.append("results.jsonl is missing")
    else:
        for line_number, line in enumerate(records_path.read_text(encoding="utf-8").splitlines(), 1):
            if not line.strip():
                continue
            record_count += 1
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                malformed.append(line_number)
                continue
            if record.get("image"):
                latest[record["image"]] = record
        if malformed:
            errors.append(f"malformed results.jsonl lines: {malformed[:10]}")

    missing_records = sorted(set(image_names) - set(latest))
    failed_records = sorted(name for name, record in latest.items() if not record.get("ok"))
    if missing_records:
        errors.append(f"missing latest inference records: {len(missing_records)}")
    if failed_records:
        errors.append(f"failed latest inference records: {len(failed_records)}")
    empty = sorted(name for name, path in actual_paths.items() if path.stat().st_size == 0)
    whitespace = sorted(
        name
        for name, path in actual_paths.items()
        if path.stat().st_size > 0 and not path.read_text(encoding="utf-8").strip()
    )
    return {
        "status": "PASS" if not errors else "FAIL",
        "gt_pages": len(pages),
        "markdown_files": len(actual_paths),
        "result_records_total": record_count,
        "latest_records": len(latest),
        "missing_markdown_count": len(missing),
        "extra_markdown_count": len(extra),
        "missing_record_count": len(missing_records),
        "failed_record_count": len(failed_records),
        "zero_byte_count": len(empty),
        "whitespace_only_count": len(whitespace),
        "samples": {
            "missing_markdown": missing[:20],
            "extra_markdown": extra[:20],
            "missing_records": missing_records[:20],
            "failed_records": failed_records[:20],
            "zero_byte": empty[:20],
            "whitespace_only": whitespace[:20],
        },
        "errors": errors,
    }


def nested(payload: dict[str, Any], *keys: str) -> Any:
    value: Any = payload
    for key in keys:
        if not isinstance(value, dict) or key not in value:
            raise KeyError(".".join(keys))
        value = value[key]
    return value


def component_overall(text_edit: float, formula_cdm: float, table_teds: float) -> float:
    return ((1.0 - text_edit) * 100.0 + formula_cdm + table_teds) / 3.0


def normalize_score(value: float) -> float:
    return value * 100.0 if 0.0 <= value <= 1.0 else value


def extract_metrics(payload: dict[str, Any]) -> dict[str, float]:
    summary = nested(payload, "notebook_metric_summary")
    metrics = nested(summary, "metrics")
    text_edit = float(nested(metrics, "text_block_Edit_dist", "notebook_value"))
    formula_cdm = normalize_score(float(nested(metrics, "display_formula_CDM", "notebook_value")))
    table_teds = normalize_score(float(nested(metrics, "table_TEDS", "notebook_value")))
    table_teds_s = normalize_score(float(nested(metrics, "table_TEDS_structure_only", "notebook_value")))
    order_edit = float(nested(metrics, "reading_order_Edit_dist", "notebook_value"))
    overall = normalize_score(float(nested(summary, "overall_notebook")))
    derived = component_overall(text_edit, formula_cdm, table_teds)
    if abs(overall - derived) > 0.03:
        raise ValueError(f"Overall={overall:.6f} disagrees with components={derived:.6f}")
    return {
        "overall": overall,
        "text_edit": text_edit,
        "formula_cdm": formula_cdm,
        "table_teds": table_teds,
        "table_teds_s": table_teds_s,
        "order_edit": order_edit,
    }


def accuracy_report(source: Path, protocol: dict[str, Any], profile: dict[str, Any]) -> dict[str, Any]:
    payload = read_json(source)
    required = {"runtime_environment", "stage_execution", "page_denominators", "notebook_metric_summary"}
    missing = sorted(required - set(payload))
    if missing:
        raise ValueError(f"official v1.6 run summary is missing: {', '.join(missing)}")
    metrics = extract_metrics(payload)
    reference = protocol["paper_reference"]
    return {
        "status": "PASS",
        "protocol_id": protocol["protocol_id"],
        "dataset_pages": protocol["dataset"]["expected_images"],
        "metrics": metrics,
        "paper_reference": reference,
        "delta_from_paper": {key: round(metrics[key] - reference[key], 6) for key in metrics},
        "machine_id": profile["machine_id"],
        "profile_id": profile["profile_id"],
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source": {"path": str(source), "sha256": sha256_file(source)},
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="HunyuanOCR accuracy verification tools")
    parser.add_argument("--protocol", type=Path, default=DEFAULT_PROTOCOL)
    commands = parser.add_subparsers(dest="command", required=True)
    assets = commands.add_parser("verify-assets")
    assets.add_argument("--assets-dir", type=Path, required=True)
    assets.add_argument("--output", type=Path, required=True)
    predictions = commands.add_parser("verify-predictions")
    predictions.add_argument("--gt", type=Path, required=True)
    predictions.add_argument("--prediction-dir", type=Path, required=True)
    predictions.add_argument("--output", type=Path, required=True)
    report = commands.add_parser("accuracy-report")
    report.add_argument("--profile", type=Path, required=True)
    report.add_argument("--source", type=Path, required=True)
    report.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    protocol = load_protocol(args.protocol)
    if args.command == "verify-assets":
        result = verify_assets(args.assets_dir, protocol)
    elif args.command == "verify-predictions":
        result = verify_predictions(args.gt, args.prediction_dir)
    else:
        result = accuracy_report(args.source, protocol, read_json(args.profile))
    write_json(args.output, result)
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
