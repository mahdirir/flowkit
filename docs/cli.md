---
title: CLI reference
---

# CLI reference

```
alpha-miner [OPTIONS] [INPUT]
```

Progress messages are written to stderr; the result is written to stdout (or
to `--output`), so output can be piped safely.

## Options

| Option | Meaning |
|---|---|
| `-i, --input FILE` | Activity log CSV (default `dataset.csv`) |
| `-o, --output FILE` | Write result to a file instead of stdout |
| `-f, --format FORMAT` | `text`, `json` or `dot` (default `text`) |
| `-d, --delimiter CHAR` | CSV delimiter, or `tab` (default `;`) |
| `--case-col N` | Case-id column, 0-based (default `0`) |
| `--time-col N` | Timestamp column, 0-based (default `1`) |
| `--event-col N` | Event-id column, 0-based (default `2`) |
| `--activity-col N` | Activity column, 0-based (default `3`) |
| `--no-header` | First row is data, not a header |
| `--summary-only` | Text format: counts and start/end activities only |
| `-q, --quiet` | Suppress progress messages |
| `-v, --verbose` | Print discovered place and arc counts |
| `-h, --help` | Show help |
| `-V, --version` | Show version |

Both `--input file.csv` and `--input=file.csv` are accepted. A single
positional argument is treated as the input file. Use `--` before a filename
that begins with a dash.

## Input

One row per event. The header row is skipped unless `--no-header` is set.

Default columns match the BPI Challenge 2014 incident activity log:

| Index | Field |
|---|---|
| 0 | case id |
| 1 | timestamp |
| 2 | event id |
| 3 | activity |

Timestamps may be `YYYY-MM-DD HH:mm:ss` or `DD-MM-YYYY HH:mm:ss`. Events are
sorted by timestamp inside each case. Duplicate event ids are ignored;
repeated activities are kept, so loops survive.

## Output formats

### text

Summary counts, start/end activities, the footprint table for logs with up to
12 activities, then every place and arc. `--summary-only` prints just the
counts and start/end sets.

### json

```json
{
  "version": "1.0.0",
  "summary": { "traces": 2, "activities": 3, "places": 4, "arcs": 7 },
  "activities": ["A", "B", "C"],
  "start_activities": ["A"],
  "end_activities": ["B", "C"],
  "places": [{ "index": 0, "inputs": ["A"], "outputs": ["B"] }],
  "arcs": [{ "transition": "A", "place": 0, "direction": "in" }]
}
```

### dot

Graphviz directed graph: transitions are boxes, places are circles.

```bash
alpha-miner -f dot -o net.dot && dot -Tpng net.dot -o net.png
```

## Exit codes

| Code | Meaning |
|---|---|
| 0 | success |
| 1 | runtime error (unreadable input, malformed row, unwritable output) |
| 2 | usage error (unknown flag, bad value, too many arguments) |
