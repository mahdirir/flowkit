# alpha

A command-line tool that discovers a **Petri net** from an **event log** using the
process-mining **α-algorithm**. Written in [V](https://vlang.io/), no runtime
dependencies.

## Install / build

```bash
v build -o alpha .      # produces ./alpha (or alpha.exe on Windows)
```

Or run directly from the source tree:

```bash
v run . -- --help
```

## Usage

```
alpha [OPTIONS] [INPUT]

Options:
  -i, --input FILE       Event log CSV (default: dataset.csv)
  -o, --output FILE      Write result to FILE (default: stdout)
  -f, --format FORMAT    Output format: text, json, dot (default: text)
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

Exit codes: `0` success, `1` runtime error, `2` usage error. Progress messages go
to stderr, so the result on stdout can be piped safely.

### Examples

```bash
# Default: read dataset.csv, print a text summary
alpha

# Discover a net and render it with Graphviz
alpha -i dataset.csv -f dot -o net.dot
dot -Tpng net.dot -o net.png

# Machine-readable output, silence progress messages
alpha -i log.csv --quiet --format json --output net.json

# A different CSV layout: comma separated, activity in column 2
alpha -i log.csv --delimiter , --activity-col 2

# Just the numbers for the bundled BPI dataset
alpha --summary-only
```

Both `--input=value` and `--input value` forms are accepted. A single positional
argument is treated as the input file. Use `--` before a filename that starts
with a dash.

## Input format

A delimited CSV with one row per event. The first row is skipped as a header
unless `--no-header` is given. Default column layout (BPI Challenge 2014):

| Column | Meaning |
|---|---|
| 0 | case / trace id |
| 1 | timestamp |
| 2 | event id |
| 3 | activity name |

Timestamps are parsed as `YYYY-MM-DD HH:mm:ss` or `DD-MM-YYYY HH:mm:ss`.
Events are sorted by timestamp within each case; repeated event ids are ignored.
Activities that repeat within a case are **not** collapsed, so loops are kept.

## Output formats

### `text` (default)

Summary counts, start/end activities, the footprint relation table (for logs with
up to 12 activities), and every place and arc of the discovered net.
`--summary-only` prints just the counts and start/end activities.

### `json`

```json
{
  "version": "1.0.0",
  "summary": { "traces": 2, "activities": 3, "places": 4, "arcs": 7 },
  "activities": ["A", "B", "C"],
  "start_activities": ["A"],
  "end_activities": ["B", "C"],
  "places": [
    { "index": 0, "inputs": ["A"], "outputs": ["B"] }
  ],
  "arcs": [
    { "transition": "A", "place": 0, "direction": "in" }
  ]
}
```

### `dot`

A Graphviz directed graph: transitions are boxes, places are circles.

## How it works

1. **Event log** — rows are grouped by case id and sorted by timestamp.
2. **Footprint** — for every pair of activities `(a, b)` compute
   `a -> b` (causality), `a || b` (concurrency) or `a # b` (never follows).
3. **Places** — grow every causal seed `(a, b)` into all maximal input/output
   sets whose members are pairwise non-following and whose cross product is
   causal. This is equivalent to the α-algorithm's powerset search without
   materialising 2ⁿ subsets, which is infeasible for real logs. Every emitted
   place is checked against the footprint before being added.
4. **Source/sink places** — `iL = (∅, start activities)` and
   `oL = (end activities, ∅)`.

The bundled `dataset.csv` is the BPI Challenge 2014 incident activity log
([source](https://data.4tu.nl/articles/dataset/BPI_Challenge_2014_Activity_log_for_incidents/12706424/1)).
`result.txt` is an example full result dump from an earlier version.

## Tests

```bash
v test .
```

Tests cover footprint relations, place validity, net construction, timestamp
parsing, argument parsing and all three renderers.

## Known limitations

The α-algorithm assumes a complete, noise-free event log. Real event logs with
missing or out-of-order events can produce an over-fitted net. The number of
places is bounded only by the structure of the footprint — for very large or
very concurrent logs the maximal-pair search can grow.

## License

MIT
