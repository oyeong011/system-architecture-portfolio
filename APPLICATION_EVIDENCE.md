# Application Evidence Index

Every claim made anywhere in this portfolio, with its raw evidence file, the command
that produces it, and a verification status. Nothing is quoted in the README or the
PDF that does not have a row here.

**Statuses:** `verified-current` (rerun in the current environment, raw log in-tree) ·
`verified-historical` (real prior measurement, raw file present and checked, not
rerun) · `documented-not-rerun` (recorded in a document, raw file not re-checked) ·
`unsupported` (claimed but no evidence found — kept visible) · `failed`.

## NPU — KV asymmetry / instrumented ONNXim

| Claim | Repo | Commit | Raw evidence | Reproduction | Status |
|---|---|---|---|---|---|
| Shared dequant baseline (demand 80:40, T=128:128) = **33,267,145 cycles** | kv-asymmetry-npu | `f47e57f` | `results/raw/p0b_sec3d_A.log` — final per-core `Total cycle`, container `npusim/onnxim:phase0b-kvfix-clean` | `./scripts/reproduce_portfolio_core.sh --mode core` | **verified-current** — reran this session, matched the archived value exactly |
| Demand-proportional split (85:43) = **33,501,237 cycles**, **+0.70 %** vs shared | kv-asymmetry-npu | `f47e57f` | `results/raw/p0b_sec3d_p3.log`; archive `audit/p0b_result.md:1153` | `--mode core` | **verified-current** — reran this session, matched the archived value exactly |
| Full 7-point misallocation sweep (+130.9 % … +158.2 %) | kv-asymmetry-npu | `df079b5` | `audit/p0b_result.md` §3-d table | `--mode full` (8 runs × ~6 min) | `verified-historical` — configs `sim_config_3d_p1..p7` present and runnable, full sweep not rerun |
| Optimal split = demand ratio, holds at 1:1 / 2:1 / 3:1 | kv-asymmetry-npu | `df079b5` | `audit/p0b_result.md` §3-e | configs `sim_config_3e_*` present | `verified-historical` |
| Mode-switch break-even ≈ 0.77 % (opt-125m) / 1.18 % (llama3-8b), dimensionless | kv-asymmetry-npu | `df079b5` | `audit/p0b_result.md:1196` — exact grep match against README | configs `sim_config_3f_p*` present | `verified-historical` |
| Switch rate 98.4 % (llama3-8b) / 65.6 % (opt-125m) — contradicts the "switches are rare" assumption | kv-asymmetry-npu | `df079b5` | `audit/p0b_result.md` §3-f table | — | `verified-historical` |
| W-INT4 batch 64 DRAM traffic: weight 21.3 % / KV payload 52.4 % / **KV metadata 26.3 %** | kv-asymmetry-npu | `df079b5` | `audit/p3_metadata_result.md:306` — exact grep match | `sim_config_p3bits_4.json` present | `verified-historical` |
| K/V structural byte symmetry, R_m(B0) = 1.000 | onnxim-kv-instrumented | `511a52a` | `audit/p2_result.md` | not rerun | `documented-not-rerun` |
| `kv_head_idx` GQA/MHA mapping bug found, fixed, reported upstream | onnxim-kv-instrumented + ONNXim fork | `511a52a` / `69e6189` | both commits confirmed present via `git log` on the lab host | — | `verified-historical` — **issue URL not independently re-queried**; the code fix is confirmed, the filing is not |
| Instrumented ONNXim builds and runs end-to-end producing cycle-level DRAM stats | kv-asymmetry-npu | `844f094` | `results/raw/smoke-2026-08-24.log` — exit 0, 1282 tiles, HBM2 engaged, 55.15 s | `--mode smoke` | `verified-current` |
| HBM/bandwidth sensitivity results | — | — | none — deliberately not run | — | not claimed (future work) |
| Accuracy/quality impact of the quantization schemes | — | — | none | — | not claimed (incomplete track) |

## SSD — Queue-Aware FTL Simulator

