# Reproducing HunyuanOCR Accuracy

This workflow reproduces only the OmniDocBench v1.6 accuracy evaluation. It does
not run or publish performance measurements.

## Pinned Inputs

| Component | Revision or digest |
| --- | --- |
| Reproduction harness | `zihaomu/HunyuanOCR-Bench@1e320ce11a9cfa29f0ffa0f735a103deb1304d43` |
| HunyuanOCR code | `c55965d3da1e6f41987abec8068f2e70851318bc` |
| HunyuanOCR weights | `tencent/HunyuanOCR@449e7d471a8a1ef5bd5d652e4881183d7252cbc7` |
| OmniDocBench v1.6 data | `opendatalab/OmniDocBench@d386947f7fc3bafdcd756c8485845a2f43a19875` |
| OmniDocBench evaluator | `opendatalab/OmniDocBench@147cd5ac9472002f5751221d390bf00abdbc0d2f` |
| Ground-truth SHA-256 | `a45cd84b04ad8b793e775089640e6b681209abea33ead54c1828ddca35fae496` |
| Evaluator image | `ghcr.io/zeng-weijun/omnidocbench-eval@sha256:6116ad72172e763b5c43e963d5efebf2093f2362b975f58156ce4f6c9142e617` |

The dataset contains 1,651 pages. The evaluator uses the committed end-to-end
configuration with quick matching, CDM for formulas, and TEDS for tables.

## Prepare Assets

Clone the fixed harness and materialize its pinned source, model, and dataset
assets. A Hugging Face mirror is optional.

```bash
git clone https://github.com/zihaomu/HunyuanOCR-Bench.git
cd HunyuanOCR-Bench
git checkout --detach 1e320ce11a9cfa29f0ffa0f735a103deb1304d43
HF_ENDPOINT=https://hf-mirror.com ./scripts/prepare-assets.sh
```

The preparation gate verifies all revisions, 1,651 images, the 42,208,096-byte
ground-truth file, and its SHA-256 before inference.

The pinned HunyuanOCR runtime must provide the dependencies used by
`inference/vLLM/batch_infer.py`, including the OpenAI Python client. The
evaluation stage additionally requires Docker, `curl`, and `jq` on the host.

## Accuracy Request

| Parameter | Value |
| --- | --- |
| Task | `doc_parse` |
| Temperature | `0` |
| Top-p | `1` |
| Top-k | `-1` |
| Repetition penalty | `1.08` |
| Maximum output tokens | `32768` |
| Document post-processing | Enabled |

The exact prompt is:

```text
提取文档图片中正文的所有信息用markdown格式表示，其中页眉、页脚部分忽略，表格用html格式表达，文档中公式用latex格式表示，按照阅读顺序组织进行解析。
```

## Start An Endpoint

Use the guide matching the result column you want to reproduce:

| Result column | Server guide | Client configuration |
| --- | --- | --- |
| NVIDIA RTX 4090 | [Configuration](./configs/nvidia-rtx4090.md) | `nvidia-rtx4090.env` |
| AMD Radeon PRO W7900D | [Configuration](./configs/amd-w7900d.md) | `amd-w7900d.env` |
| AMD Strix Halo c2 | [Configuration](./configs/amd-strix-halo-c2.md) | `amd-strix-halo-c2.env` |
| AMD Radeon AI PRO R9700 | [Configuration](./configs/amd-r9700.md) | `amd-r9700.env` |

Wait until every configured `/v1/models` endpoint reports
`tencent/HunyuanOCR`.

## Run Inference And Evaluation

From a clone of this repository, point the accuracy-only runner at the pinned
benchmark checkout and the Python environment containing the HunyuanOCR client
dependencies:

```bash
BENCH_ROOT=/path/to/HunyuanOCR-Bench \
PYTHON_BIN=/path/to/hunyuan-runtime/bin/python \
./HunyuanOCR/accuracy/run.sh amd-w7900d.env
```

Replace `amd-w7900d.env` with the client configuration for the selected result
column. Set `RUN_ID` to choose a stable output directory; otherwise a UTC
timestamp is used.

The runner performs only this sequence:

1. Verify the fixed harness commit and all assets.
2. Verify every configured OpenAI-compatible endpoint.
3. Generate document predictions for all 1,651 images.
4. Verify that the prediction inventory is complete.
5. Run the pinned OmniDocBench evaluator image.
6. Write normalized metrics to `work/<run-id>/accuracy.json`.

The runner always uses the protocol-pinned evaluator image. See the RTX 4090
guide for the provenance difference from that column's historical local evaluator.

The client concurrency in each `.env` file records the actual schedule behind
that published column. Multiple independent endpoints or client workers reduce
wall-clock evaluation time; every request retains the deterministic generation
parameters above. Strix Halo is explicitly reported as `c2` because its two
workers deviate from the strict concurrency-1 protocol.
