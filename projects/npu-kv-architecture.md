# KV Asymmetry on an NPU — Instrumented ONNXim

**Repositories: private — available on request.** The work was done in a research-group
environment on a shared simulator host; the repositories carry lab configuration and
research material, so they are shared by invitation rather than published. Everything
needed to evaluate the work is in this document.

| | |
|---|---|
| Reproducibility status | **Verified** — both headline points rerun and matched exactly |
| Shared baseline (T = 128:128) | **33,267,145 cycles** |
| Split 85:43 (= demand ratio) | **33,501,237 cycles** (+0.70 %) |
| Reproduction command | `./scripts/reproduce_portfolio_core.sh --mode core` (~12 min) |
| Upstream contribution | ONNXim fork, branch `fix/kv-head-idx-gqa-mapping` @ `69e6189` |

Internal references: `kv-asymmetry-npu` @ `5b93805` (branch `portfolio-hardening`),
`onnxim-kv-instrumented` @ `bd1f344` (branch `phase0b-dequant`), fork of
[PSAL-POSTECH/ONNXim](https://github.com/PSAL-POSTECH/ONNXim).

## Problem

In a quantized LLM, the KV cache is not one uniform blob. K and V are produced,
consumed, and re-read on different schedules, and each carries per-group quantization
**metadata** alongside its payload. If K and V place structurally different demands on
the dequantization engine, then a **single shared dequant engine is the wrong
allocation** — you would want to split it into separately sized K and V units.

**Research question:** do K and V differ enough in dequantization resource demand to
justify splitting the dequant engine, and if so, how sharply must the split be sized?

## My Role

Extended a third-party cycle-level NPU simulator (ONNXim, C++) to be able to answer
this at all: it had no dequantization model, no K/V-separated counters, and no
provenance logging. I added those, designed and ran the sweeps, analyzed the results,
and wrote up the rejection of my own proposal. I also found and fixed a correctness
bug in upstream ONNXim in the process.

## Implementation

| Change | File | What it does |
|---|---|---|
| Throughput-based dequant cost model | `src/SystolicWS.cc` | `dequant_cycles = ceil(size_bytes / throughput_B_per_cycle)`, distinct from the existing per-element latency switch |
| Shared vs split engine | `src/SystolicWS.cc` | `dequant_mode ∈ {disabled, shared, split}`; split gives K and V independent throughput budgets |
| Mode-switch penalty | `src/SystolicWS.cc`, `src/Core.h` | configurable `dequant_mode_switch_penalty_cycles` + switch counter, so the cost of alternating K/V on a shared engine is measurable rather than assumed |
| K/V-separated counters | `src/Core.h`, `src/Core.cc` | active / stall cycles and issue counts, split by K and V |
| Config plumbing | `src/Common.cc`, `src/SimulationConfig.h` | `dequant_mode`, `k_/v_dequant_throughput`, `k_/v_dequant_demand_multiplier` |
| Dequant issue points | `src/operations/Attention.cc` | K path (QK) and V path (PV) issue dequant work at the right places in the attention dataflow |
| Provenance logging | `src/main.cc` | every run logs its config path and dequant parameters, so a log identifies the run that produced it |

**A trap I had to design around**: ONNXim's opcode switch silently returns **0 cycles**
for an unmatched opcode. Adding `DEQUANT` to the enum without a matching case would
have produced a clean, plausible, and completely wrong "no cost" simulation. This is
why the work carries regression anchors against `dequant_mode=disabled` rather than
trusting that the model is wired in.

## Experiment

Main workload: `llama3-8b-1L-proxy_single`, context 4096, batch 16, systolic WS
128×128, 4 cores, HBM2 via ramulator2. Sweeps:

- **A/B/C comparison** — shared engine (T = 128:128) vs neutral split (64:64) vs
  demand-proportional split.
- **Misallocation sensitivity** (§3-d) — 7-point sweep of the K:V throughput split at
  fixed demand 80:40: 110:18, 96:32, **85:43**, 74:54, 64:64, 43:85, 32:96.
- **Demand-ratio generality** (§3-e) — repeats at demand ratios 1:1, 2:1, 3:1.
- **Mode-switch break-even** (§3-f) — penalty sweep to find where split starts to win.
- **Metadata traffic decomposition** (P3) — DRAM traffic split into weight / KV
  payload / KV metadata across weight bit-widths and batch sizes.

## Result

**The proposal was rejected by its own experiment.** A correctly sized split lands
within ~0.7–1.2 % of a shared engine:

| Condition (demand 80:40, T = 128) | Total cycles | vs shared |
|---|---:|---:|
| shared 128:128 | 33,267,145 | — |
| split 110:18 | 76,810,724 | +130.9 % |
| split 96:32 | 44,122,913 | +32.6 % |
| **split 85:43 (= demand ratio)** | **33,501,237** | **+0.70 %** |
| split 74:54 | 38,209,118 | +14.9 % |
| split 64:64 | 43,878,368 | +31.9 % |
| split 32:96 | 85,904,231 | +158.2 % |

Three things fall out of this:

1. **The optimum is exactly the demand ratio**, and it holds at 1:1, 2:1, and 3:1 —
   the rule is not an artifact of one configuration.
2. **The curve is brutally sharp and asymmetric.** Being wrong by one sweep step costs
   15–33 %; being wrong in the K-heavy direction costs more than the V-heavy direction.
   A split engine must be sized for a demand ratio that shifts with model and workload —
   it buys ≤ 1 % in the best case and loses 30 %+ when the workload moves.
3. **Break-even needs an implausible switch cost.** For split to win, the shared
   engine's mode-switch penalty would have to reach ~0.8–1.2 % of the work done between
   switches (dimensionless; converges across two models). That is far beyond a datapath
   mux reconfiguration.

**Verification status — both headline points were rerun this session** in the
`npusim/onnxim:phase0b-kvfix-clean` container and reproduced **exactly**:

| Condition | Rerun | Archived anchor | Verdict |
|---|---:|---:|---|
| shared 128:128 | 33,267,145 | 33,267,145 | exact match |
| split 85:43 | 33,501,237 | 33,501,237 | exact match |
| delta | +0.70 % | +0.70 % | match |

Raw logs: `results/raw/p0b_sec3d_{A,p3}.log` · summary `p0b_sec3d_summary.csv`.
`./scripts/reproduce_portfolio_core.sh --mode core` (~12 min) was then run **as written**
and printed `[REPRODUCED]` for both points, with the same cycle counts as the manual
runs — so the simulation is deterministic across invocations, not only within one.

A prior pass had recorded this experiment's original invocation as lost. It was not:
all eight §3-d sim configs were still on the lab host, together with the model json,
the models_list, and the 274-byte trace. All of it is now committed under
`experiments/p0b_sec3d/`, so the reproduction is self-contained. If a rerun ever
disagrees with an anchor, the script reports a `DISCREPANCY` rather than re-anchoring
to the new value.

## Negative Result / New Observation

The rejection is the headline, and the follow-on observation is the more interesting
part: at **INT4 weights, batch 64**, DRAM traffic decomposes as

- weights **21.3 %**
- KV payload **52.4 %**
- **KV metadata 26.3 %**

**Quantization metadata moves more bytes than the weights do.** Push quantization
harder and finer-grained and this term grows, not shrinks — the bookkeeping that makes
the payload small becomes the next bottleneck. That is a research question the original
hypothesis was not even asking.

A second correction the data forced: my prior assumption that mode switches are rare
(so a shared engine batches K and V work) is **wrong** — measured switch rate is 98.4 %
of dequant events on llama3-8b, i.e. nearly every event alternates. The shared engine
still wins, but not for the reason I assumed.

## Upstream Contribution

Found a **`kv_head_idx` GQA/MHA mapping bug** in upstream ONNXim: head indices were
computed in a way that breaks for multi-head attention (worst case: full head collapse
on a 12-head MHA model). Fixed on branch `fix/kv-head-idx-gqa-mapping` @ `69e6189` and
reported upstream.

This mattered internally too: a spot check on the bugged build showed C vs A at
+6.53 %, over the 5 % significance threshold — which would have *supported* the split
proposal. Rerunning the affected sections on the fixed build brought it back to +1.13 %
and killed the proposal. **The bug had been flattering my own hypothesis.**

## Limitations

- The dequant model is an **in-place cost stub**, not a full dequantization datapath —
  it models timing and traffic, not the arithmetic.
- Single-layer proxy models (`*-1L-proxy`), not full-depth networks.
- §3-a/§3-b and §1/§2 numbers were measured on the pre-`kv_head_idx`-fix build and are
  labeled as such; only the A/B/C-critical sections were rerun on the fixed build.
- Absolute break-even penalty values are workload-scale-dependent and are quoted only
  as the dimensionless ratio; the raw P* numbers live in an appendix.
- **The accuracy track is incomplete** — this work measures cycles and traffic, not
  model quality under the quantization schemes involved.
- HBM/bandwidth sensitivity was scoped and **deliberately not run**: adding a fake
  bandwidth multiplier would have produced numbers with nothing behind them. Left as
  future work.

## Reproducibility

```bash
# on the lab simulator host, in kv-asymmetry-npu:
./scripts/reproduce_portfolio_core.sh --mode smoke   # image + binary run end-to-end
./scripts/reproduce_portfolio_core.sh --mode core    # shared baseline + 85:43 split, vs anchors
./scripts/reproduce_portfolio_core.sh --mode full    # full 8-point §3-d sweep
```

`experiments/p0b_sec3d/` carries the exact sim configs (`sim_config_3d_A`,
`sim_config_3d_p1..p7`), the model json, the models list, and the trace — all of them
small — plus a `run.sh` that logs image id and input sha256s before every run. Runtime:
~6 minutes per point on the lab host.
