# Data Movement–Aware System Architecture for AI Accelerators and Storage

**Oyeong Gwon** · Soongsil University, School of Computer Science (BS expected Feb 2027)
· Target role: SK hynix Solution SW — AI Memory / System Software

> I measure how the way data is *stored* and *moved* limits system performance —
> in an NPU's KV-cache path and in an SSD's host-queue-to-NAND path — by
> instrumenting simulators, running controlled experiments, and reporting what the
> data actually says, including when it kills my own hypothesis.

---

## The common question

Two projects, two different layers of the stack, one method:

| | NPU (main) | SSD (supporting) |
|---|---|---|
| **What moves** | LLM KV-cache: quantized payload + per-group metadata | Host I/O: LBA writes, GC page copies |
| **Through what** | dequantization engine → SRAM → HBM | host queue → FTL mapping → NAND channels |
| **What limits it** | DRAM traffic, dequant engine allocation, mode-switch cost | queue wait, GC-induced stall, write amplification |
| **Metric** | cycles, DRAM traffic composition, engine utilization | p99 latency, WAF, GC stall |
| **Tool** | instrumented ONNXim (C++, cycle-level) | FTL/NAND simulator I wrote (C++17, deterministic) |

**The question both ask:** *how does the storage format and movement path of data
create the bottleneck, and what instrumentation proves it?*

These are not one project. They share a method, not a codebase — and the method is
the point: turn an architectural intuition into a measurable quantity, instrument
the simulator until it can measure it, then let the measurement decide.

---

## Projects

### 1. KV Asymmetry on an NPU — instrumented ONNXim
**[projects/npu-kv-architecture.md](projects/npu-kv-architecture.md)** ·
Repositories: **private — available on request** · Reproducibility: **verified**
(shared baseline 33,267,145 cycles · split 85:43 33,501,237 cycles, +0.70 %)

Asked whether K and V in a quantized LLM KV-cache have different enough resource
demands to justify **splitting the dequantization engine** into separate K and V
units. Added a dequant model, K/V-separated counters, and provenance logging to
ONNXim; swept allocation ratios; and **rejected my own proposal** — a correctly
sized split lands within 0.7–1.2 % of a shared engine, which does not pay for the
hardware. The experiments then surfaced something I had not been looking for: at
INT4 weights and batch 64, **KV metadata traffic (26.3 %) exceeds weight traffic
(21.3 %)** — quantization metadata, not payload, becomes the next thing worth
attacking. Also found and reported a **GQA/MHA `kv_head_idx` mapping bug in
upstream ONNXim**.

### 2. Queue-Aware FTL Simulator
**[projects/ssd-ftl-simulator.md](projects/ssd-ftl-simulator.md)** ·
`queue-aware-ftl-simulator-public` — code, tests, configs, processed results, manifests
(the development repository with raw traces stays private)

Wrote a page-level FTL + per-channel NAND simulator from scratch in C++17 to ask
whether **GC that watches the host queue** can cut GC-induced tail latency without
blowing up write amplification. Three policies (foreground-greedy, fixed-threshold
background, queue-aware), 12 invariant tests, 5-seed sweep. Result: queue-aware
lowers p99 on every seed and cuts host-blocking GC stall by **12.95 % ± 0.23** for
a steady **+4.15 % ± 0.10** WAF cost — and I report the p99 effect as
direction-plus-range (2.4–7.4 %), not a single number, because σ is half the mean.

### 3. KV-cache Consumer GPU Benchmark
**[projects/gpu-kv-cache-benchmark.md](projects/gpu-kv-cache-benchmark.md)** ·
[`kv-cache-consumer-gpu-bench`](https://github.com/oyeong011/kv-cache-consumer-gpu-bench) (public)

Measured KV-cache memory pressure, latency degradation, and OOM boundaries for HF
causal LMs on consumer GPUs (RTX 5060 / 5080), including a token-eviction layer
(SnapKV / H2O-related presses). Explicitly *not* an accelerator paper reproduction —
it measures the pressure that motivates such work.

### 4. Memory Hierarchy Experiment Framework
**[projects/memory-hierarchy.md](projects/memory-hierarchy.md)** ·
[`memory-hierarchy-experiment-framework`](https://github.com/oyeong011/memory-hierarchy-experiment-framework) (public)

C microbenchmarks + `perf` automation for cache locality, TLB behavior, access
patterns, and matrix-blocking effects on Linux.

### Supporting: RTL / CPU microarchitecture
RV32I single-cycle → pipelined CPU in Verilog (COSE222), with a self-written
testbench and a passing single-cycle baseline. Included as evidence of
HW-side literacy, not as a headline project.

---

## How to read this portfolio

1. **[JD_TRACEABILITY_MATRIX.md](JD_TRACEABILITY_MATRIX.md)** — every Solution SW
   competency mapped to a specific file and a specific measurement, with
   `not demonstrated` written where there is no evidence.
2. **[APPLICATION_EVIDENCE.md](APPLICATION_EVIDENCE.md)** — every claim in this
   portfolio, its raw evidence file, and its verification status.
3. **[PORTFOLIO_KO.md](PORTFOLIO_KO.md)** / [pdf/portfolio.pdf](pdf/portfolio.pdf) — the
   Korean manuscript. 13 pages: a cover plus 12 content pages.
4. Then either project README.

## Why some repositories are private

The NPU work was carried out in a research-group environment, on a shared simulator host,
and it includes negative results and a new observation the group may want to publish
first. Those repositories therefore stay private and are available on request; what they
produced — the narrative, every number, the raw-evidence pointers, and the exact
reproduction commands — is documented here in full.

The SSD simulator is entirely my own work and is published as a code snapshot. Its
development repository stays private only because it tracks ~390 MB of workload traces;
those traces are regenerable from the seeds and arguments recorded in the published
manifests, so nothing needed to reproduce the results is missing from the public copy.

## Evidence policy

Every number in this portfolio is traceable to a raw log or CSV in a repository, at
a named commit, with the command that produced it. Claims carry one of five statuses:

| Status | Meaning |
|---|---|
| `verified-current` | rerun in the current environment; raw log in-tree |
| `verified-historical` | real prior measurement, raw file present, not rerun |
| `documented-not-rerun` | recorded in a document; raw file not re-checked |
| `unsupported` | claimed somewhere but no evidence found — kept visible, not deleted |
| `failed` | attempted and did not work |

**Simulator results are labeled as simulator results.** The SSD project models an
SSD; it does not measure one. There is no NVMe device in this setup, and no number
here is a measurement of physical SSD hardware.
