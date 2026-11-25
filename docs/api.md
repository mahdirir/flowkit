---
title: Library API
---

# Library API

```v
import flowkit
```

All facade functions live in `flowkit/flowkit.v` and re-export the
sub-packages under short aliases (`flowkit.EventLog`, `flowkit.Options`,
`flowkit.Result`, ...). Import sub-packages directly for smaller binaries:
`flowkit.model`, `flowkit.io`, `flowkit.analysis`, etc.

## Three levels

```v
// 1. One call — CSV, XES or OCEL by file extension.
result := flowkit.discover('log.xes', flowkit.Options{})!

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

## Session and registry

| Signature | Purpose |
|---|---|
| `new_registry() !Registry` | Default registry with CSV/XES/OCEL readers, all writers/renderers, `alpha`/`alpha+`/`heuristic`, built-in hooks |
| `new_context(path string, opts Options) Context` | Fresh pipeline context for `path` |
| `run(mut reg Registry, mut ctx Context) !Result` | Full extension-aware run: readers → filters → algorithm → evaluate → writer/renderer, with `before/after_*` hooks |
| `run_default(mut ctx Context) !Result` | Same as `run` with the default registry |
| `describe_registry(reg Registry) string` | Human-readable `readers / writers / algorithms / hooks` listing (same as `--list-formats`) |
| `parse_phase(s string) ?Phase` | Parse `before_read`, `after_read`, `before_discover`, `after_discover`, `before_write`, `after_write` |
| `normalize_hook() HookSpec` | Built-in `after_read` hook: trims activity names |
| `annotate_hook() HookSpec` | Built-in hook: adds metadata annotations |
| `command_hook(name string, phase Phase, command string) HookSpec` | External `CMD` hook, run via arg array without a shell |

`Options`, `Result`, `Context` are aliases of `contracts.Options`,
`contracts.Result`, `contracts.Context`:

```v
// contracts.Options — shared config, passed to every extension.
Options{
  method    Method = .alpha // .alpha | .alpha_plus
  min_count u32 = 1         // DFG edge threshold
  filters   []Filter        // applied in order
  delimiter u8 = `;`
  header    bool = true
  algorithm string          // overrides method when set: 'alpha', 'alpha+', 'heuristic', or custom
  metadata  map[string]string // 'threshold', 'format', 'object_type', ...
}

// contracts.Result — complete output of one run.
Result{ log EventLog; footprint Footprint; net PetriNet; stats Stats;
        quality Quality; report Report; dfg Dfg }

// contracts.Context — mutable pipeline state shared with hooks.
Context{ path string; options Options; log EventLog; has_log bool;
         footprint Footprint; net PetriNet; result Result; has_result bool;
         output string; rendered string; metadata map[string]string }
