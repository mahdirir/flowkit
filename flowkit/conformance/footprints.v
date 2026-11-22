// Module conformance compares an event log with a discovered model.
module conformance

import flowkit.model
import flowkit.analysis

pub struct Report {
pub:
	consistent  bool
	differences []string
	log_edges   int
	model_edges int
}

pub fn check_footprints(log model.EventLog, net model.PetriNet) Report {
	log_fp := analysis.build_footprint(log)
	n := log.activity_count()
	mut model_causal := []bool{len: n * n, init: false}
	for place in net.places {
		for a in place.inputs {
			ia := log.activity_id(a)
			if ia < 0 {
				continue
			}
			for b in place.outputs {
				ib := log.activity_id(b)
				if ib >= 0 {
					model_causal[ia * n + ib] = true
				}
			}
		}
	}
	mut differences := []string{}
	mut log_edges := 0
	mut model_edges := 0
	for a := 0; a < n; a++ {
		for b := 0; b < n; b++ {
			log_rel := log_fp.relation_id(a, b)
			if log_rel == .causality {
				log_edges++
			}
			if model_causal[a * n + b] {
				model_edges++
			}
			if log_rel == .causality && !model_causal[a * n + b] {
				differences << '${log.activities[a]} -> ${log.activities[b]} observed but not modelled'
			} else if log_rel != .causality && model_causal[a * n + b] {
				differences << '${log.activities[a]} -> ${log.activities[b]} modelled but not observed'
			}
		}
	}
	return Report{
		consistent:  differences.len == 0
		differences: differences
		log_edges:   log_edges
		model_edges: model_edges
	}
}
