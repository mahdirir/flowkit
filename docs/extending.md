---
title: Extending flowkit
---

# Extending flowkit

flowkit is built from typed extension records. Built-in formats and algorithms
are registered exactly like third-party ones, so there is no separate plugin
API to learn.

## Extension points

| Spec | Purpose |
|---|---|
| `ReaderSpec` | path → `EventLog` (e.g. a new log format) |
| `ParserSpec` | string → `EventLog` (e.g. inline content) |
| `WriterSpec` | result → file |
| `RendererSpec` | result → string (stdout) |
| `AlgorithmSpec` | log + footprint → `PetriNet` |
| `HookSpec` | run at one of six pipeline phases |

The phases are `before_read`, `after_read`, `before_discover`,
`after_discover`, `before_write` and `after_write`. Duplicate names are rejected
for readers, parsers, writers, renderers, algorithms, and for hooks with the
same name *and* phase.

## Registering an extension

```v
import flowkit

fn my_algorithm(log flowkit.EventLog, fp flowkit.Footprint, opts flowkit.Options) !flowkit.PetriNet {
	return flowkit.discover_net(log, fp, .alpha)
}

mut reg := flowkit.new_registry()!
reg.add_algorithm(flowkit.AlgorithmSpec{ name: 'mine', discover: my_algorithm })!

ctx := flowkit.new_context('log.csv', flowkit.Options{ algorithm: 'mine' })
result := flowkit.run(mut reg, mut ctx)!
```

A full example package — custom reader, algorithm and hook — lives in
[`examples/plugins/custom.v`](https://github.com/metif12/flowkit/blob/main/examples/plugins/custom.v),
with a test that registers it.

## External command hooks

For runtime extensions written in any language, register a command hook:

```bash
flowkit -i log.csv --hook after_write="python annotate.py"
```

flowkit writes a flat JSON context file with a UUID-based name in the system
temp directory and passes its path as the final argument. The program edits the
file in place; recognised keys (`path`, `output`, `rendered` and any metadata
keys) are read back into the context. See
[`examples/plugins/annotate.py`](https://github.com/metif12/flowkit/blob/main/examples/plugins/annotate.py).

Commands are split on spaces and executed via an argument array without a
shell. Hooks are opt-in; no external program runs unless you register one.

## Discovery

```bash
flowkit --list-formats
```

Example output:

```
readers:    csv, ocel, xes
writers:    bpmn, dot, json, pnml, text, xes
algorithms: alpha, alpha+, heuristic
hooks:      0
```

Unknown format or algorithm names list the available choices.

## Context contract

Hooks receive a `Context` with `path`, `options`, `log`, `footprint`, `net`,
`result`, `output`, `rendered` and `metadata`. The session updates `ctx.log`
after filtering, so `after_discover` hooks see the same log the algorithm used.
`--dry-run` withholds the output path from the context, so no file is written.

## Compatibility

`flowkit.discover`, `flowkit.render_*`, `flowkit.new_pipeline` and every existing
CLI flag continue to work. They are thin wrappers over a registry with only the
built-ins registered.
