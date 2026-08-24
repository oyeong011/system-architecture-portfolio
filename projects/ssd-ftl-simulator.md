# Queue-Aware FTL Simulator

Repo: [`oyeong011/queue-aware-ftl-simulator`](https://github.com/oyeong011/queue-aware-ftl-simulator) (private) · commit `a657bcc` · C++17 / CMake / CTest / Python

## Problem

Garbage collection is the SSD's self-inflicted tail-latency problem. When free
blocks run out, the FTL must copy valid pages and erase a block *while the host is
waiting* — and the host sees it as a p99 spike, not as "GC". The usual mitigation is
background GC on a free-space threshold, but a background GC that fires while the
host is busy just moves the stall around, and every page it copies is write
amplification the host pays for in endurance.

**The question:** can GC that reads the *host queue state* — running only when the
device is idle — cut GC-induced tail latency without inflating write amplification
unacceptably?

This is a trade-off question, so every result is reported as a pair: a tail-latency
number **and** a WAF number. Lowering p99 by paying unbounded WAF is not an answer.

## My Role

Wrote the entire simulator, tests, workload generator, experiment harness, and
analysis. No existing SSD simulator was copied or forked — the point was to model
the mapping/GC/NAND path myself rather than drive someone else's model.

## Implementation

```
HostWorkload (trace CSV)
  → HostQueue        bounded by queue_depth, accrues queue wait
  → FTL              L2P/P2L page-level map, page state table,
                     per-channel write frontier, out-of-place update,
                     old-page invalidation, GC policy
  → NANDModel        channel / die / block / page, per-channel busy-until clocks,
                     t_read 50µs · t_program 600µs · t_erase 3ms
  → MetricsCollector latency percentiles, WAF, GC counters, stall, erase stats
```

~330 lines of core FTL (`src/Ftl.cc`), deliberately small. The one architectural
decision that matters: **GC reads `outstanding_io` from the queue.** Foreground and
fixed-background policies do not — they see only free-page ratio. That extra input
is the whole hypothesis.

The three policies share one critical-threshold safety valve and differ only in when
*background* GC is permitted:

```
while free_pages(channel) == 0 or free_ratio(channel) <= critical:
    force GC now                       # host stalls behind it → gc_induced_stall_ns

if free_ratio(channel) <= background:
    A foreground:       never
    B fixed_background: always
    C queue_aware:      only if outstanding_io <= low_queue_threshold
```

The free-ratio check is **per channel**, not global — free blocks never migrate
between channels, so a global ratio can look healthy while one channel is starved.

## Experiment

| # | Variable | Values | Metrics |
|---|---|---|---|
| 1 | GC policy × seed | 3 policies × seeds 0–4 | p99, WAF, GC stall |
| 2 | Queue depth | 1, 4, 16, 32 | throughput, queue wait, p99 |
| 3 | Over-provisioning | 7 %, 14 %, 28 % | WAF, GC count, p99 |
| 4 | Locality | uniform random vs hot/cold | pages moved, WAF, p99 |

Workload: `bursty_write` — uniform-random writes at 3× overwrite pressure with
periodic ~20 ms idle gaps. The idle gaps are load-bearing and stated as such: without
an idle window, a queue-aware policy cannot differ from foreground by construction.

Traces are fully determined by `(pattern, capacity, count, working-set, qd, seed)`,
so ~90 MB traces are regenerated from six values rather than stored.

## Result

**Experiment 1 — 5 seeds, paired per-seed deltas (queue-aware vs foreground):**

| Metric | mean | σ | per-seed |
|---|---:|---:|---|
| p99 latency | **−4.35 %** | 2.10 % | −5.07, −2.35, −4.56, −7.38, −2.40 |
| GC-induced stall | **−12.95 %** | 0.23 % | −12.91, −12.59, −13.04, −13.03, −13.20 |
| WAF (cost) | **+4.15 %** | 0.10 % | +4.12, +3.98, +4.17, +4.23, +4.24 |

Queue-aware wins on **every seed**, and the stall reduction and WAF cost are tight
(σ ≈ 0.1–0.2 %). The p99 magnitude is **not** tight — σ is half the mean — so the
claim I make is *"consistently lower p99, magnitude workload-dependent"*, not
"5 % faster". That distinction is the result.

**Fixed-threshold background GC is catastrophically worse** (WAF 33.3 vs 1.91,
p99 25× worse): GC'ing on a schedule regardless of queue state causes runaway
self-inflicted amplification. Its reported `gc_induced_stall_ns = 0` is a metric
artifact — that counter measures only *host-blocking* GC — and is called out as
such rather than presented as a win.

**Experiments 2–4** (single seed, directional): throughput saturates at
queue_depth = 4 = channel count; WAF falls monotonically with OP
(2.63 → 1.91 → 1.35 at 7/14/28 %); locality sharply reduces GC pressure.

## Negative Result / Limitation

- Experiment 3's first run had a real methodological bug — the same trace was reused
  across OP levels, but OP only gates LBA validity, not physical reservation. Caught,
  fixed by generating per-OP traces, rerun.
- Experiment 4's uniform-vs-hot/cold comparison is **not matched**: hot_cold is 50/50
  R/W while the uniform baseline is pure write, so part of the WAF gap is write count,
  not locality. Stated in the README rather than quoted as a locality result.
- Only Experiment 1 is swept over seeds. One workload pattern, one NAND geometry.
- No wear leveling, ECC, bad-block handling, or power-loss recovery.
- Single-request-granularity timing understates intra-request pipelining.
- **Every number is simulator output.** No physical NVMe or SATA device was measured,
  and NAND timing parameters are nominal, not device-derived. The invariants verify
  internal consistency, not physical accuracy.

## A bug worth naming

The first Experiment 1 run crashed with `NAND full`. Root cause: `checkAndRunGc`
compared a **global** free-page ratio while free blocks are partitioned per channel —
one channel could be exhausted while the global ratio looked fine. Fixed in the one
shared function all three policies route through, and a per-channel-sum invariant was
added so the same class of drift fails in `ctest` instead of in an experiment.

## Reproducibility

```bash
./experiments/reproduce_core.sh --mode smoke   # 3.6 s    clean build + 12 invariants + one run
./experiments/reproduce_core.sh --mode core    # 1.2 min  + Exp1 over 5 seeds + figures
./experiments/reproduce_core.sh --mode full    # + Exp2/3/4 (not timed end-to-end)
```

Each mode rebuilds from scratch, runs `ctest`, prints the binary sha256 and git
commit, regenerates traces from seeds, and writes raw CSVs plus a manifest
(`results/manifests/exp1_multiseed.json`) recording generator args, seeds, and
config sha256s.

`--mode core` was executed from a cleared scratch directory and reproduced the
committed `exp1_bursty_multiseed.csv` and `exp1_multiseed_summary.csv`
**byte-for-byte** — so trace generation is stable across runs, not just the simulator.
Running the command end-to-end (rather than the steps it wraps) is also what caught a
wrong runtime figure in the README and two latent bugs in `--mode full`; both fixed in
`0e5cd6d`.

**12 invariants** (`ctest --test-dir build --output-on-failure`), including:
L2P/P2L bijection, free+valid+invalid = total, per-channel free sums, overwrite
invalidation, GC data preservation, WAF = 1.0 without GC, `nand_writes ≥ host_writes`
under GC, **bit-exact determinism for the same seed+config**, queue-depth bounding,
forward progress at critical pressure, explicit failure on invalid LBA. The `CHECK`
macro counts failures instead of aborting, so a pass means all 12 actually ran.
