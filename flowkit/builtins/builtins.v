// Module builtins registers every format and algorithm that ships with
// flowkit. Third-party packages can register extensions the same way.
module builtins

import contracts
import registry
import flowkit.model
import flowkit.io
import flowkit.discovery
import flowkit.export
import flowkit.process
import flowkit.ocel

fn builtin_read_csv(path string, opts contracts.Options) !model.EventLog {
	return io.read_csv_fast(path, model.ReadOptions{ delimiter: opts.delimiter, header: opts.header })
}

fn builtin_read_xes(path string, opts contracts.Options) !model.EventLog {
	_ = opts
	return io.read_xes(path)
}

fn builtin_read_ocel(path string, opts contracts.Options) !model.EventLog {
	log := ocel.read_ocel_json(path)!
	return ocel.flatten(log, opts.metadata['object_type'])
}

fn builtin_parse_csv(content string, opts contracts.Options) !model.EventLog {
	return io.parse_csv(content, model.ReadOptions{ delimiter: opts.delimiter, header: opts.header })
}

fn builtin_alpha(log model.EventLog, fp model.Footprint, opts contracts.Options) !model.PetriNet {
	_ = opts
	return discovery.discover(log, fp, .alpha)
}

fn builtin_alpha_plus(log model.EventLog, fp model.Footprint, opts contracts.Options) !model.PetriNet {
	_ = opts
	return discovery.discover(log, fp, .alpha_plus)
}

fn builtin_heuristic(log model.EventLog, fp model.Footprint, opts contracts.Options) !model.PetriNet {
	mut threshold := 0.5
	if opts.metadata['threshold'] != '' {
		threshold = opts.metadata['threshold'].f64()
	}
	return discovery.discover_heuristic(log, fp, threshold)
}

fn builtin_render_text(result contracts.Result, opts contracts.Options) string {
	_ = opts
	return export.render_text(result.log, result.stats, result.net, result.quality, export.TextOptions{})
}

fn builtin_render_json(result contracts.Result, opts contracts.Options) string {
	_ = opts
	return export.render_json(result.log, result.stats, result.net, result.quality)
}

fn builtin_render_dot(result contracts.Result, opts contracts.Options) string {
	_ = opts
	return export.render_dot(result.log, result.net)
}

fn builtin_render_pnml(result contracts.Result, opts contracts.Options) string {
	_ = opts
	return export.render_pnml(result.net)
}

fn builtin_render_bpmn(result contracts.Result, opts contracts.Options) string {
	_ = opts
	return process.render_bpmn(process.from_log(result.log))
}

fn builtin_render_xes(result contracts.Result, opts contracts.Options) string {
	_ = result
	_ = opts
	return ''
}

fn builtin_write_text(path string, result contracts.Result) ! {
	export.write_file(path, builtin_render_text(result, contracts.Options{}))!
}

fn builtin_write_json(path string, result contracts.Result) ! {
	export.write_file(path, builtin_render_json(result, contracts.Options{}))!
}

fn builtin_write_dot(path string, result contracts.Result) ! {
	export.write_file(path, builtin_render_dot(result, contracts.Options{}))!
}

fn builtin_write_pnml(path string, result contracts.Result) ! {
	export.write_file(path, builtin_render_pnml(result, contracts.Options{}))!
}

fn builtin_write_bpmn(path string, result contracts.Result) ! {
	export.write_file(path, builtin_render_bpmn(result, contracts.Options{}))!
}

fn builtin_write_xes(path string, result contracts.Result) ! {
	io.write_xes(path, result.log)!
}

// register_all adds the built-in readers, parsers, writers, renderers and
// algorithms to the given registry.
pub fn register_all(mut r registry.Registry) ! {
	r.add_reader(contracts.ReaderSpec{ name: 'csv', extensions: ['csv'], read: builtin_read_csv })!
	r.add_reader(contracts.ReaderSpec{ name: 'xes', extensions: ['xes'], read: builtin_read_xes })!
	r.add_reader(contracts.ReaderSpec{ name: 'ocel', extensions: ['json', 'jsonocel'], read: builtin_read_ocel })!
	r.add_parser(contracts.ParserSpec{ name: 'csv', extensions: ['csv'], parse: builtin_parse_csv })!
	r.add_writer(contracts.WriterSpec{ name: 'text', extensions: ['txt'], write: builtin_write_text })!
	r.add_writer(contracts.WriterSpec{ name: 'json', extensions: ['json'], write: builtin_write_json })!
	r.add_writer(contracts.WriterSpec{ name: 'dot', extensions: ['dot', 'gv'], write: builtin_write_dot })!
	r.add_writer(contracts.WriterSpec{ name: 'pnml', extensions: ['pnml'], write: builtin_write_pnml })!
	r.add_writer(contracts.WriterSpec{ name: 'bpmn', extensions: ['bpmn'], write: builtin_write_bpmn })!
	r.add_writer(contracts.WriterSpec{ name: 'xes', extensions: ['xes'], write: builtin_write_xes })!
	r.add_renderer(contracts.RendererSpec{ name: 'text', render: builtin_render_text })!
	r.add_renderer(contracts.RendererSpec{ name: 'json', render: builtin_render_json })!
	r.add_renderer(contracts.RendererSpec{ name: 'dot', render: builtin_render_dot })!
	r.add_renderer(contracts.RendererSpec{ name: 'pnml', render: builtin_render_pnml })!
	r.add_renderer(contracts.RendererSpec{ name: 'bpmn', render: builtin_render_bpmn })!
	r.add_renderer(contracts.RendererSpec{ name: 'xes', render: builtin_render_xes })!
	r.add_algorithm(contracts.AlgorithmSpec{ name: 'alpha', discover: builtin_alpha })!
	r.add_algorithm(contracts.AlgorithmSpec{ name: 'alpha+', discover: builtin_alpha_plus })!
	r.add_algorithm(contracts.AlgorithmSpec{ name: 'heuristic', discover: builtin_heuristic })!
}

pub fn default_registry() !registry.Registry {
	mut r := registry.new()
	register_all(mut r)!
	return r
}
