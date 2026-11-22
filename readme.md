# flowkit

[![V](https://img.shields.io/badge/V-0.5.2-5d87bf.svg)](https://vlang.io/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![vpm](https://img.shields.io/badge/vpm-metif12.flowkit-blue.svg)](https://vpm.vlang.io/)

**Process mining and activity log processing, in V.**

`flowkit` turns activity logs into Petri nets and analysis results. It is a VPM
package (`metif12.flowkit`) and a single-binary CLI, with no runtime dependencies.

📖 **Documentation:** <https://metif12.github.io/flowkit/>

## What it does

- **Ingest** CSV (single-pass parser, configurable columns), XES 1.0 and OCEL 2.0 logs
- **Inspect** statistics: cases, events, activities, variants, frequencies, rework
- **Filter** by time, activities, case size, frequency and top variants
- **Discover** Petri nets with α, α+ (short loops) or the frequency-based heuristic miner
- **Evaluate** token replay, bounded alignments, escaping-edge precision, generalization and simplicity
- **Convert** process trees to Petri nets and BPMN 2.0
- **Summarise** logs with incremental event counters and DFG statistics
- **Encode** cases as one-hot, count, n-gram or TF-IDF feature tables
- **Export** text, JSON, Graphviz DOT, PNML, BPMN and XES
- **Extend** with custom readers, parsers, writers, algorithms and hooks — built-ins use the same registry
- **Compose** everything through a pipeline API or the CLI

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

# Convert and analyse
flowkit convert -i log.xes -f pnml -o model.pnml
flowkit -i log.xes -f bpmn -o model.bpmn
flowkit -i examples/simple.csv -d , --conformance
flowkit -i log.csv --encode tfidf -o features.csv
flowkit -i examples/simple.csv -d , --stream

# Object-centric logs
flowkit --ocel-types -i examples/example.jsonocel
flowkit -i examples/example.jsonocel --object-type Order

# Extension discovery
flowkit --list-formats
flowkit -i log.csv -f json --hook after_write="python annotate.py"
```

## Use as a V library

```v
import flowkit

// One call: read a CSV, XES or OCEL log and run the whole pipeline.
result := flowkit.discover('log.xes')!
println(flowkit.render_text(result, flowkit.TextOptions{}))
println(flowkit.replay(result.log, result.net).fitness)
println(flowkit.alignment_fitness(result.log, result.net, 200, 8))

// Composed pipeline.
log := flowkit.read_csv('log.csv', flowkit.ReadOptions{ delimiter: `,` })!
result2 := flowkit.new_pipeline(log)
	.with_method(.alpha_plus)
	.with_filter(flowkit.Filter{ min_activity_count: 5 })
	.run()

// Extension-aware session.
mut reg := flowkit.new_registry()!
reg.add_algorithm(flowkit.AlgorithmSpec{ name: 'mine', discover: my_algorithm })!
ctx := flowkit.new_context('log.csv', flowkit.Options{ algorithm: 'mine' })
result3 := flowkit.run(mut reg, mut ctx)!
```

Import individual packages for smaller binaries: `flowkit.model`, `flowkit.io`,
`flowkit.analysis`, `flowkit.discovery`, `flowkit.conformance`,
`flowkit.evaluation`, `flowkit.export`, `flowkit.pipeline`, `flowkit.process`,
`flowkit.streaming`, `flowkit.ml`, `flowkit.ocel`, `flowkit.contracts`,
`flowkit.registry`, `flowkit.builtins`, `flowkit.hooks`, `flowkit.session`.

## CLI

```
flowkit [discover|stats|convert] [OPTIONS] [INPUT]
flowkit completions <bash|zsh|powershell>

  -i, --input FILE       Log file: .csv, .xes or .jsonocel (default: dataset.csv)
  -o, --output FILE      Write to file (default: stdout)
  -f, --format FORMAT    text, json, dot, pnml, bpmn, xes (default: text)
  -d, --delimiter CHAR   CSV delimiter, or "tab" (default: ;)
      --case-col N       Case-id column, 0-based (default: 0)
      --time-col N       Timestamp column, 0-based (default: 1)
      --event-col N      Event-id column, 0-based (default: 2)
      --activity-col N   Activity column, 0-based (default: 3)
      --no-header        First row is data, not a header
      --method NAME      alpha or alpha+ (default: alpha)
      --heuristic        Use the frequency-based heuristic miner
      --threshold N      Heuristic dependency threshold (default: 0.5)
      --stream           Incremental event/DFG summary
      --encode NAME      Feature encoding: onehot, count, ngram, tfidf
      --ngram N          N-gram size (default: 2)
      --algorithm NAME   Discovery algorithm (alpha, alpha+, heuristic, or custom)
      --hook PHASE=CMD   Register an external hook (repeatable)
      --list-formats     List registered readers, writers and algorithms
      --object-type NAME Object type to project from an OCEL log
      --ocel-types       List object types and their co-occurrence graph
      --min-count N      Minimum DFG edge frequency (default: 1)
      --max-variants N   Keep the N most frequent variants
      --conformance      Conformance metrics (text format only)
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
  model/        shared data types, flat footprint matrix, length-prefixed keys
  io/           single-pass CSV parser, XES and OCEL readers/writers
  analysis/     footprint, statistics, DFG, filtering
  discovery/    alpha, alpha+ and heuristic place discovery
  conformance/  footprint comparison, token replay, alignments
  evaluation/   quality proxies and conformance metrics
  export/       text, JSON, DOT, PNML, BPMN
  process/      process trees, Petri net and BPMN conversion
  streaming/    incremental event and DFG counters
  ml/           one-hot, count, n-gram and TF-IDF encodings
  ocel/         object-centric logs, flattening and OC-DFG
  contracts/    extension specs and shared pipeline context
  registry/     extension registration and lookup
  builtins/     registers CSV/XES/OCEL, exporters and α/α+/heuristic
  hooks/        in-process and external command hooks
  session/      extension-aware stage pipeline
  pipeline/     legacy fixed-stage composition
cmd/flowkit/    CLI
benchmarks/     reproducible per-stage throughput harness
docs/           GitHub Pages site
examples/       small logs and a sample plugin package
```

The footprint uses interned activity ids and a flat `n × n` matrix, so relation
lookups are O(1) and allocation-free in the hot loops. Places are grown from
causal seeds rather than enumerating all 2ⁿ activity subsets. Composite keys
are length-prefixed, so activity names containing separators cannot collide.

## Tests and benchmarks

```bash
v test ./flowkit ./cmd/flowkit ./examples/plugins
v fmt -check flowkit cmd benchmarks
v vet ./flowkit ./cmd/flowkit
v run benchmarks/bench.v -- dataset.csv
```

**15 test files pass.** The regression suite in `flowkit/session/regression_test.v`
covers the review fixes (missing case lookup, strict timestamps, key collisions,
short variants, filtered context).

Measured on the bundled 39 MB BPI log (466,737 events, 46,616 cases) on the
development machine. Timings vary between runs; a representative run:

| Stage | Time |
|---|---:|
| CSV read | 1,957 ms |
| Footprint | 78 ms |
| Discovery | 134 ms |
| Statistics | 587 ms |
| Quality | 106 ms |
| Conformance | 86 ms |
| DFG | 83 ms |
| **Total** | **3,031 ms** |

That is ≈154,000 events/s and ≈12.9 MB/s (other runs measured 2.88 s /
162,000 events/s). Raw file I/O is only ~11 ms; parsing dominates.

## Limitations

- The α-algorithm assumes a complete, noise-free log; real logs can overfit.
- The CSV and OCEL readers load the whole file into memory; `--stream`
  summarises events incrementally but does not avoid that initial read.
- The XES and OCEL readers are small hand-rolled parsers, not full validators.
- `--conformance` prints its report only in `text` format; other formats emit a
  warning.
- Highly concurrent logs can still produce large models.

## Dataset

`dataset.csv` is the BPI Challenge 2014 incident activity log
([source](https://data.4tu.nl/articles/dataset/BPI_Challenge_2014_Activity_log_for_incidents/12706424/1)).
`result.txt` is an example full result dump from an earlier version.

## Extending

Every format and algorithm is a registered extension, so third-party code uses
the same API as built-ins. External hooks can be written in any language. See
the [extension guide](docs/extending.md) and
[`examples/plugins`](examples/plugins).

## License

MIT — see [LICENSE](LICENSE).
