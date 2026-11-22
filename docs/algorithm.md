---
title: Algorithm
---

# Algorithms and internals

This page describes the footprint relations, place discovery, the heuristic
miner, conformance checks and the limits of the implementation.

## 1. Event log

Rows are grouped by case id. Within each case, events are sorted by a numeric
timestamp key, so ordering does not depend on struct layout. Repeated event ids
are ignored; repeated activities are preserved so loops remain visible.
Timestamps are digit-checked: a non-numeric component is rejected rather than
silently converted to zero.

## 2. Footprint

Let `a > b` mean "in some case, activity `b` directly follows activity `a`".

| Condition | Relation | Symbol |
|---|---|---|
| `a > b` and not `b > a` | causality | `->` |
| `a > b` and `b > a` | concurrency | `\|\|` |
| otherwise | never-follow | `#` |

Concurrency is set symmetrically for both directions. The relation matrix is
flat (`n × n`) and addressed by interned activity ids.

## 3. Places (α and α+)

A place is a pair `(A, B)` of non-empty activity sets such that:

- activities inside `A` are pairwise in `#`;
- activities inside `B` are pairwise in `#`;
- every activity in `A` causally precedes every activity in `B`;
- the pair is maximal.

A naive implementation enumerates the powerset of activities — 2^39 for the
bundled log. Instead, every causal pair `(a, b)` is grown into all larger valid
pairs with a visited-state map, and each completed pair is re-validated against
the footprint.

Two extra places are added: source `(∅, start activities)` and sink
`(end activities, ∅)`. The sink uses **end** activities. α+ additionally adds
`(a, a)` places for activities with self-loops.

## 4. Heuristic miner

The heuristic miner uses a dependency measure
`dep(a,b) = |a>b| / (|a>b| + |b>a| + 1)` and a threshold (default 0.5).
Successors and predecessors that are mutually concurrent are grouped into
AND-splits and AND-joins. The threshold is validated before conversion.

## 5. Conformance

- **Footprint comparison** — log relations vs. relations implied by the net's places.
- **Token replay** — per-case missing and remaining tokens, with a fitness value.
- **Bounded alignments** — playout sequences up to a state/length limit, then
  edit-distance alignment against each trace.
- **Quality** — fitness, precision, generalization and simplicity proxies; the
  `_proxy` suffix marks that these are structural estimates, not exact replay
  measurements.

## 6. Export

Composite keys are length-prefixed so names containing separators cannot
collide. PNML transition ids are sanitised to valid NCName identifiers. Output
formats: text, JSON, DOT, PNML, BPMN and XES.

## Limitations

- α assumes a complete, noise-free log; real logs can overfit.
- Concurrency that never appears as a direct alternation cannot be detected.
- The number of maximal pairs is bounded only by the footprint; highly
  concurrent logs can produce large models.
- CSV and OCEL readers load the whole file into memory.
- XES/OCEL parsing is a lightweight hand-rolled approximation, not a full
  schema validator.
- `--conformance` is only printed in text format.
