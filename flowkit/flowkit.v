// Package flowkit discovers process models from activity logs.
//
// Quick start:
//
//	result := flowkit.discover('log.xes')!
//	println(flowkit.render_text(result, flowkit.TextOptions{}))
//
// Extension-aware usage:
//
//	mut reg := flowkit.new_registry()!
//	reg.add_algorithm(my_algorithm)!
//	ctx := flowkit.new_context('log.csv', flowkit.Options{})
//	result := flowkit.run(mut reg, mut ctx)!
module flowkit

import flowkit.model
import flowkit.io
import flowkit.analysis
import flowkit.discovery
import flowkit.conformance
import flowkit.evaluation
import flowkit.export
import flowkit.pipeline as pl
import flowkit.process
import flowkit.streaming
import flowkit.ml
import flowkit.ocel
import flowkit.contracts
import flowkit.registry
import flowkit.builtins
import flowkit.session
import flowkit.hooks

pub const version = contracts.version

pub type Event = model.Event
pub type Trace = model.Trace
pub type EventLog = model.EventLog
pub type Footprint = model.Footprint
pub type PetriNet = model.PetriNet
pub type Place = model.Place
pub type Arc = model.Arc
pub type Dfg = model.Dfg
pub type Stats = model.Stats
pub type Relation = model.Relation
pub type Method = discovery.Method
pub type Filter = analysis.Filter
pub type Options = contracts.Options
pub type Result = contracts.Result
pub type Context = contracts.Context
pub type Registry = registry.Registry
pub type Phase = contracts.Phase
pub type HookSpec = contracts.HookSpec
pub type ReaderSpec = contracts.ReaderSpec
pub type ParserSpec = contracts.ParserSpec
pub type WriterSpec = contracts.WriterSpec
pub type RendererSpec = contracts.RendererSpec
pub type AlgorithmSpec = contracts.AlgorithmSpec
pub type TextOptions = export.TextOptions
pub type ReadOptions = model.ReadOptions
pub type Quality = evaluation.Quality
pub type ConformanceReport = conformance.Report
pub type ReplayResult = conformance.ReplayResult
pub type Alignment = conformance.Alignment

pub fn new_registry() !registry.Registry {
	return builtins.default_registry()
}

pub fn new_context(path string, opts Options) Context {
	return contracts.Context{ path: path, options: opts }
}

pub fn run(mut reg registry.Registry, mut ctx Context) !Result {
	return session.run(mut reg, mut ctx)
}

pub fn run_default(mut ctx Context) !Result {
	return session.run_default(mut ctx)
}

pub fn describe_registry(reg registry.Registry) string {
	return registry.describe(reg)
}

pub fn parse_phase(s string) ?Phase {
	return contracts.parse_phase(s)
}

pub fn normalize_hook() HookSpec {
	return hooks.normalize_activities()
}

pub fn annotate_hook() HookSpec {
	return hooks.annotate()
}

pub fn command_hook(name string, phase Phase, command string) HookSpec {
	return hooks.command(name, phase, command)
}

// discover reads a log and runs the full extension-aware pipeline.
pub fn discover(path string, opts Options) !Result {
	mut ctx := new_context(path, opts)
	return run_default(mut ctx)
}

pub fn discover_heuristic_log(path string, threshold f64, opts Options) !Result {
	mut options := opts
	options.metadata = opts.metadata.clone()
	options.algorithm = 'heuristic'
	options.metadata['threshold'] = threshold.str()
	mut ctx := new_context(path, options)
	return run_default(mut ctx)
}

pub fn new_pipeline(log model.EventLog) pl.Pipeline {
	return pl.new(log)
}

pub fn read_csv(path string, opts model.ReadOptions) !model.EventLog {
	return io.read_csv_fast(path, opts)
}

pub fn parse_csv(content string, opts model.ReadOptions) !model.EventLog {
	return io.parse_csv(content, opts)
}

pub fn read_xes(path string) !model.EventLog {
	return io.read_xes(path)
}

pub fn write_xes(path string, log model.EventLog) ! {
	return io.write_xes(path, log)
}

pub fn build_footprint(log model.EventLog) model.Footprint {
	return analysis.build_footprint(log)
}

