// Module pipeline composes the analysis stages into a single reproducible run.
module pipeline

import flowkit.model
import flowkit.analysis
import flowkit.discovery
import flowkit.conformance
import flowkit.evaluation

pub struct Result {
pub:
	log       model.EventLog
	footprint model.Footprint
	net       model.PetriNet
	stats     model.Stats
	quality   evaluation.Quality
	report    conformance.Report
	dfg       model.Dfg
}

pub struct Pipeline {
pub:
	log model.EventLog
mut:
	method    discovery.Method = .alpha
	filters   []analysis.Filter
	min_count u32 = 1
}

pub fn new(log model.EventLog) Pipeline {
	return Pipeline{ log: log }
}

pub fn (p Pipeline) with_method(m discovery.Method) Pipeline {
	mut q := p
	q.method = m
	return q
}

pub fn (p Pipeline) with_filter(f analysis.Filter) Pipeline {
	mut q := p
	q.filters << f
	return q
}

pub fn (p Pipeline) with_min_count(n u32) Pipeline {
	mut q := p
	q.min_count = n
	return q
}

pub fn (p Pipeline) run() Result {
	mut log := p.log
	for filter in p.filters {
		log = analysis.filter(log, filter)
	}
	footprint := analysis.build_footprint(log)
	net := discovery.discover(log, footprint, p.method)
	return Result{
		log:       log
		footprint: footprint
		net:       net
		stats:     analysis.compute_stats(log)
		quality:   evaluation.evaluate(log, net)
		report:    conformance.check_footprints(log, net)
		dfg:       analysis.build_dfg(log, p.min_count)
	}
}
