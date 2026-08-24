# Memory Hierarchy Experiment Framework

Repo: [`oyeong011/memory-hierarchy-experiment-framework`](https://github.com/oyeong011/memory-hierarchy-experiment-framework) (public) · C / Bash / Python / `perf`

## Problem

The same working set, laid out or traversed differently, can differ in runtime by an
order of magnitude with identical instruction counts. This project builds the tooling
to measure *why* — cache locality, TLB behavior, and blocking effects — rather than
reasoning about it from a textbook diagram.

## My Role

Wrote the C microbenchmarks, the `perf`-based automation, and the Python parsing and
plotting layer.

## Implementation

- **C microbenchmarks** — sequential / strided / random access; naive, loop-reordered,
  and blocked (tiled) matrix multiply; page-granular sequential vs random access for
  virtual-memory behavior.
- **Bash automation** — sweeps working-set size and stride, invokes `perf` per point.
- **Python** — parses `perf` output into CSV, plots, produces the report.
- `Makefile` + `scripts/` so a sweep is one command.

## Experiment

Working-set size and stride are swept across the cache hierarchy's boundaries while
`perf` counts cache and TLB events; matrix multiply is measured across loop orders and
tile sizes at fixed problem size.

## Result

Reproduces the canonical memory-hierarchy behaviors on a real Linux machine with real
counters: bandwidth cliffs where the working set leaves each cache level, TLB-miss
growth under page-random access, and the runtime gap between naive, reordered, and
blocked matrix multiply at identical FLOP counts.

## Negative Result / Limitation

- Single-machine results; counter semantics and cache geometry are CPU-specific and
  the conclusions are not portable as absolute numbers.
- `perf` counter availability varies with kernel and permissions; some events are
  unavailable without elevated privileges.
- **Status in this portfolio: `documented-not-rerun`.** This repository's claims have
  not been re-verified against raw output in the current portfolio pass — it is
  included as skills evidence (C, `perf`, Linux performance tooling, automation), not
  as a headline measurement.

## Reproducibility

`make` + `scripts/` drive the full sweep; parsing and plotting regenerate the report
from raw `perf` output. Public repository.
