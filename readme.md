# flowkit

[![V](https://img.shields.io/badge/V-0.5.2-5d87bf.svg)](https://vlang.io/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![vpm](https://img.shields.io/badge/vpm-metif12.flowkit-blue.svg)](https://vpm.vlang.io/)

**Process mining and activity log processing, in V.**

`flowkit` turns activity logs into trustworthy process models. It is a VPM
package (`metif12.flowkit`) and a single-binary CLI, with no runtime
dependencies.

📖 **Docs:** <https://metif12.github.io/flowkit/>

## What it does

- **Ingest** CSV (streamed, configurable columns) and XES 1.0 event logs
- **Inspect** statistics: cases, events, activities, variants, frequencies, rework
- **Filter** by time, activities, case size, frequency and top variants
- **Discover** Petri nets with the α-algorithm or α+ (short loops)
- **Evaluate** token replay, bounded alignments, escaping-edge precision, generalization and simplicity
- **Export** text, JSON, Graphviz DOT, PNML and XES
- **Compose** all of the above through a pipeline API or the CLI

## Install

Once registered on VPM:

```bash
v install metif12.flowkit
```

Until then, build from source:

```bash
git clone https://github.com/metif12/flowkit.git
cd flowkit
v build -o flowkit ./cmd/flowkit
```

## 60-second tour

```bash
# Discover a net from the bundled BPI Challenge 2014 log
flowkit discover -i dataset.csv --summary-only

# Statistics for a small log
flowkit stats -i examples/tiny.csv -d ,

# Render a Graphviz model
flowkit -i examples/simple.csv -d , -f dot -o net.dot

# XES in, PNML out
flowkit convert -i log.xes -f pnml -o model.pnml
```

## Use as a V library

```v
import flowkit

// One call: read a CSV or XES log and run the whole pipeline.
result := flowkit.discover('log.xes')!
println(flowkit.render_text(result, flowkit.TextOptions{}))
println(flowkit.replay(result.log, result.net).fitness)
println(flowkit.alignment_fitness(result.log, result.net, 200, 8))

// Or compose your own pipeline.
log := flowkit.read_csv('log.csv', flowkit.ReadOptions{ delimiter: `,` })!
result2 := flowkit.new_pipeline(log)
	.with_method(.alpha_plus)
	.with_filter(flowkit.Filter{ min_activity_count: 5 })
	.run()
```

Import individual packages for smaller binaries: `flowkit.model`,
`flowkit.io`, `flowkit.analysis`, `flowkit.discovery`, `flowkit.conformance`,
`flowkit.evaluation`, `flowkit.export`, `flowkit.pipeline`.

## CLI

```
flowkit [discover|stats|convert] [OPTIONS] [INPUT]
flowkit completions <bash|zsh|powershell>

  -i, --input FILE       Log file: .csv or .xes (default: dataset.csv)
  -o, --output FILE      Write to file (default: stdout)
  -f, --format FORMAT    text, json, dot, pnml, xes (default: text)
  -d, --delimiter CHAR   CSV delimiter, or "tab" (default: ;)
      --case-col N       Case-id column, 0-based (default: 0)
      --time-col N       Timestamp column, 0-based (default: 1)
      --event-col N      Event-id column, 0-based (default: 2)
      --activity-col N   Activity column, 0-based (default: 3)
      --no-header        First row is data, not a header
      --method NAME      alpha or alpha+ (default: alpha)
      --min-count N      Minimum DFG edge frequency (default: 1)
      --max-variants N   Keep the N most frequent variants
      --conformance      Print replay, alignment, precision and generalization
      --summary-only     Counts and quality only
      --explain          Explain each step in the output
      --dry-run          Validate input without writing output
  -q, --quiet            Suppress progress messages
  -v, --verbose          Print extra detail
  -h, --help             Show help
  -V, --version          Show version
```

Exit codes: `0` success, `1` runtime error, `2` usage error.

## Architecture

```
flowkit/
  model/        shared data types, flat footprint matrix
  io/           streaming CSV reader, XES reader/writer
  analysis/     footprint, statistics, DFG, filtering
  discovery/    alpha and alpha+ place discovery
  conformance/  footprint comparison log vs model
  evaluation/   quality proxies
  export/       text, JSON, DOT, PNML
  pipeline/     stage composition
cmd/flowkit/    CLI
benchmarks/     reproducible throughput harness
docs/           GitHub Pages site
```

The footprint uses interned activity ids and a flat `n × n` matrix, so relation
lookups are O(1) and allocation-free in the hot loops. Places are grown from
causal seeds rather than enumerating all 2ⁿ activity subsets.

## Tests and benchmarks

```bash
v test ./flowkit ./cmd/flowkit
v fmt -check flowkit cmd benchmarks
v vet ./flowkit ./cmd/flowkit
v run benchmarks/bench.v -- dataset.csv
```

Measured on the bundled 39 MB BPI log: 466,737 events in 5.31 s
(≈87,800 events/s, ≈7.4 MB/s) on the development machine.

## Dataset

`dataset.csv` is the BPI Challenge 2014 incident activity log
([source](https://data.4tu.nl/articles/dataset/BPI_Challenge_2014_Activity_log_for_incidents/12706424/1)).
`result.txt` is an example full result dump from an earlier version.

## License

MIT — see [LICENSE](LICENSE).
