# HunyuanOCR Accuracy Evidence

This directory contains the accuracy-only evidence behind the OmniDocBench v1.6
table. The raw JSON files were transferred byte-for-byte from source commit
`1e320ce11a9cfa29f0ffa0f735a103deb1304d43`; the [manifest](./manifest.json)
records the original repository, byte count, and SHA-256 of every file.

No speed summaries, per-request speed records, or throughput artifacts are
included.

| Platform | Accuracy report | Asset gate | Prediction gate | Raw evaluator summary | Additional provenance |
| --- | --- | --- | --- | --- | --- |
| NVIDIA RTX 4090 | [accuracy.json](./nvidia-rtx4090/accuracy.json) | [assets-verification.json](./nvidia-rtx4090/assets-verification.json) | [prediction-verification.json](./nvidia-rtx4090/prediction-verification.json) | [evaluator-summary.json](./nvidia-rtx4090/evaluator-summary.json) | [manifest.json](./nvidia-rtx4090/manifest.json), [runtime](./nvidia-rtx4090/evaluator-runtime-environment.json), [stages](./nvidia-rtx4090/evaluator-stage-execution.json), [metric result](./nvidia-rtx4090/evaluator-metric-result.json) |
| AMD Radeon PRO W7900D | [accuracy.json](./amd-w7900d/accuracy.json) | [assets-verification.json](./amd-w7900d/assets-verification.json) | [prediction-verification.json](./amd-w7900d/prediction-verification.json) | [evaluator-summary.json](./amd-w7900d/evaluator-summary.json) | [inference summary](./amd-w7900d/inference-summary.json), [prediction quality](./amd-w7900d/prediction-quality.json) |
| AMD Strix Halo (`c2`) | [accuracy.json](./amd-strix-halo-c2/accuracy.json) | [assets-verification.json](./amd-strix-halo-c2/assets-verification.json) | [prediction-verification.json](./amd-strix-halo-c2/prediction-verification.json) | [evaluator-summary.json](./amd-strix-halo-c2/evaluator-summary.json) | Request concurrency 2 is recorded in the [local profile](../profiles/amd-strix-halo-c2.json). |
| AMD Radeon AI PRO R9700 | [accuracy.json](./amd-r9700/accuracy.json) | [assets-verification.json](./amd-r9700/assets-verification.json) | [prediction-verification.json](./amd-r9700/prediction-verification.json) | [evaluator-summary.json](./amd-r9700/evaluator-summary.json) | Eager mode and client concurrency 32 are recorded in the [local profile](../profiles/amd-r9700.json). |

The raw reports intentionally retain historical timestamps and source-path
strings. Use the repository-relative links above and the local profiles for
reproduction.
