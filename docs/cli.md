---
title: CLI reference
---

# CLI reference

```
flowkit [discover|stats|convert] [OPTIONS] [INPUT]
flowkit completions <bash|zsh|powershell>
```

Progress goes to stderr; results go to stdout or `--output`.

## Commands

| Command | Purpose |
|---|---|
| `discover` | Discover a Petri net (default when no command is given) |
| `stats` | Print log statistics and quality only |
| `convert` | Convert a log to another format |
| `completions` | Print a shell completion script |

## Options

| Option | Meaning |
|---|---|
| `-i, --input FILE` | `.csv` or `.xes` log (default `dataset.csv`) |
| `-o, --output FILE` | Output file (default stdout) |
| `-f, --format FMT` | `text`, `json`, `dot`, `pnml`, `xes` |
| `-d, --delimiter CHAR` | CSV delimiter or `tab` (default `;`) |
| `--case-col N` | Case-id column (default 0) |
| `--time-col N` | Timestamp column (default 1) |
| `--event-col N` | Event-id column (default 2) |
| `--activity-col N` | Activity column (default 3) |
| `--no-header` | First row is data |
| `--method NAME` | `alpha` or `alpha+` |
| `--min-count N` | Minimum DFG edge frequency |
| `--max-variants N` | Keep only the N most frequent variants |
| `--summary-only` | Counts and quality only |
| `--explain` | Explain the steps in text output |
| `--dry-run` | Validate input without writing output |
| `-q, --quiet` | Suppress progress |
| `-v, --verbose` | Extra detail |
| `-h, --help`, `-V, --version` | Help and version |

Both `--input file` and `--input=file` forms work.

## Input format

CSV: one row per event, header skipped by default. Default columns match the
BPI Challenge 2014 log (case, timestamp, event id, activity).
Timestamps accept `YYYY-MM-DD HH:mm:ss` and `DD-MM-YYYY HH:mm:ss`.

XES: standard `<trace>` / `<event>` structure with `concept:name` and
`time:timestamp` attributes.

## Output formats

- **text** — summary, statistics, start/end, places, arcs, optional explanation
- **json** — summary, quality, activities, places, arcs
- **dot** — Graphviz graph (transitions as boxes, places as circles)
- **pnml** — standard Petri net markup language, importable by ProM/PM4Py
- **xes** — converts the discovered log back to XES

## Exit codes

`0` success, `1` runtime error, `2` usage error.
