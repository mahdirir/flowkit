# alpha-miner

[![V](https://img.shields.io/badge/V-0.5.2-5d87bf.svg)](https://vlang.io/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Process discovery from activity logs, in V.**

`alpha-miner` discovers a Petri net from a delimited event log using the
process-mining α-algorithm. It is both an importable V library (`alpha`) and a
single-binary CLI (`alpha-miner`), with no runtime dependencies.

📖 **Documentation:** <https://metif12.github.io/alpha-miner/>

## Install

Requires [V](https://vlang.io/) 0.5.2 or newer.

```bash
git clone https://github.com/metif12/alpha-miner.git
cd alpha-miner
v build -o alpha-miner ./cmd/alpha-miner
```

## Quick start

```bash
# Discover a net from the bundled BPI Challenge 2014 log
./alpha-miner -i dataset.csv --summary-only

# Render it as a Graphviz graph
./alpha-miner -i dataset.csv -f dot -o net.dot
dot -Tpng net.dot -o net.png

# A small example log
./alpha-miner -i examples/simple.csv -d ,
```

## CLI options

```
  -i, --input FILE       Activity log CSV (default: dataset.csv)
  -o, --output FILE      Write result to FILE (default: stdout)
  -f, --format FORMAT    text, json or dot (default: text)
  -d, --delimiter CHAR   CSV delimiter, or "tab" (default: ;)
      --case-col N       Case-id column, 0-based (default: 0)
      --time-col N       Timestamp column, 0-based (default: 1)
      --event-col N      Event-id column, 0-based (default: 2)
      --activity-col N   Activity column, 0-based (default: 3)
      --no-header        First row is data, not a header
      --summary-only     Text output: counts only, no places/arcs
  -q, --quiet            Suppress progress messages
  -v, --verbose          Print detailed progress
  -h, --help             Show help
  -V, --version          Show version
```

Exit codes: `0` success, `1` runtime error, `2` usage error. See the
[CLI reference](docs/cli.md) for the input format and all output formats.

## Use as a V library

```v
import alpha

result := alpha.analyze('log.csv', alpha.CsvOptions{ delimiter: `,` })!
println(alpha.render_json(result))
```

The library exposes the full pipeline — `read_eventlog_csv`, `build_footprint`,
`discover_net` — plus the `render_text`, `render_json` and `render_dot`
exporters. See the [API reference](docs/api.md).

## Repository layout

```
alpha/               V library (module alpha)
cmd/alpha-miner/     CLI entry point
docs/                GitHub Pages documentation
examples/            small example logs
dataset.csv          BPI Challenge 2014 activity log
result.txt           example result dump from an earlier version
```

## How it works

1. Group rows by case and sort events by timestamp.
2. Build a footprint of causality (`->`), concurrency (`||`) and never-follow
   (`#`) relations between activities.
3. Grow every causal pair into all maximal places, validating each against the
   footprint — no 2ⁿ powerset enumeration.
4. Add the source and sink places, then render.

The α-algorithm assumes complete, noise-free logs; see
[Algorithm](docs/algorithm.md) for details and limitations.

## Tests

```bash
v test ./alpha ./cmd/alpha-miner
```

## Dataset

`dataset.csv` is the BPI Challenge 2014 incident activity log
([source](https://data.4tu.nl/articles/dataset/BPI_Challenge_2014_Activity_log_for_incidents/12706424/1)).

## License

MIT — see [LICENSE](LICENSE).
