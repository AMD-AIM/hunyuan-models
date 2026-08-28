# HunyuanOCR Accuracy Evaluation

### Accuracy (OmniDocBench v1.6)

| Metric | [Official paper](https://arxiv.org/pdf/2607.04884v2) | [NVIDIA RTX 4090](./configs/nvidia-rtx4090.md) | [AMD Radeon PRO W7900D](./configs/amd-w7900d.md) | [AMD Strix Halo (Ryzen AI Max+ 395 / Radeon 8060S, c2)](./configs/amd-strix-halo-c2.md) | [AMD Radeon AI PRO R9700](./configs/amd-r9700.md) |
| --- | ---: | ---: | ---: | ---: | ---: |
| Overall↑ | 94.74 | 95.443681 | 95.593058 | 95.345115 | 95.618309 |
| TextEdit↓ | 0.039 | 0.036132 | 0.036086 | 0.036755 | 0.034877 |
| FormulaCDM↑ | 94.50 | 94.651074 | 95.129761 | 94.213906 | 94.705744 |
| TableTEDS↑ | 93.67 | 95.293169 | 95.258004 | 95.496913 | 95.636851 |
| TableTEDS_S↑ | 94.71 | 96.385071 | 96.362554 | 96.682094 | 96.721318 |
| OrderEdit↓ | 0.129 | 0.127247 | 0.124724 | 0.125789 | 0.124848 |

The paper column is the HunyuanOCR-1.5 reference from Table 12. Every local
column used the pinned 1B model and all 1,651 OmniDocBench v1.6 pages. Select a
hardware heading for the exact server and client configuration, or start with
the [common reproduction protocol](./reproduce.md).

The R9700 and W7900D results used the protocol-pinned evaluator image. The RTX
4090 result used the same evaluator revision and configuration in a
version-aligned local toolchain. The Strix Halo result used the pinned evaluator
image but request concurrency 2 instead of 1, so it is labeled `c2` and is not a
strict protocol result.

## Evidence

- [RTX 4090 accuracy evidence](https://github.com/zihaomu/HunyuanOCR-Bench/tree/1e320ce11a9cfa29f0ffa0f735a103deb1304d43/results/nvidia-rtx4090-amd-sys-741ge-tnrt/local-evaluator-accuracy-20260826T063000Z-ar)
- [W7900D canonical result](https://github.com/zihaomu/HunyuanOCR-Bench/blob/1e320ce11a9cfa29f0ffa0f735a103deb1304d43/results/amd-w7900d-gpu1-xw-k8s-test-m-001/amd-w7900d-gpu1-xw-k8s-test-m-001-20260826-quick9-c1-r1/result.json)
- [Strix Halo c2 accuracy evidence](https://github.com/zihaomu/HunyuanOCR-Bench/tree/1e320ce11a9cfa29f0ffa0f735a103deb1304d43/results/amd-strix-halo-halo3/full1651-c2-accuracy-20260826T065105Z-ar)
- [R9700 canonical result](https://github.com/zihaomu/HunyuanOCR-Bench/blob/1e320ce11a9cfa29f0ffa0f735a103deb1304d43/results/amd-r9700-workstation-sh/amd-r9700-workstation-sh-20260827T014842Z-ar/result.json)

The source table and evidence are fixed at
[`HunyuanOCR-Bench@1e320ce`](https://github.com/zihaomu/HunyuanOCR-Bench/tree/1e320ce11a9cfa29f0ffa0f735a103deb1304d43).

## Metric Formula

```text
Overall = ((1 - TextEdit) * 100 + FormulaCDM + TableTEDS) / 3
```

`TableTEDS_S` and `OrderEdit` are reported but are not terms in `Overall`.
