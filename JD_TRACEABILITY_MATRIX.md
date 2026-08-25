# JD Traceability Matrix — SK hynix SYSTEM SW

Every row maps a competency to a **specific file** and a **specific measurement**.
Where there is no evidence, the row says `not demonstrated` — blanks are not filled
with coursework or interest.

> **Which job description these rows came from.** The competency rows below were derived
> from SK hynix's **Solution SW** job description, which is why storage-firmware items
> (PCIe/NVMe, Firmware/FTL, FTL/NAND) appear as rows at all. The 2027 전기 Korea
> University 반도체시스템공학과 posting names the track **SYSTEM SW**, and its own
> requirement text was not available when this matrix was written. The rows are therefore
> a competency map I can evidence, not a line-by-line trace of the SYSTEM SW posting —
> saying otherwise would be the kind of unsupported claim the rest of this repository
> refuses to make. Rows are ordered by how central they are to a memory/storage systems
> role, not by the original JD's order.

Verification statuses: `verified-current` (rerun now, raw log in-tree) ·
`verified-historical` (real prior measurement, raw file present, not rerun) ·
`documented-not-rerun` · `unsupported` · `failed`.

---

| Competency | Project evidence | Specific file / code | Measured result | Limitation |
|---|---|---|---|---|
| **AI workload analysis** | KV Asymmetry on NPU | `audit/p3_metadata_result.md`; DRAM traffic decomposition by weight / KV payload / KV metadata | At W-INT4, batch 64: weight 21.3 %, KV payload 52.4 %, **KV metadata 26.3 %** — metadata traffic exceeds weight traffic | `verified-historical`; one model family, proxy layer counts |
| | KV-cache GPU Benchmark | `run_eviction_bench.py`, `results/*.csv` | 75 % KV-byte reduction → 0.92× throughput (slower); peak memory *up* | Single model family; 5080 telemetry incomplete |
| **Memory / data movement** | KV Asymmetry on NPU | `audit/p0b_result.md` §3-d 7-point allocation sweep | Optimal split = demand ratio; misallocation penalty is steep and asymmetric (+0.70 % at optimum → +158 % at worst point) | `verified-current` — shared baseline and 85:43 split both reran and matched exactly this session |
| | FTL simulator | `src/Ftl.cc` GC copy-forward path | WAF 2.63 → 1.91 → 1.35 across OP 7/14/28 % | Single seed for the OP sweep |
| **SSD / system architecture** | Queue-Aware FTL Simulator | `src/Ftl.cc`, `include/ftlsim/*.h` | Page-level FTL + per-channel NAND + 3 GC policies, 12 invariants; queue-aware cuts GC stall 12.95 % ± 0.23 at +4.15 % ± 0.10 WAF | `verified-current`; **simulator, not a device** |
| **Firmware / FTL** | Queue-Aware FTL Simulator | L2P/P2L mapping, out-of-place update, invalidation, free-page allocator, greedy victim selection, over-provisioning | 12 invariants pass; bit-exact determinism per seed | No wear leveling, ECC, bad-block, or power-loss recovery — explicitly out of scope |
| **FTL / NAND** | Queue-Aware FTL Simulator | `NandGeometry`: channel/die/block/page, t_read 50 µs / t_program 600 µs / t_erase 3 ms | Throughput saturates at queue_depth = channel count (4) | NAND timings are nominal, not device-measured |
| **Reproducibility & verification** | Both projects | `results/manifests/*.json` (generator args, seeds, config sha256), `reproduce_core.sh --mode smoke\|core\|full`, provenance logging in the simulator binary | Same seed + config reproduces bit-identical metrics (enforced by a test) | NPU `--mode full` (28-run sweep) not yet executed |
| **C / C++** | FTL simulator | `src/Ftl.cc` (~330 lines), `include/ftlsim/*.h`, `tests/test_invariants.cc` (215 lines), C++17, CMake, CTest | Clean build + 12/12 invariants from scratch in 3.6 s | Single-threaded; no advanced C++ idioms exercised |
| | Instrumented ONNXim | C++ changes across `SystolicWS.cc`, `Core.cc/h`, `Common.cc`, `Attention.cc` | Modified a ~10k-line third-party C++ simulator without breaking its regression behavior | Modifications are targeted, not architectural |
| **Computer architecture / OS** | Instrumented ONNXim | `src/SystolicWS.cc` (dequant cycle model), `src/Core.h` (K/V-separated counters), `src/Common.cc` (config plumbing) | Dequant engine modeled as throughput-based (`ceil(bytes / B_per_cycle)`), shared vs split allocation, mode-switch penalty | `verified-historical`; in-place stub, not a full dequant datapath |
| | RV32I CPU (COSE222) | Verilog RTL + self-written `tb_cpu.v` | Single-cycle baseline passes the testbench; pipelining in progress | Supporting evidence only; pipelining incomplete |
| **Performance profiling** | Memory Hierarchy Framework | C microbenchmarks + `perf` automation + Python parsing | Cache-level bandwidth cliffs, TLB-miss growth, blocked-vs-naive GEMM gap | `documented-not-rerun` |
| | FTL simulator | `include/ftlsim/Metrics.h` | Full latency distribution (p50/p95/p99), queue wait vs device service time separated | Simulator-internal timing, not a profiler on real hardware |
| **Linux / system software** | Memory Hierarchy Framework | `scripts/`, `Makefile`, `perf` integration | Automated sweeps on Linux with hardware counters | `documented-not-rerun` |
| | Experiment infrastructure | `experiments/reproduce_core.sh`, `run.sh` provenance logging, Docker-based simulator runs over SSH | One-command clean-build → test → run → figure pipelines | — |
| **Python automation** | Both projects | `workloads/generator.py`, `analysis/aggregate_seeds.py`, `experiments/run_*.py`, `sim/scripts/analyze_p3.py` | Deterministic trace generation, multi-seed aggregation with σ, figure generation from raw CSV | Standard library + matplotlib only |
| **Open-source analysis** | ONNXim | Fork `fix/kv-head-idx-gqa-mapping` @ `69e6189`; instrumented branch commit `511a52a` | Found a **GQA/MHA `kv_head_idx` mapping bug** in upstream ONNXim, fixed it, filed upstream | Issue URL not independently re-queried this pass |
| **Verilog / SystemVerilog** | RV32I CPU (COSE222) | RTL + `tb_cpu.v` testbench | Single-cycle RV32I passes self-written testbench | Pipelined version incomplete; no synthesis/timing results |
| **PCIe / NVMe** | — | — | `not demonstrated` | No NVMe device in this setup; QEMU NVMe was scoped as a stretch goal and deliberately dropped in favor of finishing the simulator core |

---

## What this matrix deliberately does not claim

- **No NVMe/PCIe protocol experience.** There is no NVMe device here. The FTL work
  models the layer *below* NVMe (mapping, GC, NAND), not the interface itself.
- **No physical SSD measurement.** Every storage number is simulator output.
- **No CUDA/Triton kernel development.** The GPU work is benchmarking and analysis
  with PyTorch/HF, not custom kernels — adding a token kernel project to imply
  otherwise was considered and rejected.
- **The RTX 5080 is not currently available**; 5080 numbers are archived.