| Claim | Repo | Commit | Raw evidence | Reproduction | Status |
|---|---|---|---|---|---|
| Queue-aware vs foreground, 5 seeds: p99 **−4.35 % ± 2.10**, GC stall **−12.95 % ± 0.23**, WAF **+4.15 % ± 0.10** | queue-aware-ftl-simulator | `a657bcc` | `results/raw/exp1_bursty_multiseed.csv` → `results/processed/exp1_multiseed_summary.csv`; manifest `results/manifests/exp1_multiseed.json` | `./experiments/reproduce_core.sh --mode core` | **verified-current** |
| Fixed-threshold background GC is 25× worse on p99, WAF 33.3 | queue-aware-ftl-simulator | `a657bcc` | same multiseed CSV | same | **verified-current** |
| Throughput saturates at queue_depth = 4 = channel count | queue-aware-ftl-simulator | `46fa966` | `results/processed/exp2_queue_depth_sweep.csv` | `--mode full` | `verified-current` — single seed |
| WAF falls monotonically with OP: 2.63 → 1.91 → 1.35 (7/14/28 %) | queue-aware-ftl-simulator | `46fa966` | `results/processed/exp3_op_sweep.csv` | `--mode full` | `verified-current` — single seed |
| hot/cold locality lowers WAF (1.02 vs 1.91) | queue-aware-ftl-simulator | `46fa966` | `results/processed/exp4_locality.csv` | `--mode full` | **verified-current, caveated** — not a matched A/B (hot_cold is 50/50 R/W vs pure-write baseline); part of the gap is write count |
| 12 invariants pass, including bit-exact per-seed determinism | queue-aware-ftl-simulator | `a657bcc` | `ctest` output; `tests/test_invariants.cc` | `ctest --test-dir build --output-on-failure` | **verified-current** |
| Clean-build reproduction in 3.6 s (smoke), 1.2 min (core) | queue-aware-ftl-simulator | `5d7c4d4` | timed runs this session | `--mode smoke` / `--mode core` | **verified-current** |
| The public snapshot reproduces every published number with **no trace files tracked** | queue-aware-ftl-simulator-public | `d21a0ec` | standalone checkout, cleared scratch: raw + summary CSVs byte-identical to committed, git tree clean after the run | `./experiments/reproduce_core.sh --mode core` | **verified-current** |
| Any statement about physical NVMe/SATA SSD performance | — | — | none — no NVMe device in this setup | — | **not claimed anywhere** |

## GPU — KV-cache consumer benchmark

| Claim | Repo | Commit | Raw evidence | Reproduction | Status |
|---|---|---|---|---|---|
| Token eviction at 50 %/75 % compression reduces KV bytes as advertised but gives 0.88–0.98× throughput (slower) and higher peak memory | kv-cache-consumer-gpu-bench | `0fbc048` | README summary table + `results/*.csv` | `run_eviction_bench.py` | `documented-not-rerun` — README table read this session; underlying CSVs not re-aggregated |
| RTX 5060 vs 5080 architectural comparison | kv-cache-consumer-gpu-bench | `0fbc048` | `docs/kv_cache_two_gpu_comparison.md` | — | `documented-not-rerun` — **RTX 5080 not currently available**; 5080 telemetry incomplete by the repo's own admission |

## CPU/memory — supporting

| Claim | Repo | Commit | Raw evidence | Reproduction | Status |
|---|---|---|---|---|---|
| Cache/TLB/blocking effects measured with `perf` on Linux | memory-hierarchy-experiment-framework | HEAD | `report/`, `docs/` | `make` + `scripts/` | `documented-not-rerun` |
| RV32I single-cycle CPU passes a self-written testbench | cose222-rv32i-final-project | — | testbench output | Verilog sim | `documented-not-rerun` — pipelined version incomplete |
| `oaken` fork contains original work | — | — | none found — repo is a fork, not located cloned anywhere | — | **unsupported** — excluded from the portfolio project list until checked |

## Standing caveats

1. **Everything storage-related is a simulator.** No NVMe or SATA device was read from
   or written to in this work.
2. **The RTX 5080 is not currently available.** Any 5080 number is archived.
3. `verified-historical` means the raw file exists and the quoted number matches it —
   not that it was recomputed.
4. Where a rerun contradicts an archived number, the discrepancy is recorded rather
   than the archive being silently re-anchored.
