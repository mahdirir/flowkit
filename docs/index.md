---
title: alpha-miner
---

# alpha-miner

**Process discovery from activity logs, in V.**

`alpha-miner` turns a delimited event log into a Petri net using the
process-mining α-algorithm. It ships as both an importable V library (`alpha`)
and a single-binary CLI (`alpha-miner`), with no runtime dependencies.

- Read CSV logs with configurable delimiters and column layouts
- Compute a footprint of causality, concurrency and never-follow relations
- Discover maximal places without enumerating the powerset of activities
- Export to human-readable text, JSON, or Graphviz DOT
- Verify the model against the footprint before emitting it

## Quick start

```bash
git clone https://github.com/metif12/alpha-miner.git
cd alpha-miner
v build -o alpha-miner ./cmd/alpha-miner
./alpha-miner --help
./alpha-miner -i dataset.csv -f dot -o net.dot
```

## A tiny example

```csv
case,time,event,activity
t1,2024-01-01 08:00:00,e1,A
t1,2024-01-01 08:01:00,e2,B
t2,2024-01-01 09:00:00,e3,A
t2,2024-01-01 09:01:00,e4,B
```

```bash
alpha-miner -d , -i example.csv
```

```text
Traces:           2
Activities:       2
Places:           3
Arcs:             4

Start activities: A
End activities:   B

Footprint (# never follows, -> causality, || concurrency):
  A: #  ->
  B: #  #

Places:
  p0: {A} -> {B}
  p1: {} -> {A}
  p2: {B} -> {}
...
```

## Use it as a library

```v
import alpha

result := alpha.analyze('log.csv', alpha.CsvOptions{ delimiter: `,` })!
println(alpha.render_json(result))
```

## Read more

- [CLI reference](cli.md)
- [Library API](api.md)
- [The algorithm and its limits](algorithm.md)
- [Source repository](https://github.com/metif12/alpha-miner)
