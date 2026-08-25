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

## Scan results — 2026-08-25

`scripts/public_release_scan.sh` run against all three repositories at their pushed commits.

| Repo | Commit | Result | Findings |
|---|---|---|---|
| `system-architecture-portfolio` | `d47fbb8` | **CLEAN** | none |
| `queue-aware-ftl-simulator` | `5d7c4d4` | 1 category | 5 trace CSVs, 64–87 MB each, tracked in git |
| `kv-asymmetry-npu` | `5b93805` | 1 category | 11 references to the lab host alias `npu-sim` and `~/research/npu-sim/...` paths |

Explicitly checked and **not** found in any repo: API keys, GitHub/HF tokens, private
keys, credential-shaped files, model weights, binaries, archives, real IP addresses,
`/home/<username>/` absolute paths.

### What each finding actually is

- **FTL trace CSVs (~388 MB total).** Not sensitive — synthetic workload traces. The
  problem is bloat: they are regenerable from six values recorded in
  `results/manifests/exp1_multiseed.json`, so a public snapshot should not carry them.
  They must **not** be removed by rewriting history in the private repo (§11).
- **NPU host references.** No IP address and no username leaks; what leaks is the lab's
  internal host alias and directory layout. Low severity, but it is lab infrastructure
  detail, not the applicant's to publish.

## Known items to fix before any release

| Item | Where | Action | Blocks which repo |
|---|---|---|---|
| Lab host alias `npu-sim`, `~/research/npu-sim/...` paths | `audit/*.md`, `reports/*.md`, `sim/scripts/*.py` (11 hits) | replace with "lab simulator host" / repo-relative paths | `kv-asymmetry-npu` |
| 5 trace CSVs, 64–87 MB | `queue-aware-ftl-simulator/results/raw/` | publish a snapshot without them (regenerable from the manifest); do **not** rewrite history in the private repo | `queue-aware-ftl-simulator` |
| Docker image tags/ids | NPU reproduce scripts | keep — local build tags, meaningful only alongside the shipped Dockerfile | — |

## Recommended disclosure order

Portfolio review does not require publishing everything. Narrowest sufficient path:

1. **`system-architecture-portfolio` first.** Scan is clean, it is the document a reviewer
   actually reads, and it links out rather than containing research artifacts. Publishing
   only this exposes nothing from the lab.
2. **`queue-aware-ftl-simulator` second, as a fresh snapshot.** It is entirely the
   applicant's own work with no lab dependency; the only blocker is size, and a snapshot
   without the trace CSVs clears it. This is the repo that best shows C++/testing/
   experiment-design ability.
3. **`kv-asymmetry-npu` — do not publish.** Beyond the host references, it carries lab
   research direction, negative results, and a new observation the group may want to
   publish first. Share by private invite if a reviewer asks. This is a research-group
   decision, not a portfolio one.

For a reviewer who wants to see the NPU work without a public repo: the project card
(`projects/npu-kv-architecture.md`) and `pdf/portfolio.pdf` carry the full narrative,
the numbers, and the reproduction commands.

## Release decision log

| Repo | Current visibility | Requested public? | Approved by owner? | Date |
|---|---|---|---|---|
| `queue-aware-ftl-simulator` | **private** | no | **explicitly held — owner: "public 전환 = 아직 금지"** | 2026-08-25 |
| `kv-asymmetry-npu` | **private** | no | **explicitly held** — lab host config/trace included | 2026-08-25 |
| `onnxim-kv-instrumented` | **private** | no | not requested | — |
| `system-architecture-portfolio` (this) | **private** (remote created 2026-08-25) | no | **explicitly held** | 2026-08-25 |

Private pushes on 2026-08-25 were approved and completed; **no visibility was changed
and none may be without a further explicit instruction.** Note that private→public on
GitHub also exposes Actions history and enables forking, and anything that has been
public in git history is not fully retractable by deleting the file later.
| `kv-cache-consumer-gpu-bench` | already public | n/a | — | — |
| `memory-hierarchy-experiment-framework` | already public | n/a | — | — |

No row moves to "approved" without an explicit instruction from the owner.
