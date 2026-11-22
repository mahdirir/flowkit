---
title: Algorithm
---

# The α-algorithm, as implemented here

The α-algorithm discovers a Petri net from an event log. This page describes
the relations it computes and how places are found.

## 1. Event log

Rows are grouped by case id. Within each case, events are sorted by timestamp,
using an explicit numeric key so that calendar comparison never depends on
timezone or struct layout. Repeated event ids are ignored; repeated activities
are preserved so self-loops remain visible.

## 2. Footprint

Let `a > b` mean "in some case, activity `b` directly follows activity `a`".
For every ordered pair of activities:

| Condition | Relation | Symbol |
|---|---|---|
| `a > b` and not `b > a` | causality | `->` |
| `a > b` and `b > a` | concurrency | `\|\|` |
| otherwise | never-follow | `#` |

The concurrency relation is set symmetrically for both directions.

## 3. Places

A place is a pair `(A, B)` of non-empty activity sets such that:

- activities inside `A` are pairwise in `#`;
- activities inside `B` are pairwise in `#`;
- every activity in `A` causally precedes every activity in `B`;
- the pair is maximal: no larger pair satisfying the above contains it.

A naive implementation enumerates the powerset of activities — 2^39 for the
bundled example log, which is impossible. Instead, every causal pair `(a, b)`
is used as a seed and grown in all possible ways into larger valid pairs. A
visited-state map prevents repeated work. Every completed pair is checked
against the footprint once more before it is emitted as a place.

Two extra places are always added:

- source: `(∅, start activities)`
- sink: `(end activities, ∅)`

Note that the sink uses **end** activities; using start activities there is a
common implementation bug.

## 4. Arcs and export

For a place `(A, B)`, arcs `a -> place` are created for `a ∈ A` and
`place -> b` for `b ∈ B`. The result can be rendered as text, JSON or DOT.

## Limitations

The α-algorithm assumes a complete, noise-free event log. Real logs with
missing, duplicated or out-of-order events can yield an over-fitted net with
many places. Concurrency that never appears as a direct alternation in any
case cannot be detected. The number of maximal pairs is bounded only by the
footprint, so highly concurrent logs can produce large models.
