// Module session runs the extension-aware pipeline: resolve a reader, run
// hooks, analyse, resolve an algorithm, evaluate, then render or write.
module session

import contracts
import registry
import flowkit.builtins
import flowkit.analysis
import flowkit.evaluation
import flowkit.conformance

fn run_hooks(r registry.Registry, phase contracts.Phase, mut ctx contracts.Context) ! {
	for hook in r.hooks_for(phase) {
		hook.run(mut ctx) or {
			return error('hook "${hook.name}" (${phase.str()}) failed: ${err.msg()}')
		}
	}
}

fn method_name(opts contracts.Options) string {
	return match opts.method {
		.alpha_plus { 'alpha+' }
		else { 'alpha' }
	}
}

// run executes one discovery session using the supplied registry.
pub fn run(mut r registry.Registry, mut ctx contracts.Context) !contracts.Result {
	run_hooks(r, .before_read, mut ctx)!

	reader := r.reader_for(ctx.path) or {
		return error('no reader for "${ctx.path}"; available readers: ${r.reader_names().join(', ')}')
	}
	ctx.log = reader.read(ctx.path, ctx.options) or {
		return error('cannot read ${ctx.path}: ${err.msg()}')
	}
	ctx.has_log = true
	run_hooks(r, .after_read, mut ctx)!

	format := ctx.options.metadata['format']
	mut log := ctx.log
	for filter in ctx.options.filters {
		log = analysis.filter(log, filter)
	}
	ctx.log = log
	footprint := analysis.build_footprint(log)

	run_hooks(r, .before_discover, mut ctx)!
	algorithm_name := if ctx.options.algorithm != '' {
		ctx.options.algorithm
	} else {
		method_name(ctx.options)
	}
	algorithm := r.algorithm(algorithm_name) or {
		return error('unknown algorithm "${algorithm_name}"; available: ${r.algorithm_names().join(', ')}')
	}
	net := algorithm.discover(log, footprint, ctx.options) or {
		return error('algorithm ${algorithm_name} failed: ${err.msg()}')
	}
	run_hooks(r, .after_discover, mut ctx)!

	result := contracts.Result{
		log:       log
		footprint: footprint
		net:       net
		stats:     analysis.compute_stats(log)
		quality:   evaluation.evaluate(log, net)
		report:    conformance.check_footprints(log, net)
		dfg:       analysis.build_dfg(log, ctx.options.min_count)
	}
	ctx.result = result
	ctx.has_result = true

	run_hooks(r, .before_write, mut ctx)!
	if ctx.output != '' {
		mut writer_opt := r.writer_for(ctx.output)
		if format != '' {
			writer_opt = r.writer(format)
		}
		writer := writer_opt or {
			return error('no writer for "${format}"; available: ${r.format_names().join(', ')}')
		}
		writer.write(ctx.output, result) or {
			return error('cannot write ${ctx.output}: ${err.msg()}')
		}
	} else {
		renderer_name := if format != '' { format } else { 'text' }
		renderer := r.renderer(renderer_name) or {
			return error('no renderer "${renderer_name}"; available: ${r.format_names().join(', ')}')
		}
		ctx.rendered = renderer.render(result, ctx.options)
	}
	run_hooks(r, .after_write, mut ctx)!
	return ctx.result
}

pub fn run_default(mut ctx contracts.Context) !contracts.Result {
	mut r := registry.new()
	builtins.register_all(mut r)!
	return run(mut r, mut ctx)
}
