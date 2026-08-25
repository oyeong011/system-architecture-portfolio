# Public Release Checklist

**Status (2026-08-25): two repositories released, three held private.**

Released after the scans and verifications recorded below:
`system-architecture-portfolio` (this hub) and `queue-aware-ftl-simulator-public`.

Held private, indefinitely: `kv-asymmetry-npu`, `onnxim-kv-instrumented` (research-group
environment — releasing them is the group's decision, not a portfolio one), and
`queue-aware-ftl-simulator` (the FTL development history, superseded for public purposes
by the snapshot).

This file stays as the pre-flight check for any *future* release, and as the record of
how these two were cleared.

## Automated scan

`scripts/public_release_scan.sh` (in this repo) greps a target repository for the
items below and exits non-zero on any hit. Run it per repository:

```bash
./scripts/public_release_scan.sh /path/to/repo
```

**This file is written to be publishable.** It names *categories* of finding, never the
actual host alias, path, or credential pattern found — a checklist that quotes what it is
protecting defeats itself. The scanner's regexes live in `scripts/public_release_scan.sh`.

| # | Check | Why |
|---|---|---|
| 1 | API keys (`sk-`, `AKIA`, `AIza`, `xox[baprs]-`) | credential leak |
| 2 | GitHub tokens (`gh[pousr]_`, `github_pat_`) | account compromise |
| 3 | Hugging Face tokens (`hf_`) | account compromise |
| 4 | SSH private keys (`BEGIN * PRIVATE KEY`) | host compromise |
| 5 | Absolute home paths (`/home/<user>/`, `C:\Users\`) | leaks username + machine layout |
| 6 | Hard-coded internal hostnames / IPs | exposes internal infrastructure |
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
| `queue-aware-ftl-simulator` | `5d7c4d4` | 1 category | 6 trace CSVs, 5.5–89 MB, tracked in git — **resolved by the snapshot below** |
| [`queue-aware-ftl-simulator-public`](https://github.com/oyeong011/queue-aware-ftl-simulator-public) (snapshot, **now PUBLIC**) | `b6a30b6` | **CLEAN** | none — 972 KB clone |
| `kv-asymmetry-npu` | `5b93805` | 1 category | 11 references to the lab simulator host's alias and its internal directory layout |

Explicitly checked and **not** found in any repo: API keys, GitHub/HF tokens, private
keys, credential-shaped files, model weights, binaries, archives, real IP addresses,
`/home/<username>/` absolute paths.

### Snapshot verification — 2026-08-25

`queue-aware-ftl-simulator-public` was built as a standalone repository (fresh
`git init`, no remote) containing no trace files at all, and then verified **from inside
that checkout**, not as a subset of the parent working tree:

```
./experiments/reproduce_core.sh --mode core     # scratch dir cleared first
  clean build OK · ctest 12/12 OK
  p99 −4.35 % (sd 2.10) · GC stall −12.95 % (sd 0.23) · WAF +4.15 % (sd 0.10)
  results/raw/exp1_bursty_multiseed.csv        byte-identical to committed
  results/processed/exp1_multiseed_summary.csv byte-identical to committed
  git status after the run: clean
```

So the snapshot regenerates ~390 MB of input from the seeds in its own manifest and
reproduces every published number without carrying a single trace file. That is the
claim the exclusion rests on, and it is tested rather than asserted.

All six traces are excluded, including the 5.5 MB `exp2_mix70r30w_seed0.csv` — keeping
one while dropping five would read as an oversight rather than a decision. The 3.7 KB
`exp1_bursty_multiseed.csv` **is** kept: it is a metric-row CSV, not a trace, and it is
the raw evidence behind the headline claim.

No `LICENSE` file is included. Publishing portfolio code is not open-sourcing it —
without a license, copyright stays with the author and no reuse rights are granted.

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
| Lab simulator host alias and internal absolute paths | `audit/*.md`, `reports/*.md`, `sim/scripts/*.py` (11 hits) | replace with a generic "lab simulator host" and repo-relative paths | `kv-asymmetry-npu` |
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
| `queue-aware-ftl-simulator-public` | **PUBLIC** | yes | **approved & released** — snapshot verified standalone, scan CLEAN | 2026-08-25 |
| `system-architecture-portfolio` (this) | **PUBLIC** | yes | **approved & released** — scan CLEAN, no Actions history existed | 2026-08-25 |
| `queue-aware-ftl-simulator` | **private** | no | **held** — development history; the snapshot serves the public purpose | 2026-08-25 |
| `kv-asymmetry-npu` | **private** | no | **held** — research-group environment; group's decision | 2026-08-25 |
| `onnxim-kv-instrumented` | **private** | no | **held** — same | 2026-08-25 |

Release order was deliberate: the FTL snapshot went public first so the hub could link a
URL that actually resolves, then the hub was re-scanned and only then flipped — the last
irreversible step. Anonymous (unauthenticated) checks after the flip confirmed HTTP 200
for both public repos and HTTP 404 for all three private ones.

Standing note for future releases: private→public also exposes any Actions history and
enables forking, and anything that has been public in git history is not fully
retractable by deleting the file afterwards. This hub had 0 workflows and 0 runs at the
time of release, so nothing beyond the 18 tracked files was exposed.
| `kv-cache-consumer-gpu-bench` | already public | n/a | — | — |
| `memory-hierarchy-experiment-framework` | already public | n/a | — | — |

No row moves to "approved" without an explicit instruction from the owner.
