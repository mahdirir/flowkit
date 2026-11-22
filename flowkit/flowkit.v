// Package flowkit discovers process models from activity logs.
//
// Quick start:
//
//	result := flowkit.discover('log.xes')!
//	println(flowkit.render_text(result, flowkit.TextOptions{}))
//
// For more control, use a pipeline:
//
//	result := flowkit.new_pipeline(log).with_method(.alpha_plus).run()
module flowkit

import flowkit.model
import flowkit.io
import flowkit.analysis
import flowkit.discovery
import flowkit.conformance
import flowkit.evaluation
import flowkit.export
import flowkit.pipeline as pl

pub const version = '1.1.0'

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
pub type Result = pl.Result
pub type TextOptions = export.TextOptions
pub type Quality = evaluation.Quality
pub type ConformanceReport = conformance.Report
pub type ReplayResult = conformance.ReplayResult
pub type Alignment = conformance.Alignment

pub struct Options {
pub:
	method    discovery.Method = .alpha
	min_count u32              = 1
	filters   []analysis.Filter
	delimiter u8   = `;`
	header    bool = true
}

// discover reads a CSV or XES log and runs the full pipeline in one call.
pub fn discover(path string, opts Options) !pl.Result {
	log := if path.ends_with('.xes') {
		io.read_xes(path)!
	} else {
		io.read_csv(path, model.ReadOptions{
			delimiter: opts.delimiter
			header:    opts.header
		})!
	}
	mut pipe := pl.new(log).with_method(opts.method).with_min_count(opts.min_count)
	for filter in opts.filters {
		pipe = pipe.with_filter(filter)
	}
	return pipe.run()
}

pub fn new_pipeline(log model.EventLog) pl.Pipeline {
	return pl.new(log)
}

pub fn read_csv(path string, opts model.ReadOptions) !model.EventLog {
	return io.read_csv(path, opts)
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

pub fn render_text(result pl.Result, opts export.TextOptions) string {
	return export.render_text(result.log, result.stats, result.net, result.quality, opts)
}

pub fn render_json(result pl.Result) string {
	return export.render_json(result.log, result.stats, result.net, result.quality)
}

pub fn render_dot(result pl.Result) string {
	return export.render_dot(result.log, result.net)
}

pub fn render_pnml(result pl.Result) string {
	return export.render_pnml(result.net)
}

pub fn write_file(path string, content string) ! {
	return export.write_file(path, content)
}
