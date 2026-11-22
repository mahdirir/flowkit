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
| `-f, --format FMT` | `text`, `json`, `dot`, `pnml`, `bpmn`, `xes` |
| `--stream` | Stream events and print DFG statistics |
| `--encode NAME` | Feature encoding: `onehot`, `count`, `ngram`, `tfidf` |
| `--ngram N` | N-gram size (default 2) |
| `--algorithm NAME` | Use a registered discovery algorithm |
| `--hook PHASE=CMD` | Register an external command hook (repeatable) |
| `--list-formats` | List registered readers, writers and algorithms |
| `--object-type NAME` | Project an OCEL log onto one object type |
| `--ocel-types` | List object types and their co-occurrence graph |
| `-d, --delimiter CHAR` | CSV delimiter or `tab` (default `;`) |
| `--case-col N` | Case-id column (default 0) |
| `--time-col N` | Timestamp column (default 1) |
| `--event-col N` | Event-id column (default 2) |
| `--activity-col N` | Activity column (default 3) |
| `--no-header` | First row is data |
| `--method NAME` | `alpha` or `alpha+` |
| `--heuristic` | Use the heuristic miner instead of α |
| `--threshold N` | Heuristic dependency threshold (default 0.5) |
| `--min-count N` | Minimum DFG edge frequency |
| `--max-variants N` | Keep only the N most frequent variants |
| `--conformance` | Print replay, alignment, precision and generalization |
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