```

## Ingest

| Signature | Purpose |
|---|---|
| `read_csv(path string, opts ReadOptions) !EventLog` | Fast CSV reader (default) |
| `parse_csv(content string, opts ReadOptions) !EventLog` | Parse CSV from a string |
| `read_xes(path string) !EventLog` | XES 1.0 `<trace>`/`<event>` reader |
| `write_xes(path string, log EventLog) !` | Write log back to XES |
| `read_ocel(path string) !OcelLog` | OCEL 2.0 JSON reader |
| `stream_csv(path string, opts ReadOptions) !StreamStats` | Incremental `follow_csv` summary |

```v
// model.ReadOptions
ReadOptions{
  delimiter    u8 = `;`
  case_col     int      // default 0
  time_col     int = 1
  event_col    int = 2
  activity_col int = 3
  header       bool = true
}
```

Timestamps accept `YYYY-MM-DD HH:mm:ss` or `DD-MM-YYYY HH:mm:ss`, digits only.
Rows group by case id, sort by numeric timestamp key; repeated event ids are
ignored, repeated activities are kept so loops stay visible.

## Log model

```v
log.trace_count() int
log.activity_count() int
log.event_count() int
log.activity_names() []string
log.trace(id string) ?Trace        // none for absent case
log.activity_id(name string) int   // -1 when absent
trace.event_list() []Event
trace.raw_events() []Event
```

Helpers: `join_key`, `split_key`, `pair_key`, `split_pair` (length-prefixed, so
names containing `>` or `:` cannot collide), `timestamp_key(...) i64`.

## Analysis

| Signature | Purpose |
|---|---|
| `build_footprint(log EventLog) Footprint` | Flat `n × n` causality / concurrency / conflict matrix |
| `compute_stats(log EventLog) Stats` | Traces, activities, events, variants, frequencies, rework |
| `build_dfg(log EventLog, min_count u32) Dfg` | Directly-follows edges with `count >= min_count` |
| `filter(log EventLog, opts Filter) EventLog` | Return a filtered copy |

```v
// analysis.Filter — all fields are opt-in.
Filter{
  min_events         int
  max_events         int
  keep_activities    []string
  drop_activities    []string
  min_activity_count int
  from_key           i64  // timestamp_key(...) range
  to_key             i64
  max_variants       int  // keep N most frequent variants
}
```

```v
fp.relation(a string, b string) Relation   // .causality | .concurrency | .conflict
fp.relation_id(a int, b int) Relation
fp.direct_id(a int, b int) u32
fp.activity_names() []string
stats.duration_seconds() f64
stats.top_activities(limit int) []string
```

## Discovery

| Signature | Purpose |
|---|---|
| `discover(path string, opts Options) !Result` | Read + full default pipeline |
| `discover_heuristic_log(path string, threshold f64, opts Options) !Result` | Heuristic miner with dependency threshold (default `0.5`) |
| `discover_ocel(path string, object_type string, opts Options) !Result` | Project OCEL onto one object type, then discover |
| `discover_net(log EventLog, fp Footprint, method Method) PetriNet` | `Method.alpha` or `Method.alpha_plus` (short loops add `(a, a)` places) |
| `new_pipeline(log EventLog) Pipeline` | Composable `with_method` / `with_filter` / `with_min_count` / `run()` |

## Conformance and quality

| Signature | Purpose |
|---|---|
| `check_footprints(log EventLog, net PetriNet) Report` | Log vs. net footprint comparison |
| `replay(log EventLog, net PetriNet) ReplayResult` | Token replay with `fitness`, missing/remaining tokens |
| `align(log EventLog, net PetriNet, max_states int, max_len int) []Alignment` | Bounded alignments (`fitness` per trace) |
| `evaluate(log EventLog, net PetriNet) Quality` | Structural proxies (fast, same-log comparisons) |
| `replay_fitness(log EventLog, net PetriNet) f64` | Exact replay fitness |
| `alignment_fitness(log EventLog, net PetriNet, max_states int, max_len int) f64` | Mean alignment fitness |
| `precision(log EventLog, net PetriNet, min_count u32) f64` | Escaping-edge precision |
| `generalization(log EventLog, net PetriNet) f64` | Transition coverage |

```v
// evaluation.Quality
Quality{ fitness_proxy f64; precision_proxy f64; simplicity f64;
         arc_degree f64; places int; arcs int }

fitness := flowkit.replay(result.log, result.net).fitness
aligns  := flowkit.align(result.log, result.net, 200, 8)
prec    := flowkit.precision(result.log, result.net, 1)
```

`_proxy` marks structural estimates, not replay measurements. See
[Algorithms](algorithm.md).

## Export

| Signature | Purpose |
|---|---|
| `render_text(result Result, opts TextOptions) string` | Summary, stats, places, arcs; `summary_only` / `explain` |
| `render_json(result Result) string` | Summary, quality, activities, places, arcs |
| `render_dot(result Result) string` | Graphviz (`box` transitions, `circle` places) |
| `render_pnml(result Result) string` | PNML with sanitised `NCName` transition ids |
| `render_bpmn(tree ProcessTree) string` | BPMN 2.0 XML from a process tree |
| `write_file(path string, content string) !` | Write any rendered output |

```v
// export.TextOptions
TextOptions{ summary_only bool; footprint bool = true; explain bool }
```

## Process trees

| Signature | Purpose |
|---|---|
| `process_tree(log EventLog) ProcessTree` | Mine a process tree from the log |
| `tree_to_petri(tree ProcessTree) PetriNet` | Convert tree → Petri net |
| `render_bpmn(tree ProcessTree) string` | Tree → BPMN 2.0 |

Constructors: `activity(name)`, `sequence(children)`, `choice(children)`,
`parallel(children)`, `loop(child)` with `Operator` enum.

## Streaming

```v
mut s := streaming.new()
s.push(case_id string, activity string)
s.case_count() int
s.activity_count() int
s.dfg(min_count u32) Dfg
s.top_activities(limit int) []string
follow_csv(path string, opts ReadOptions) !StreamStats
```

## ML features

| Signature | Purpose |
|---|---|
| `encode(log EventLog, kind string, n int) Features` | `onehot` (default), `count`/`count2vec`, `ngram`, `tfidf` |
| `features_csv(features Features) string` | `case_id` header + `%.6f` values, deterministic column order |
| `features_json(features Features) string` | `{ names, case_ids, rows }` |

```v
// ml.Features
Features{ names []string; case_ids []string; rows [][]f64 }
```

## OCEL 2.0

| Signature | Purpose |
|---|---|
| `ocel_object_types(log OcelLog) []string` | All object types in the log |
| `ocel_type_graph(log OcelLog) []TypeRelation` | Co-occurrence graph |
| `flatten_ocel(log OcelLog, object_type string) !EventLog` | Project onto one object type |
| `ocel_dfg(log OcelLog, object_type string, min_count u32) Dfg` | Object-centric DFG |

## Registry (extensions)

```v
mut reg := flowkit.new_registry()!
reg.add_reader(ReaderSpec{ name: 'csv', extensions: ['csv'], read: my_read })!
reg.add_parser(ParserSpec{ name: 'csv', extensions: ['csv'], parse: my_parse })!
reg.add_writer(WriterSpec{ name: 'pnml', extensions: ['pnml'], write: my_write })!
reg.add_renderer(RendererSpec{ name: 'mine', render: my_render })!
reg.add_algorithm(AlgorithmSpec{ name: 'mine', discover: my_discover })!
reg.add_hook(HookSpec{ name: 'h', phase: .after_write, run: my_hook })!

