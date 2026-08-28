# AMD Strix Halo Accuracy Configuration

This is the serving and client configuration behind the Strix Halo `c2` column
in the [OmniDocBench v1.6 accuracy table](../results.md).

## Runtime

| Setting | Value |
| --- | --- |
| Accelerator | AMD Radeon 8060S (`gfx1151`), integrated in Ryzen AI Max+ 395 |
| Device memory visible to PyTorch | 120 GiB unified memory |
| Serving framework | vLLM `0.1.dev1+ga1274c75b.d20260807` |
| Precision | BF16 |
| Tensor parallelism | 1 |
| Served model | `tencent/HunyuanOCR` |
| Container image | `ghcr.io/inferstation/vllm-rocm-halo:latest` |
| Container digest | `sha256:ff89ae6d0cc44eb70b9bada85b535652058c0daf3c2c2c542da844b6f592cae6` |
| ROCm / PyTorch | ROCm 7.15.0 / PyTorch 2.14.0a0+rocm7.15.0a20260719 |
| Accuracy endpoint | HIP0, port 8000 |
| Fixed KV cache | 16 GiB |
| Model context | 131072 tokens |
| Maximum batched tokens / sequences | 131072 / 8 |
| Client concurrency | 2 |

Prepare the pinned assets with the [common protocol](../reproduce.md), then
start the endpoint with the fixed 16 GiB KV cache used by the accuracy run:

## Start Endpoint

```bash
BENCH_ROOT=/path/to/HunyuanOCR-Bench
RUNTIME_CACHE=/path/to/vllm-cache

docker run -d --name hunyuanocr-strix-halo-accuracy \
  --device=/dev/kfd --device=/dev/dri \
  --group-add 44 --group-add 992 \
  --security-opt seccomp=unconfined --security-opt label=disable \
  --ipc=host --shm-size=32g \
  -p 8000:8000 \
  -e HIP_VISIBLE_DEVICES=0 -e CUDA_VISIBLE_DEVICES=0 \
  -e HF_HOME=/runtime-cache/huggingface -e XDG_CACHE_HOME=/runtime-cache \
  -e HF_HUB_OFFLINE=1 -e TRANSFORMERS_OFFLINE=1 \
  -v "$RUNTIME_CACHE:/runtime-cache" \
  -v "$BENCH_ROOT/assets/models/HunyuanOCR:/model:ro" \
  ghcr.io/inferstation/vllm-rocm-halo@sha256:ff89ae6d0cc44eb70b9bada85b535652058c0daf3c2c2c542da844b6f592cae6 \
  --model /model \
  --served-model-name tencent/HunyuanOCR \
  --tensor-parallel-size 1 \
  --dtype bfloat16 \
  --limit-mm-per-prompt '{"image":4,"video":0}' \
  --trust-remote-code \
  --kv-cache-memory-bytes 17179869184 \
  --skip-mm-profiling \
  --max-model-len 131072 \
  --max-num-batched-tokens 131072 \
  --max-num-seqs 8 \
  --host 0.0.0.0 \
  --port 8000
```

## Run Accuracy

```bash
BENCH_ROOT=/path/to/HunyuanOCR-Bench \
PYTHON_BIN=/path/to/hunyuan-runtime/bin/python \
./HunyuanOCR/accuracy/run.sh amd-strix-halo-c2.env
```

This run used two request workers on one endpoint. Concurrency 2 differs from
the strict protocol concurrency 1, so the result is explicitly labeled `c2` and
is complete comparison evidence rather than a canonical protocol result.

- [Machine profile](https://github.com/zihaomu/HunyuanOCR-Bench/blob/1e320ce11a9cfa29f0ffa0f735a103deb1304d43/machines/amd-strix-halo-halo3.json)
- [Accuracy evidence](https://github.com/zihaomu/HunyuanOCR-Bench/tree/1e320ce11a9cfa29f0ffa0f735a103deb1304d43/results/amd-strix-halo-halo3/full1651-c2-accuracy-20260826T065105Z-ar)
