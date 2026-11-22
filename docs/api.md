---
title: Library API
---

# Library API

The V module is named `alpha`. Add this repository as a dependency, then:

```v
import alpha
```

## Discovery pipeline

```v
// Read a log and discover the net in one call.
result := alpha.analyze('log.csv', alpha.CsvOptions{ delimiter: `,` })!

// Or run each stage yourself.
log := alpha.read_eventlog_csv('log.csv', alpha.CsvOptions{})!
footprint := alpha.build_footprint(log)
net := alpha.discover_net(log, footprint)
```

## Types

### CsvOptions

| Field | Type | Default | Meaning |
|---|---|---|---|
| `delimiter` | `u8` | `;` | CSV delimiter |
| `case_col` | `int` | `0` | case-id column |
| `time_col` | `int` | `1` | timestamp column |
| `event_col` | `int` | `2` | event-id column |
| `activity_col` | `int` | `3` | activity column |
| `header` | `bool` | `true` | skip the first row |

### EventLog

- `read_eventlog_csv(path, opts) !EventLog` — read a file.
- `parse_csv(content, opts) !EventLog` — read from a string.
- `trace(id) ?Trace` — look up one case.
- `trace_count()`, `activity_count()`, `event_count()` — sizes.
- Fields: `traces map[string]Trace`, `activities []string`.

### Trace

- `event_list() []Event` — events in chronological order.
- Field: `id string`.

### Event

- Fields: `id`, `activity`, `time`, `sort_key`.
- `same_activity(other) bool`.

### Footprint

- `build_footprint(log) Footprint`.
- `relation(a, b) Relation` — `.causality`, `.concurrency` or `.conflict`.
- `Relation.str()` — `->`, `||` or `#`.

### PetriNet

- `discover_net(log, footprint) PetriNet`.
- Fields: `start_activities`, `end_activities`, `places`, `arcs`.
- `Place` exposes `inputs` and `outputs`; `Place.valid(footprint)` checks a place.
- `Arc` exposes `transition`, `place` and `is_input`.

### Analysis

`Analysis` bundles `eventlog`, `footprint` and `net`. It is what `analyze`
returns and what the renderers accept.

## Renderers

```v
text := alpha.render_text(result, alpha.TextOptions{ summary_only: false })
json := alpha.render_json(result)
dot := alpha.render_dot(result)
```

`alpha.version` holds the current version string.

## Error handling

Discovery functions return V results (`!T`). Malformed rows carry the row
number; unreadable files carry the path and the underlying OS error.
