# Hunyuan Models on AMD Radeon GPUs

This repository tracks the enablement and optimization of [Tencent Hunyuan](https://github.com/Tencent-Hunyuan) models on AMD Radeon GPUs, including workstation, consumer, and integrated graphics hardware. For each model, we document setup instructions, performance benchmarks, and accuracy evaluations across multiple platforms — with AMD Radeon GPUs as the primary target.

## Hardware Platforms

| Category | Devices |
|---|---|
| AMD Radeon Discrete GPU | Radeon PRO W7900D, Radeon AI PRO R9700 |
| AMD Integrated GPU | Ryzen AI Max+ 395 with Radeon 8060S (Strix Halo) |
| Reference GPU (NVIDIA) | GeForce RTX 4090 |
| Reference System (NVIDIA) | DGX Spark |

## Models

### [HunyuanOCR](./HunyuanOCR/)

An OCR model from the Hunyuan family. See the [`HunyuanOCR/`](./HunyuanOCR/) directory for:

- Setup and installation guide on ROCm
- Performance benchmarks (throughput, latency) across all platforms
- Accuracy evaluation results

#### Accuracy (OmniDocBench v1.6)

| Metric | [Official paper](https://arxiv.org/pdf/2607.04884v2) | [NVIDIA RTX 4090](./HunyuanOCR/accuracy/configs/nvidia-rtx4090.md) | [AMD Radeon PRO W7900D](./HunyuanOCR/accuracy/configs/amd-w7900d.md) | [AMD Strix Halo (Ryzen AI Max+ 395 / Radeon 8060S, c2)](./HunyuanOCR/accuracy/configs/amd-strix-halo-c2.md) | [AMD Radeon AI PRO R9700](./HunyuanOCR/accuracy/configs/amd-r9700.md) |
| --- | ---: | ---: | ---: | ---: | ---: |
| Overall↑ | 94.74 | 95.443681 | 95.593058 | 95.345115 | 95.618309 |
| TextEdit↓ | 0.039 | 0.036132 | 0.036086 | 0.036755 | 0.034877 |
| FormulaCDM↑ | 94.50 | 94.651074 | 95.129761 | 94.213906 | 94.705744 |
| TableTEDS↑ | 93.67 | 95.293169 | 95.258004 | 95.496913 | 95.636851 |
| TableTEDS_S↑ | 94.71 | 96.385071 | 96.362554 | 96.682094 | 96.721318 |
| OrderEdit↓ | 0.129 | 0.127247 | 0.124724 | 0.125789 | 0.124848 |

All local columns use the pinned HunyuanOCR-1.5 1B model and all 1,651
OmniDocBench v1.6 pages. See the [detailed accuracy results](./HunyuanOCR/accuracy/results.md),
[local evidence](./HunyuanOCR/accuracy/evidence/README.md), and
[self-contained reproduction guide](./HunyuanOCR/accuracy/reproduce.md).

---

## Repository Structure

```
hunyuan-models/
└── HunyuanOCR/
    ├── README.md          # Model-specific setup and notes
    ├── benchmarks/        # Performance results (latency, throughput)
    └── accuracy/          # Accuracy results and reproduction
        ├── configs/       # Hardware-specific serving guides
        ├── profiles/      # Machine-readable accuracy profiles
        ├── evidence/      # Transferred raw accuracy evidence
        ├── protocol/      # Pinned model, dataset, and evaluator contract
        └── scripts/       # Accuracy-only preparation and evaluation tools
```

More models will be added as enablement work progresses.

## Contributing

Benchmark results and accuracy data are organized per model under their respective directories. When adding new results, please include:

- Hardware platform and driver/ROCm version
- Model configuration (precision, batch size, etc.)
- Measurement methodology

## License

See individual model directories for applicable licenses. Benchmark data in this repository is provided for reference purposes.
