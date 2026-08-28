# AMD Radeon PRO W7900D Accuracy Configuration

This is the serving and client configuration behind the W7900D column in the
[OmniDocBench v1.6 accuracy table](../results.md).

## Runtime

| Setting | Value |
| --- | --- |
| Accelerator | AMD Radeon PRO W7900D (`gfx1100`) |
| Serving framework | vLLM `0.27.0` |
| Precision | BF16 |
| Tensor parallelism | 1 per endpoint |
| Served model | `tencent/HunyuanOCR` |
| Container image | `hunyuanocr-base:rocm7.2.4-v0` |
| Container digest | `sha256:83fef91f42e0306dbf81d2d225086234e7fbc770eeba16a02a9a11f57e17d335` |
| ROCm / PyTorch | ROCm 7.2.4 / PyTorch 2.10.0+rocm7.2.4.git3d3aa833 |
| Accuracy endpoints | GPU1:18016, GPU2:18017, GPU5:18020, GPU6:18021 |
| Maximum model length / batched tokens | 131072 / 131072 |
| Client concurrency | 4, one worker per endpoint |

Prepare the pinned model, dataset, and evaluator assets with the
[common protocol](../reproduce.md) before starting the endpoints.

`MIOPEN_FIND_MODE=2` is required for this exact ROCm 7.2.4, MIOpen 3.5.1,
and gfx1100 stack. Without it, some image shapes produced coordinate-only
placeholders instead of document text.

## Start Endpoints

```bash
ACCURACY_ROOT=$PWD/HunyuanOCR/accuracy
WORKSPACE=/path/to/hunyuanOCR_workspace

for pair in "1:18016" "2:18017" "5:18020" "6:18021"; do
  GPU=${pair%%:*}
  PORT=${pair##*:}
  docker run -d --name "hyocr-miopen2-gpu${GPU}" \
    --network host \
    --device=/dev/kfd --device=/dev/dri \
    --group-add 44 --group-add 993 \
    --security-opt seccomp=unconfined --ipc=host --shm-size=16g \
    -e "HIP_VISIBLE_DEVICES=${GPU}" \
    -e MIOPEN_FIND_MODE=2 \
    -e HF_HOME=/workspace/cache/huggingface \
    -e PYTORCH_ROCM_ARCH=gfx1100 \
    -e VLLM_TARGET_DEVICE=rocm \
    -v "$WORKSPACE:/workspace" \
    -v "$ACCURACY_ROOT/assets/models/HunyuanOCR:/workspace/models/HunyuanOCR:ro" \
    --entrypoint vllm \
    hunyuanocr-base:rocm7.2.4-v0 \
    serve /workspace/models/HunyuanOCR \
    --served-model-name tencent/HunyuanOCR \
    -tp 1 \
    --limit-mm-per-prompt '{"image":4,"video":0}' \
    --trust-remote-code \
    --port "$PORT" \
    --gpu-memory-utilization 0.90 \
    --max-model-len 131072 \
    --max-num-batched-tokens 131072 \
    --skip-mm-profiling
done
```

## Run Accuracy

```bash
PYTHON_BIN=/path/to/hunyuan-runtime/bin/python \
./HunyuanOCR/accuracy/run.sh amd-w7900d
```

- [Machine profile](../profiles/amd-w7900d.json)
- [Accuracy evidence](../evidence/amd-w7900d/accuracy.json)
