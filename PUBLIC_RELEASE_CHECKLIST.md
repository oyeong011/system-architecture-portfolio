# Public Release Checklist

**Status: NOT RELEASED. No repository has been made public as part of this work.**

`kv-asymmetry-npu`, `onnxim-kv-instrumented`, and `queue-aware-ftl-simulator` are
private and stay private until the owner explicitly approves each one. This file is
the pre-flight check to run *before* that decision, not a record that it was made.

## Automated scan

`scripts/public_release_scan.sh` (in this repo) greps a target repository for the
items below and exits non-zero on any hit. Run it per repository:

```bash
./scripts/public_release_scan.sh /path/to/repo
```

| # | Check | Why |
|---|---|---|
| 1 | API keys (`sk-`, `AKIA`, `AIza`, `xox[baprs]-`) | credential leak |
| 2 | GitHub tokens (`gh[pousr]_`, `github_pat_`) | account compromise |
| 3 | Hugging Face tokens (`hf_`) | account compromise |
| 4 | SSH private keys (`BEGIN * PRIVATE KEY`) | host compromise |
| 5 | Absolute home paths (`/home/<user>/`, `C:\Users\`) | leaks username + machine layout |
| 6 | Hard-coded internal hostnames / IPs (e.g. the lab simulator host) | exposes internal infrastructure |
| 7 | `.env`, `*.pem`, `*.key`, `credentials*` files | credential leak |
| 8 | Files > 25 MB | repo bloat; also often accidental data dumps |
| 9 | Unpublished paper PDFs / proprietary datasets | licensing and embargo |
| 10 | Model weights, Docker cache, build artifacts | bloat, sometimes licensing |
| 11 | Third-party code without its license header | licensing |

## Manual review — the scan cannot decide these

- [ ] **Lab / advisor consent.** The NPU work uses a lab simulator host and a research
      direction that may be embargoed or intended for submission. Making
      `kv-asymmetry-npu` or `onnxim-kv-instrumented` public is a **research-group
      decision, not a portfolio decision**, and must be asked before any release.
- [ ] **Upstream fork hygiene.** `ONNXim` is a fork of PSAL-POSTECH/ONNXim. Confirm the
      upstream license is honored and the fix branch is attributed as a contribution,
      not presented as original work.
- [ ] **Anything that reads as an unpublished result.** Negative results and new
      observations (the metadata-traffic finding) may be material the lab wants to
      publish first.
- [ ] **Recruiter access without public release.** For an application, a private repo
      shared by invite, or an exported PDF, gives the reviewer what they need without
      a public release. Prefer this.

## Known items to fix before any release

| Item | Where | Action |
|---|---|---|
| Absolute paths `/home/oy/...` | `experiments/p0b_sec3d/run.sh` manifests, some audit docs | replace with repo-relative paths |
| Internal host `203.253.25.244` / `npu-sim` | audit docs, STATUS files | replace with a generic "lab simulator host" |
| 60–85 MB trace CSVs | `queue-aware-ftl-simulator/results/raw/exp1_bursty_seed0.csv` | traces are regenerable from seed + manifest; drop from a public snapshot rather than rewriting history in the private repo |
| Docker image names/ids | NPU reproduce scripts | fine to keep — they are local build tags, but the Dockerfile must ship with them to be meaningful |

## Release decision log

| Repo | Current visibility | Requested public? | Approved by owner? | Date |
|---|---|---|---|---|
| `queue-aware-ftl-simulator` | private | no | — | — |
| `kv-asymmetry-npu` | private | no | — | — |
| `onnxim-kv-instrumented` | private | no | — | — |
| `system-architecture-portfolio` (this) | local only | no | — | — |
| `kv-cache-consumer-gpu-bench` | already public | n/a | — | — |
| `memory-hierarchy-experiment-framework` | already public | n/a | — | — |

No row moves to "approved" without an explicit instruction from the owner.
