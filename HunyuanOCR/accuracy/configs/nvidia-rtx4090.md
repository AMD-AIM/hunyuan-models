# NVIDIA GeForce RTX 4090 Accuracy Configuration

This is the serving and client configuration behind the RTX 4090 column in the
[OmniDocBench v1.6 accuracy table](../results.md).

## Runtime

| Setting | Value |
| --- | --- |
| Accelerator | NVIDIA GeForce RTX 4090 |
| Serving framework | vLLM `0.26.1rc1.dev457+gc810e5ee9` |
| Precision | BF16 |
| Tensor parallelism | 1 per endpoint |
| Served model | `tencent/HunyuanOCR` |
| Container image | `ghcr.io/inferstation/vllm-cuda-4090:latest` |
| Container digest | `sha256:6877023dee3a2456e00f468813607fd4ec21cd92c6386e5433e2f7422bf087a8` |
| CUDA / PyTorch | CUDA 13.0 / PyTorch 2.13.0+cu130 |
| Accuracy endpoints | GPU0:18081 and GPU1:18082 |
| Maximum model length / batched tokens | 131072 / 131072 |
| Client concurrency | 2, one worker per endpoint |

## Start Endpoints

Use the HunyuanOCR code and weights prepared by the
[common protocol](../reproduce.md). Run the pinned official launcher once per
GPU inside the recorded image or an equivalent CUDA 13 environment:

```bash
ACCURACY_ROOT=$PWD/HunyuanOCR/accuracy
HUNYUAN_ROOT="$ACCURACY_ROOT/assets/src/HunyuanOCR"
MODEL_PATH="$ACCURACY_ROOT/assets/models/HunyuanOCR"

MODEL_PATH="$MODEL_PATH" \
GPU=0 PORT=18081 GPU_MEM_UTIL=0.9 MAX_MODEL_LEN=131072 \
LOG=vllm_18081.log \
bash "$HUNYUAN_ROOT/inference/vLLM/serve.sh"

MODEL_PATH="$MODEL_PATH" \
GPU=1 PORT=18082 GPU_MEM_UTIL=0.9 MAX_MODEL_LEN=131072 \
LOG=vllm_18082.log \
bash "$HUNYUAN_ROOT/inference/vLLM/serve.sh"
```

The launcher resolves to these accuracy-relevant vLLM arguments:

```bash
CUDA_VISIBLE_DEVICES="$GPU" vllm serve "$MODEL_PATH" \
  --served-model-name tencent/HunyuanOCR \
  -tp 1 \
  --limit-mm-per-prompt '{"image":4,"video":0}' \
  --trust-remote-code \
  --port "$PORT" \
  --gpu-memory-utilization 0.9 \
  --max-model-len 131072 \
  --max-num-batched-tokens 131072
```

## Run Accuracy

The command below reproduces inference with the recorded RTX configuration and
evaluates it with the portable, protocol-pinned evaluator image.

From the `hunyuan-models` repository:

```bash
PYTHON_BIN=/path/to/hunyuan-runtime/bin/python \
./HunyuanOCR/accuracy/run.sh nvidia-rtx4090
```

The published score used the pinned evaluator source and configuration in a
version-aligned local evaluator toolchain rather than the protocol-pinned image.
It is complete comparison evidence, not a canonical protocol result.
The published evidence records that historical toolchain's packages and external
tools, but not a complete installation recipe. Therefore this runner does not
claim byte-for-byte evaluator-runtime provenance with the historical RTX result;
it uses the reproducible official evaluator image instead.

- [Machine profile](../profiles/nvidia-rtx4090.json)
- [Accuracy evidence](../evidence/nvidia-rtx4090/accuracy.json)
