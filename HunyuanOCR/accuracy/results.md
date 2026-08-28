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

- [RTX 4090 accuracy report](./evidence/nvidia-rtx4090/accuracy.json)
- [W7900D accuracy report](./evidence/amd-w7900d/accuracy.json)
- [Strix Halo c2 accuracy report](./evidence/amd-strix-halo-c2/accuracy.json)
- [R9700 accuracy report](./evidence/amd-r9700/accuracy.json)

Each evidence directory also contains the asset gate, prediction gate, and raw
evaluator summary. The files were transferred byte-for-byte from source commit
`1e320ce11a9cfa29f0ffa0f735a103deb1304d43`; their checksums are recorded in the
[local evidence manifest](./evidence/manifest.json). Speed artifacts are excluded.

## Metric Formula

```text
Overall = ((1 - TextEdit) * 100 + FormulaCDM + TableTEDS) / 3
```

`TableTEDS_S` and `OrderEdit` are reported but are not terms in `Overall`.
