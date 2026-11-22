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
| `--list-formats` | List registered readers, writers, renderers and algorithms |

## Options

| Option | Meaning |
|---|---|
| `-i, --input FILE` | `.csv`, `.xes` or `.jsonocel` log (default `dataset.csv`) |
| `-o, --output FILE` | Output file (default stdout) |
| `-f, --format FMT` | `text`, `json`, `dot`, `pnml`, `bpmn`, `xes` |
| `-d, --delimiter CHAR` | CSV delimiter or `tab` (default `;`) |
| `--case-col N` | Case-id column (default 0) |
| `--time-col N` | Timestamp column (default 1) |
| `--event-col N` | Event-id column (default 2) |
| `--activity-col N` | Activity column (default 3) |
| `--no-header` | First row is data |
| `--method NAME` | `alpha` or `alpha+` |
| `--heuristic` | Use the heuristic miner instead of α |
| `--threshold N` | Heuristic dependency threshold (default 0.5); must be numeric |
| `--algorithm NAME` | Use a registered discovery algorithm |
| `--hook PHASE=CMD` | Register an external command hook (repeatable) |
| `--object-type NAME` | Project an OCEL log onto one object type |
| `--ocel-types` | List object types and their co-occurrence graph |
| `--stream` | Incremental event/DFG summary |
| `--encode NAME` | Feature encoding: `onehot`, `count`, `ngram`, `tfidf` |
| `--ngram N` | N-gram size (default 2) |
| `--min-count N` | Minimum DFG edge frequency |
| `--max-variants N` | Keep only the N most frequent variants |
| `--conformance` | Conformance metrics — **text format only**; other formats print a warning |
| `--summary-only` | Counts and quality only |
| `--explain` | Explain the steps in text output |
| `--dry-run` | Validate input without writing any output file |
| `-q, --quiet` | Suppress progress |
| `-v, --verbose` | Extra detail |
| `-h, --help`, `-V, --version` | Help and version |

Both `--input file` and `--input=file` forms work.

## Input formats

- **CSV** — one row per event; header skipped by default; columns configurable;
  timestamps accept `YYYY-MM-DD HH:mm:ss` or `DD-MM-YYYY HH:mm:ss` with numeric
  digits only.
- **XES** — `<trace>` / `<event>` blocks with `concept:name` and
  `time:timestamp` attributes.
- **OCEL 2.0 JSON** — `events`, `objects` and `relationships`; select an object
  type with `--object-type`, or inspect types with `--ocel-types`.

## Output formats

- **text** — summary, statistics, start/end, places, arcs, optional explanation
- **json** — summary, quality, activities, places, arcs
- **dot** — Graphviz graph (transitions as boxes, places as circles)
- **pnml** — Petri net markup with sanitised, unique transition identifiers
- **bpmn** — BPMN 2.0 XML from a process tree
- **xes** — converts the discovered log back to XES (requires `--output`)

## Examples

```bash
flowkit -i examples/simple.csv -d , --conformance
flowkit -i examples/example.jsonocel --object-type Order -f json
flowkit -i log.csv --encode tfidf -o features.csv
flowkit -i log.csv --hook after_write="python annotate.py"
flowkit --list-formats
```

## Exit codes

`0` success, `1` runtime error, `2` usage error.

## Limitations

Input files are read fully into memory; `--stream` summarises events
incrementally but does not avoid that initial read. The XES/OCEL readers are
lightweight parsers, not full schema validators.