reg.reader_for(path) ?ReaderSpec
reg.writer(name) ?WriterSpec
reg.writer_for(path) ?WriterSpec
reg.renderer(name) ?RendererSpec
reg.algorithm(name) ?AlgorithmSpec
reg.hooks_for(phase) []HookSpec
reg.format_names() []string
reg.reader_names() []string
reg.algorithm_names() []string
```

Duplicate reader/parser/writer/renderer/algorithm names are rejected; hooks
allow the same name on different phases. See
[Extending](extending.md).

## Packages

| Package | Contents |
|---|---|
| `flowkit.model` | `Event`, `Trace`, `EventLog`, `Footprint`, `PetriNet`, `Place`, `Arc`, `Dfg`, `Stats`, `Relation`, `join_key`, `split_key`, `pair_key`, `split_pair` |
| `flowkit.io` | `read_csv`, `read_csv_fast`, `read_csv_smart`, `parse_csv`, `read_xes`, `write_xes`, `parse_timestamp` |
| `flowkit.analysis` | `build_footprint`, `compute_stats`, `build_dfg`, `filter`, `Filter` |
| `flowkit.discovery` | `discover`, `discover_heuristic`, `Method.alpha`, `Method.alpha_plus` |
| `flowkit.conformance` | `check_footprints`, `replay`, `align`, `model_sequences`, `Report`, `ReplayResult`, `Alignment` |
| `flowkit.evaluation` | `evaluate`, `replay_fitness`, `alignment_fitness`, `escaping_edge_precision`, `generalization`, `Quality` |
| `flowkit.export` | `render_text`, `render_json`, `render_dot`, `render_pnml`, `write_file`, `TextOptions` |
| `flowkit.pipeline` | `Pipeline`, `Result`, `new`, `with_method`, `with_filter`, `with_min_count`, `run` |
| `flowkit.process` | `ProcessTree`, `from_log`, `to_petri`, `render_bpmn`, `activity`, `sequence`, `choice`, `parallel`, `loop` |
| `flowkit.streaming` | `StreamStats`, `new`, `push`, `follow_csv`, `dfg`, `top_activities` |
| `flowkit.ml` | `one_hot`, `count2vec`, `ngram`, `tfidf`, `to_csv`, `to_json`, `Features` |
| `flowkit.ocel` | `read_ocel_json`, `write_ocel_json`, `flatten`, `object_types`, `object_type_graph`, `ocdfg`, `OcelLog`, `TypeRelation` |
| `flowkit.contracts` | `Options`, `Result`, `Context`, `Phase`, six `*_Spec` types, `version` |
| `flowkit.registry` | `Registry`, `new`, `add_*`, `reader_for`, `writer`, `renderer`, `algorithm`, `hooks_for`, `describe` |
| `flowkit.builtins` | `register_all`, `default_registry` |
| `flowkit.hooks` | `normalize_activities`, `annotate`, `command` |
| `flowkit.session` | `run`, `run_default` |

## Error handling

Readers, `discover`, `run` and writers return V results (`!T`). Errors carry the
file path and row number where possible. Composite keys are length-prefixed, so
activity or object names containing `>` cannot collide.

## Compatibility

`flowkit.discover`, the `render_*` functions, `new_pipeline` and every CLI flag
continue to work as thin wrappers over a default registry.
