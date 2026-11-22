---
title: flowkit
---

# flowkit

**Process mining and activity log processing in V.**

`flowkit` is a VPM package and a single-binary CLI for the full activity-log
lifecycle: ingest → inspect → filter → discover → evaluate → export.

- Streamed CSV with configurable columns; XES 1.0 import and export
- Statistics, variants, frequencies and rework detection
- Filtering by time, activity, case size, frequency and top variants
- Petri net discovery with α and α+ (short loops)
- Footprint conformance and fitness/precision/simplicity proxies
- Text, JSON, Graphviz DOT, PNML and XES output
- Three API levels: one-call, pipeline and raw building blocks
- Extensible via registered readers, writers, algorithms and pre/post hooks

## Install

```bash
v install metif12.flowkit
```

```bash
git clone https://github.com/metif12/flowkit.git
cd flowkit
v build -o flowkit ./cmd/flowkit
```

## Quick start

```bash
flowkit discover -i dataset.csv --summary-only
flowkit stats -i examples/tiny.csv -d ,
flowkit -i examples/simple.csv -d , -f dot -o net.dot
flowkit convert -i log.xes -f pnml -o model.pnml
```

## Library

```v
import flowkit

result := flowkit.discover('log.xes')!
println(flowkit.render_json(result))
```

## Learn more

- [CLI reference](cli.md)
- [Library API](api.md)
- [Algorithm and internals](algorithm.md)
- [Extending flowkit](extending.md)
- [Source](https://github.com/metif12/flowkit)
