// Module discovery implements the alpha family of process discovery
// algorithms. Places are grown from causal seeds instead of enumerating the
// powerset of activities, so large logs remain tractable.
module discovery

import flowkit.model

pub enum Method {
	alpha
	alpha_plus
}

struct Candidate {
	inputs  []int
	outputs []int
}

fn ids_key(ids []int) string {
	mut out := ''
	for id in ids {
		out += '${id},'
	}
	return out
}

fn key(c Candidate) string {
	return '${ids_key(c.inputs)}>${ids_key(c.outputs)}'
}

fn conflicts(x int, set []int, fp model.Footprint) bool {
	for a in set {
		if fp.relation_id(x, a) != .conflict || fp.relation_id(a, x) != .conflict {
			return false
		}
	}
	return true
}

fn causes(x int, set []int, fp model.Footprint) bool {
	for b in set {
		if fp.relation_id(x, b) != .causality {
			return false
		}
	}
	return true
}

fn caused_by(set []int, y int, fp model.Footprint) bool {
	for a in set {
		if fp.relation_id(a, y) != .causality {
			return false
		}
	}
	return true
}

fn names(ids []int, all []string) []string {
	mut out := []string{cap: ids.len}
	for id in ids {
		out << all[id]
	}
	return out
}

// discover builds a Petri net with the chosen alpha-family method.
pub fn discover(log model.EventLog, fp model.Footprint, method Method) model.PetriNet {
	n := log.activity_count()
	mut starts := []string{}
	mut ends := []string{}
	for _, trace in log.traces {
		events := trace.raw_events()
		if events.len == 0 {
			continue
		}
		start := events[0].activity
		end := events[events.len - 1].activity
		if start !in starts {
			starts << start
		}
		if end !in ends {
			ends << end
		}
	}
	starts.sort()
	ends.sort()

	mut net := model.PetriNet{}
	mut seen := map[string]bool{}
	mut queue := []Candidate{}

	for a := 0; a < n; a++ {
		for b := 0; b < n; b++ {
			if fp.relation_id(a, b) == .causality {
				seed := Candidate{ inputs: [a], outputs: [b] }
				k := key(seed)
				if k !in seen {
					seen[k] = true
					queue << seed
				}
			}
		}
	}

	mut i := 0
	for i < queue.len {
		state := queue[i]
		i++
		mut extended := false
		for x := 0; x < n; x++ {
			if x in state.inputs || !conflicts(x, state.inputs, fp) || !causes(x, state.outputs, fp) {
				continue
			}
			mut inputs := state.inputs.clone()
			inputs << x
			inputs.sort()
			next := Candidate{ inputs: inputs, outputs: state.outputs.clone() }
			k := key(next)
			if k !in seen {
				seen[k] = true
				queue << next
				extended = true
			}
		}
		for y := 0; y < n; y++ {
			if y in state.outputs || !conflicts(y, state.outputs, fp) || !caused_by(state.inputs, y, fp) {
				continue
			}
			mut outputs := state.outputs.clone()
			outputs << y
			outputs.sort()
			next := Candidate{ inputs: state.inputs.clone(), outputs: outputs }
			k := key(next)
			if k !in seen {
				seen[k] = true
				queue << next
				extended = true
			}
		}
		if !extended {
			place := model.Place{ inputs: names(state.inputs, log.activities), outputs: names(state.outputs, log.activities) }
			k := place.key()
			if k !in net.place_keys && place.valid(fp) {
				net.place_keys[k] = true
				net.places << place
			}
		}
	}

	if method == .alpha_plus {
		for a := 0; a < n; a++ {
			if fp.direct_id(a, a) == 0 {
				continue
			}
			place := model.Place{ inputs: [log.activities[a]], outputs: [log.activities[a]] }
			k := place.key()
			if k !in net.place_keys {
				net.place_keys[k] = true
				net.places << place
			}
		}
	}

	net.places << model.Place{ inputs: [], outputs: starts }
	net.places << model.Place{ inputs: ends, outputs: [] }
	net.start_activities = starts
	net.end_activities = ends

	for idx, place in net.places {
		for a in place.inputs {
			net.arcs << model.Arc{ transition: a, place: idx, is_input: true }
		}
		for b in place.outputs {
			net.arcs << model.Arc{ transition: b, place: idx, is_input: false }
		}
	}
	return net
}
