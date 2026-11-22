// Module evaluation computes model quality indicators.
//
// The metrics here are fast structural proxies, not exact token-replay or
// alignment-based measures. They are useful for comparing models from the
// same log; the names carry the `_proxy` suffix to make that explicit.
module evaluation

import flowkit.model
import flowkit.analysis
import flowkit.conformance

pub struct Quality {
pub:
	fitness_proxy   f64
	precision_proxy f64
	simplicity      f64
	arc_degree      f64
	places          int
	arcs            int
}

pub fn evaluate(log model.EventLog, net model.PetriNet) Quality {
	fp := footprint_from(log)
	n := log.activity_count()
	mut observed := 0
	mut modelled := 0
	for a := 0; a < n; a++ {
		for b := 0; b < n; b++ {
			seen := fp.relation_id(a, b) == .causality
			mut present := false
			for place in net.places {
				if place.inputs.contains(log.activities[a]) && place.outputs.contains(log.activities[b]) {
					present = true
					break
				}
			}
			if seen {
				observed++
			}
			if present {
				modelled++
			}
		}
	}
	mut covered := 0
	if observed > 0 {
		for a := 0; a < n; a++ {
			for b := 0; b < n; b++ {
				if fp.relation_id(a, b) != .causality {
					continue
				}
				for place in net.places {
					if place.inputs.contains(log.activities[a]) && place.outputs.contains(log.activities[b]) {
						covered++
						break
					}
				}
			}
		}
	}
	fitness := if observed == 0 { 1.0 } else { f64(covered) / f64(observed) }
	precision := if modelled == 0 { 1.0 } else { f64(covered) / f64(modelled) }
	nodes := net.places.len + n
	degree := if nodes == 0 { 0.0 } else { f64(net.arcs.len) / f64(nodes) }
	simplicity := 1.0 / (1.0 + degree)
	return Quality{
		fitness_proxy:   fitness
		precision_proxy: precision
		simplicity:      simplicity
		arc_degree:      degree
		places:          net.places.len
		arcs:            net.arcs.len
	}
}

pub fn replay_fitness(log model.EventLog, net model.PetriNet) f64 {
	return conformance.replay(log, net).fitness
}

pub fn alignment_fitness(log model.EventLog, net model.PetriNet, max_states int, max_len int) f64 {
	alignments := conformance.align(log, net, max_states, max_len)
	if alignments.len == 0 {
		return 1.0
	}
	mut total := 0.0
	for alignment in alignments {
		total += alignment.fitness
	}
	return total / f64(alignments.len)
}

pub fn escaping_edge_precision(log model.EventLog, net model.PetriNet, min_count u32) f64 {
	log_dfg := analysis.build_dfg(log, 1)
	mut observed := map[string]bool{}
	for edge in log_dfg.edges {
		observed['${edge.from}>${edge.to}'] = true
	}

	mut max_len := 2
	for _, trace in log.traces {
		if trace.raw_events().len + 2 > max_len {
			max_len = trace.raw_events().len + 2
		}
	}
	sequences := conformance.model_sequences(net, 500, max_len)
	mut counts := map[string]int{}
	for sequence in sequences {
		for i := 1; i < sequence.len; i++ {
			counts['${sequence[i - 1]}>${sequence[i]}']++
		}
	}
	mut model_edges := 0
	mut escaping := 0
	for edge, count in counts {
		if u32(count) < min_count {
			continue
		}
		model_edges++
		if edge !in observed {
			escaping++
		}
	}
	if model_edges == 0 {
		return 1.0
	}
	return 1.0 - f64(escaping) / f64(model_edges)
}

pub fn generalization(log model.EventLog, net model.PetriNet) f64 {
	mut transitions := []string{}
	for arc in net.arcs {
		if arc.transition !in transitions {
			transitions << arc.transition
		}
	}
	if transitions.len == 0 {
		return 1.0
	}
	mut seen := 0
	for activity in log.activities {
		if activity in transitions {
			seen++
		}
	}
	return f64(seen) / f64(transitions.len)
}

fn footprint_from(log model.EventLog) model.Footprint {
	mut ids := map[string]int{}
	for i, name in log.activities {
		ids[name] = i
	}
	n := log.activities.len
	mut direct := []u32{len: n * n, init: 0}
	for _, trace in log.traces {
		events := trace.raw_events()
		for i := 1; i < events.len; i++ {
			prev := events[i - 1].activity
			cur := events[i].activity
			direct[ids[prev] * n + ids[cur]]++
		}
	}
	mut matrix := []model.Relation{len: n * n, init: .conflict}
	for a := 0; a < n; a++ {
		for b := 0; b < n; b++ {
			f := direct[a * n + b] > 0
			r := direct[b * n + a] > 0
			if f && r {
				matrix[a * n + b] = .concurrency
			} else if f {
				matrix[a * n + b] = .causality
			}
		}
	}
	return model.Footprint{ names: log.activities.clone(), index: ids, matrix: matrix, direct: direct }
}
