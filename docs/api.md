---
title: Library API
---

# Library API

```v
import flowkit
```

## Three levels

```v
// 1. One call — CSV, XES or OCEL by file extension.
result := flowkit.discover('log.xes')!

// 2. Composed pipeline.
log := flowkit.read_csv('log.csv', flowkit.ReadOptions{ delimiter: `,` })!
result2 := flowkit.new_pipeline(log)
	.with_method(.alpha_plus)
	.with_filter(flowkit.Filter{ min_activity_count: 5 })
	.run()

// 3. Extension-aware session.
mut reg := flowkit.new_registry()!
reg.add_algorithm(flowkit.AlgorithmSpec{ name: 'mine', discover: my_algorithm })!
ctx := flowkit.new_context('log.csv', flowkit.Options{ algorithm: 'mine' })
result3 := flowkit.run(mut reg, mut ctx)!
```

## Packages

| Package | Contents |
|---|---|
| `flowkit.model` | `Event`, `Trace`, `EventLog`, `Footprint`, `PetriNet`, `Place`, `Arc`, `Dfg`, `Stats`, `Relation`, `join_key`, `split_key`, `pair_key`, `split_pair` |
| `flowkit.io` | `read_csv`, `read_csv_fast`, `parse_csv`, `read_xes`, `write_xes`, `parse_timestamp` |
| `flowkit.analysis` | `build_footprint`, `compute_stats`, `build_dfg`, `filter` |
| `flowkit.discovery` | `discover`, `discover_heuristic`, `Method.alpha`, `Method.alpha_plus` |
| `flowkit.conformance` | `check_footprints`, `replay`, `align`, `model_sequences` |
| `flowkit.evaluation` | `evaluate`, `replay_fitness`, `alignment_fitness`, `escaping_edge_precision`, `generalization` |
| `flowkit.export` | `render_text`, `render_json`, `render_dot`, `render_pnml`, `write_file` |
| `flowkit.pipeline` | `Pipeline`, `Result` |
| `flowkit.process` | `ProcessTree`, `from_log`, `to_petri`, `render_bpmn` |
| `flowkit.streaming` | `StreamStats`, `push`, `follow_csv`, `dfg`, `top_activities` |
| `flowkit.ml` | `one_hot`, `count2vec`, `ngram`, `tfidf`, `to_csv`, `to_json` |
| `flowkit.ocel` | `read_ocel_json`, `write_ocel_json`, `flatten`, `object_types`, `object_type_graph`, `ocdfg` |
| `flowkit.contracts` | `Options`, `Result`, `Context`, `Phase`, six `*_Spec` types |
| `flowkit.registry` | `Registry`, `new`, `add_*`, `reader_for`, `writer`, `renderer`, `algorithm`, `hooks_for`, `describe` |
| `flowkit.builtins` | `register_all`, `default_registry` |
| `flowkit.hooks` | `normalize_activities`, `annotate`, `command` |
| `flowkit.session` | `run`, `run_default` |

## Key types

- `EventLog` — `trace_count()`, `activity_count()`, `event_count()`,
  `trace(id) ?Trace` (returns `none` for an absent case), `activity_names()`,
  `activity_id(name)`
- `Footprint` — `relation(a, b)`, `relation_id(i, j)`, `direct_id(i, j)`,
  `activity_names()`
- `PetriNet` — `places`, `arcs`, `start_activities`, `end_activities`
- `Result` — `log`, `footprint`, `net`, `stats`, `quality`, `report`, `dfg`
- `Quality` — `fitness_proxy`, `precision_proxy`, `simplicity`, `arc_degree`
- `Options` — `method`, `algorithm`, `filters`, `delimiter`, `header`,
  `min_count`, `metadata` (used by extension implementations)

## Conformance and extension helpers

```v
fitness := flowkit.replay(result.log, result.net).fitness
alignments := flowkit.align(result.log, result.net, 200, 8)
precision := flowkit.precision(result.log, result.net, 1)

mut reg := flowkit.new_registry()!
reg.add_renderer(flowkit.RendererSpec{ name: 'mine', render: my_renderer })!
```

## Error handling

Readers, `discover`, `run` and writers return V results (`!T`). Errors carry the
file path and row number where possible. Composite keys are length-prefixed, so
activity or object names containing `>` cannot collide.

## Compatibility

`flowkit.discover`, the `render_*` functions, `new_pipeline` and every CLI flag
continue to work as thin wrappers over a default registry.
