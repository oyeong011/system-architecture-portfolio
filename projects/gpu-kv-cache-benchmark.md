# KV-cache Consumer GPU Benchmark

Repo: [`oyeong011/kv-cache-consumer-gpu-bench`](https://github.com/oyeong011/kv-cache-consumer-gpu-bench) (public) · branch `artifact/rtx5060-final-paper-data` @ `0fbc048` · Python / PyTorch / HF Transformers

## Problem

Before arguing about KV-cache *hardware*, it is worth measuring the pressure that
motivates it: how fast does the KV cache actually grow with context and batch, where
does latency start degrading, and where does the GPU OOM? On consumer GPUs (8–16 GB)
those boundaries arrive early enough to measure directly.

Explicitly **not** an Oaken reproduction. Oaken's contribution is accelerator-level
HW/SW co-design with dedicated quant/dequant hardware; this repo measures the root
memory pressure such work responds to. That boundary is stated in the repo README so
the work is not mistaken for a paper reproduction it is not.

## My Role

Built the benchmark harness, ran the grids on RTX 5060 and RTX 5080, wrote the
analysis and the comparison documents, and separated directly-backed evidence from
limitations in writing.

## Implementation

- `run_kv_cache_bench.py` — sweeps model × `seq_len` × `batch_size`, records
  `past_key_values` bytes, peak memory, decode throughput, OOM events.
- `run_eviction_bench.py` (`eviction-layer`) — adds `kvpress`-based token eviction
  (SnapKV-style and H2O-related selection) to test whether pruning KV tokens reduces
  real cache bytes and whether that converts into throughput.
- CSV-first: every plot regenerates from committed CSVs.

## Experiment

RTX 5060, `Qwen/Qwen2.5-1.5B-Instruct`, fp16, `seq_len` 512–4096, `batch_size` 1/4,
`max_new_tokens` 64, presses `SnapKVPress` and `ObservedAttentionPress`,
`compression_ratio` 0.5 / 0.75, vs a `dynamic` FullKV baseline. Plus a two-GPU
(5060 vs 5080) architectural comparison on a matched Qwen2.5-1.5B grid.

## Result

Token eviction delivers exactly the KV-byte reduction it promises and **does not buy
throughput**:

| Press | ratio | ok/total | OOM | measured KV reduction | tokens/s vs dynamic |
|---|---:|---:|---:|---:|---:|
| H2O-related `ObservedAttentionPress` | 0.5 | 5/8 | 3 | 50.0 % | 0.953× |
| H2O-related `ObservedAttentionPress` | 0.75 | 5/8 | 3 | 75.0 % | 0.980× |
| `SnapKVPress` | 0.5 | 7/8 | 1 | 50.0 % | 0.876× |
| `SnapKVPress` | 0.75 | 7/8 | 1 | 75.0 % | 0.921× |

Cutting 75 % of KV bytes made decoding **slower**, and peak memory went *up* — the
selection pass itself costs memory and compute at the point of compression. A capacity
win is not a performance win, which is the same lesson the NPU project reaches from
the other direction.

## Negative Result / Limitation

- Throughput never improved for any press or ratio measured.
- `kvpress 0.5.3` exposes no `H2OPress`; `ObservedAttentionPress` is used as the
  H2O-related press and the CSV records it as `press_type=h2o` — a naming compromise
  documented rather than hidden.
- RTX 5080 telemetry is incomplete and the quantized-backend does not match across
  GPUs, so the two-GPU comparison is bounded — stated in
  `docs/kv_cache_two_gpu_comparison.md`.
- Single model family at the headline; not a broad model sweep.
- **The RTX 5080 is not currently available to me**; 5080 numbers are archived prior
  measurements, not reproducible on demand in this setup.

## Reproducibility

`requirements.txt` + `run_kv_cache_bench.py` / `run_eviction_bench.py`; plots
regenerate from committed CSVs under `results/` via the `plot_*` scripts. Public
repository — clonable and runnable given a supported GPU.