pub fn compute_stats(log model.EventLog) model.Stats {
	return analysis.compute_stats(log)
}

pub fn build_dfg(log model.EventLog, min_count u32) model.Dfg {
	return analysis.build_dfg(log, min_count)
}

pub fn filter(log model.EventLog, opts analysis.Filter) model.EventLog {
	return analysis.filter(log, opts)
}

pub fn discover_net(log model.EventLog, fp model.Footprint, method discovery.Method) model.PetriNet {
	return discovery.discover(log, fp, method)
}

pub fn check_footprints(log model.EventLog, net model.PetriNet) conformance.Report {
	return conformance.check_footprints(log, net)
}

pub fn evaluate(log model.EventLog, net model.PetriNet) evaluation.Quality {
	return evaluation.evaluate(log, net)
}

pub fn replay(log model.EventLog, net model.PetriNet) conformance.ReplayResult {
	return conformance.replay(log, net)
}

pub fn align(log model.EventLog, net model.PetriNet, max_states int, max_len int) []conformance.Alignment {
	return conformance.align(log, net, max_states, max_len)
}

pub fn replay_fitness(log model.EventLog, net model.PetriNet) f64 {
	return evaluation.replay_fitness(log, net)
}

pub fn alignment_fitness(log model.EventLog, net model.PetriNet, max_states int, max_len int) f64 {
	return evaluation.alignment_fitness(log, net, max_states, max_len)
}

pub fn precision(log model.EventLog, net model.PetriNet, min_count u32) f64 {
	return evaluation.escaping_edge_precision(log, net, min_count)
}

pub fn generalization(log model.EventLog, net model.PetriNet) f64 {
	return evaluation.generalization(log, net)
}

pub fn render_text(result Result, opts export.TextOptions) string {
	return export.render_text(result.log, result.stats, result.net, result.quality, opts)
}

pub fn render_json(result Result) string {
	return export.render_json(result.log, result.stats, result.net, result.quality)
}

pub fn render_dot(result Result) string {
	return export.render_dot(result.log, result.net)
}

pub fn render_pnml(result Result) string {
	return export.render_pnml(result.net)
}

pub fn write_file(path string, content string) ! {
	return export.write_file(path, content)
}

pub fn process_tree(log model.EventLog) process.ProcessTree {
	return process.from_log(log)
}

pub fn tree_to_petri(tree process.ProcessTree) model.PetriNet {
	return process.to_petri(tree)
}

pub fn render_bpmn(tree process.ProcessTree) string {
	return process.render_bpmn(tree)
}

pub fn stream_csv(path string, opts model.ReadOptions) !streaming.StreamStats {
	return streaming.follow_csv(path, opts)
}

pub fn encode(log model.EventLog, kind string, n int) ml.Features {
	match kind {
		'count', 'count2vec' { return ml.count2vec(log) }
		'ngram' { return ml.ngram(log, if n > 0 { n } else { 2 }) }
		'tfidf' { return ml.tfidf(log) }
		else { return ml.one_hot(log) }
	}
}

pub fn features_csv(features ml.Features) string {
	return ml.to_csv(features)
}

pub fn features_json(features ml.Features) string {
	return ml.to_json(features)
}

pub fn read_ocel(path string) !ocel.OcelLog {
	return ocel.read_ocel_json(path)
}

pub fn ocel_object_types(log ocel.OcelLog) []string {
	return ocel.object_types(log)
}

pub fn ocel_type_graph(log ocel.OcelLog) []ocel.TypeRelation {
	return ocel.object_type_graph(log)
}

pub fn flatten_ocel(log ocel.OcelLog, object_type string) !model.EventLog {
	return ocel.flatten(log, object_type)
}

pub fn ocel_dfg(log ocel.OcelLog, object_type string, min_count u32) model.Dfg {
	return ocel.ocdfg(log, object_type, min_count)
}

pub fn discover_ocel(path string, object_type string, opts Options) !Result {
	mut options := opts
	options.metadata = opts.metadata.clone()
	options.metadata['object_type'] = object_type
	mut ctx := new_context(path, options)
	return run_default(mut ctx)
}
