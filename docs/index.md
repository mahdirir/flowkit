---
title: flowkit
---

# flowkit

**Process mining and activity log processing in V.**

`flowkit` is a VPM package and a single-binary CLI covering the activity-log
lifecycle: ingest → inspect → filter → discover → evaluate → export. It has no
runtime dependencies.

- CSV (single-pass parser), XES 1.0 and OCEL 2.0 object-centric logs
- Statistics, variants, frequencies and rework detection
- Filtering by time, activity, case size, frequency and variants
- Petri net discovery with α, α+ (short loops) and a heuristic miner
- Conformance: footprint comparison, token replay and bounded alignments
- Process trees converted to Petri nets and BPMN 2.0
- Incremental event/DFG summaries and ML feature encodings
- Text, JSON, Graphviz DOT, PNML, BPMN and XES output
- Three API levels: one-call, pipeline and raw building blocks
- Extensible through registered readers, writers, algorithms and pre/post hooks

## Install

```bash
v install metif12.flowkit
```

Or from source:

```bash
git clone https://github.com/metif12/flowkit.git
cd flowkit
v build -o flowkit ./cmd/flowkit
```

(The VPM package must be registered first; until then, use the source build.)

## Quick start

```bash
flowkit discover -i dataset.csv --summary-only
flowkit stats -i examples/tiny.csv -d ,
flowkit -i examples/simple.csv -d , -f dot -o net.dot
flowkit -i examples/simple.csv -d , --conformance
flowkit --ocel-types -i examples/example.jsonocel
flowkit -i examples/example.jsonocel --object-type Order
flowkit --list-formats
```

## Library

```v
import flowkit

result := flowkit.discover('log.xes')!
println(flowkit.render_json(result))
println(flowkit.replay(result.log, result.net).fitness)
```

## Performance

A benchmark harness reports per-stage timings:

```bash
v run benchmarks/bench.v -- dataset.csv
```

On the bundled 39 MB BPI log: ~154k events/s, ~13 MB/s, ~3.0 s total.
CSV parsing dominates; raw file I/O is ~11 ms.

## Learn more

- [CLI reference](cli.md)
- [Library API](api.md)
- [Algorithm and internals](algorithm.md)
- [Extending flowkit](extending.md)
- [Source](https://github.com/metif12/flowkit)
