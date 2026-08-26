# Hunyuan Models on AMD Radeon GPUs

This repository tracks the enablement and optimization of [Tencent Hunyuan](https://github.com/Tencent-Hunyuan) models on AMD Radeon GPUs, including workstation, consumer, and integrated graphics hardware. For each model, we document setup instructions, performance benchmarks, and accuracy evaluations across multiple platforms — with AMD Radeon GPUs as the primary target.

## Hardware Platforms

| Category | Devices |
|---|---|
| AMD Radeon Discrete GPU | Radeon PRO W7900, Radeon RX 9700 |
| AMD Integrated GPU | Strix Halo iGPU (e.g., Ryzen AI Max) |
| Reference GPU (NVIDIA) | GeForce RTX 4090 |
| Reference System (NVIDIA) | DGX Spark |

## Models

### [HunyuanOCR](./HunyuanOCR/)

An OCR model from the Hunyuan family. See the [`HunyuanOCR/`](./HunyuanOCR/) directory for:

- Setup and installation guide on ROCm
- Performance benchmarks (throughput, latency) across all platforms
- Accuracy evaluation results

---

## Repository Structure

```
hunyuan-models/
└── HunyuanOCR/
    ├── README.md          # Model-specific setup and notes
    ├── benchmarks/        # Performance results (latency, throughput)
    └── accuracy/          # Accuracy evaluation results
```

More models will be added as enablement work progresses.

## Contributing

Benchmark results and accuracy data are organized per model under their respective directories. When adding new results, please include:

- Hardware platform and driver/ROCm version
- Model configuration (precision, batch size, etc.)
- Measurement methodology

## License

See individual model directories for applicable licenses. Benchmark data in this repository is provided for reference purposes.
