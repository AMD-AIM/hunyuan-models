# HunyuanOCR on AMD Radeon GPUs

## Overview

[HunyuanOCR-1.5](https://github.com/Tencent-Hunyuan/HunyuanOCR) is a lightweight
1B end-to-end OCR vision-language model. A single model supports document
parsing, text spotting, layout analysis, formula and table recognition,
information extraction, chart parsing, and text-image translation. Its native
context length is 131,072 tokens.

This directory records validated autoregressive vLLM deployments on AMD Radeon
PRO W7900D (`gfx1100`), Radeon 8060S / Strix Halo (`gfx1151`), and Radeon AI PRO
R9700 (`gfx1201`). The hardware-specific runtime images and launch flags differ;
use the matching configuration rather than mixing packages between platforms.

## Environment

The published AMD accuracy runs used BF16, tensor parallelism 1, and Python
3.12.3. The remaining versions are platform-specific:

| Platform | ROCm / HIP | PyTorch | vLLM | Required settings |
| --- | --- | --- | --- | --- |
| [Radeon PRO W7900D](./accuracy/configs/amd-w7900d.md) | ROCm 7.2.4 / HIP 7.2.53211 / MIOpen 3.5.1 | `2.10.0+rocm7.2.4.git3d3aa833` | `0.27.0` | `MIOPEN_FIND_MODE=2` |
| [Ryzen AI Max+ 395 / Radeon 8060S](./accuracy/configs/amd-strix-halo-c2.md) | ROCm 7.15.0 | `2.14.0a0+rocm7.15.0a20260719` | `0.1.dev1+ga1274c75b.d20260807` | 16 GiB fixed KV cache, `--skip-mm-profiling` |
| [Radeon AI PRO R9700](./accuracy/configs/amd-r9700.md) | ROCm 7.14 / HIP 7.14.60850 | `2.13.0a0+rocm7.14.0a20260612` | `0.1.dev1+g3775d5fca` | transformers 5.x registration patch, eager mode, `MIOPEN_FIND_MODE=2` |

Host prerequisites are Linux with the matching AMDGPU/ROCm driver, Docker with
access to `/dev/kfd` and `/dev/dri`, and `git`, `curl`, `jq`, and Python 3.12.
The client environment additionally needs the OpenAI Python client.

## Installation

There is no single validated Radeon package set for all three GPU generations.
Use the container image and launch command from the matching hardware guide.

Clone this repository, then download and verify the exact HunyuanOCR source,
weights, OmniDocBench v1.6 data, and evaluator source used by the published
accuracy results:

```bash
git clone https://github.com/AMD-AIM/hunyuan-models.git
cd hunyuan-models

# HF_ENDPOINT is optional; omit it to use huggingface.co.
HF_ENDPOINT=https://hf-mirror.com \
./HunyuanOCR/accuracy/scripts/prepare_assets.sh
```

Assets are stored under the ignored `HunyuanOCR/accuracy/assets/` directory.
The preparation script pins and verifies:

- HunyuanOCR code `c55965d3da1e6f41987abec8068f2e70851318bc`;
- `tencent/HunyuanOCR` weights revision
  `449e7d471a8a1ef5bd5d652e4881183d7252cbc7`;
- all 1,651 OmniDocBench v1.6 pages and the ground-truth SHA-256;
- OmniDocBench evaluator revision `147cd5ac9472002f5751221d390bf00abdbc0d2f`.

Create a small client environment for single-image and batch requests:

```bash
python3.12 -m venv .venv-hunyuanocr-client
source .venv-hunyuanocr-client/bin/activate
python -m pip install --upgrade pip
python -m pip install "openai>=1.30.0"
```

Then start the server using the guide for your accelerator. Each guide pins the
validated container image, device mapping, environment variables, model limits,
and ports:

- [Radeon PRO W7900D](./accuracy/configs/amd-w7900d.md)
- [Ryzen AI Max+ 395 / Radeon 8060S](./accuracy/configs/amd-strix-halo-c2.md)
- [Radeon AI PRO R9700](./accuracy/configs/amd-r9700.md)

Do not omit `MIOPEN_FIND_MODE=2` on the recorded W7900D stack. Without it, some
image shapes produced coordinate placeholders instead of document text.

## Running the Model

One TP=1 endpoint is sufficient for ordinary single-image inference. The
multi-endpoint layouts and client concurrency in the local profiles are required
only when reproducing the published full-dataset schedule.

After the selected guide reports a healthy OpenAI-compatible endpoint, verify
the served model ID:

```bash
curl -fsS http://127.0.0.1:8000/v1/models
```

Replace port `8000` with the port from your hardware guide. Run a single
document through the pinned official client:

```bash
CLIENT=HunyuanOCR/accuracy/assets/src/HunyuanOCR/inference/vLLM/infer_vllm_client.py

python "$CLIENT" \
  --image /path/to/document.png \
  --task-type doc_parse \
  --model tencent/HunyuanOCR \
  --host 127.0.0.1 \
  --port 8000 \
  --max-tokens 32768
```

`doc_parse` emits Markdown, HTML tables, and LaTeX formulas while ignoring
headers and footers. List all 12 supported task types with:

```bash
python HunyuanOCR/accuracy/assets/src/HunyuanOCR/inference/vLLM/infer_vllm_client.py \
  --list-tasks
```

To reproduce the complete 1,651-page accuracy run, start every endpoint listed
in the local profile and run:

```bash
PYTHON_BIN=$PWD/.venv-hunyuanocr-client/bin/python \
./HunyuanOCR/accuracy/run.sh amd-w7900d
```

Available profile IDs are `amd-w7900d`, `amd-strix-halo-c2`, `amd-r9700`, and
`nvidia-rtx4090`. The runner verifies assets and endpoints, generates all
predictions, checks coverage, runs the pinned evaluator image, and writes the
report below `HunyuanOCR/accuracy/work/`. See the
[full reproduction protocol](./accuracy/reproduce.md) for request parameters and
provenance details.

## Accuracy

OmniDocBench v1.6 accuracy uses the pinned HunyuanOCR-1.5 1B model and all 1,651
pages:

| Platform | Overall↑ |
| --- | ---: |
| Official paper | 94.74 |
| NVIDIA RTX 4090 | 95.443681 |
| AMD Radeon PRO W7900D | 95.593058 |
| AMD Strix Halo (`c2`) | 95.345115 |
| AMD Radeon AI PRO R9700 | 95.618309 |

- [Full accuracy metrics](./accuracy/results.md)
- [Self-contained reproduction guide](./accuracy/reproduce.md)
- [Local profiles and raw evidence](./accuracy/evidence/README.md)

## Performance

- [Benchmark results](./benchmarks/results.md)
