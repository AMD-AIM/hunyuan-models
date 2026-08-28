# HunyuanOCR on AMD Radeon GPUs

## Overview

TODO: Brief description of HunyuanOCR model.

## Environment

| Component | Version |
|---|---|
| ROCm | TODO |
| PyTorch | TODO |
| Python | TODO |

## Installation

TODO

## Running the Model

TODO

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
