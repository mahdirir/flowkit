---
title: Library API
---

# Library API

```v
import flowkit
```

## Three levels

```v
// 1. One call.
result := flowkit.discover('log.xes')!

// 2. Composed pipeline.
log := flowkit.read_csv('log.csv', flowkit.ReadOptions{ delimiter: `,` })!
result2 := flowkit.new_pipeline(log)
	.with_method(.alpha_plus)
	.with_filter(flowkit.Filter{ min_activity_count: 5 })
	.run()

// 3. Raw building blocks.
fp := flowkit.build_footprint(log)
net := flowkit.discover_net(log, fp, .alpha)
```

## Packages

| Package | Contents |
|---|---|
| `flowkit.model` | `Event`, `Trace`, `EventLog`, `Footprint`, `PetriNet`, `Place`, `Arc`, `Dfg`, `Stats`, `Relation` |
| `flowkit.io` | `read_csv`, `parse_csv`, `read_xes`, `write_xes` |
| `flowkit.analysis` | `build_footprint`, `compute_stats`, `build_dfg`, `filter` |
| `flowkit.discovery` | `discover`, `discover_heuristic`, `Method.alpha`, `Method.alpha_plus` |
| `flowkit.conformance` | `check_footprints` |
| `flowkit.evaluation` | `evaluate` |
| `flowkit.export` | `render_text`, `render_json`, `render_dot`, `render_pnml` |
| `flowkit.pipeline` | `Pipeline`, `Result` |
| `flowkit.process` | `ProcessTree`, `from_log`, `to_petri`, `render_bpmn` |
| `flowkit.streaming` | `StreamStats`, `push`, `follow_csv`, `dfg` |
| `flowkit.ml` | `one_hot`, `count2vec`, `ngram`, `tfidf`, `to_csv`, `to_json` |
| `flowkit.ocel` | `read_ocel_json`, `flatten`, `object_types`, `object_type_graph`, `ocdfg`, `write_ocel_json` |

## Key types

- `EventLog` — `trace_count()`, `activity_count()`, `event_count()`, `trace(id)`, `activity_names()`
- `Footprint` — `relation(a, b)`, `relation_id(i, j)`, `direct_id(i, j)`, `activity_names()`
- `PetriNet` — `places`, `arcs`, `start_activities`, `end_activities`
- `Result` — `log`, `footprint`, `net`, `stats`, `quality`, `report`, `dfg`
- `Quality` — `fitness_proxy`, `precision_proxy`, `simplicity`, `arc_degree`
- Conformance — `replay(log, net)`, `align(log, net, max_states, max_len)`, `replay_fitness`, `alignment_fitness`, `precision`, `generalization`

## Error handling

All readers and the top-level `discover` return V results (`!T`). Errors carry
the file path and row number where possible.
