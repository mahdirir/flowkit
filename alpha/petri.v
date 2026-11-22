module alpha

// Place is a Petri net place described by its input and output transitions.
pub struct Place {
pub:
	inputs  []string
	outputs []string
}

fn (p Place) key() string {
	return '${p.inputs.join('|')}=>${p.outputs.join('|')}'
}

// valid reports whether the place agrees with the footprint.
pub fn (p Place) valid(fp Footprint) bool {
	if p.inputs.len == 0 || p.outputs.len == 0 {
		return false
	}
	for a in p.inputs {
		for b in p.inputs {
			if a != b && fp.relation(a, b) != .conflict {
				return false
			}
		}
	}
	for a in p.outputs {
		for b in p.outputs {
			if a != b && fp.relation(a, b) != .conflict {
				return false
			}
		}
	}
	for a in p.inputs {
		for b in p.outputs {
			if fp.relation(a, b) != .causality {
				return false
			}
		}
	}
	return true
}

// Arc connects a transition to a place, or a place to a transition.
pub struct Arc {
pub:
	transition string
	place      int
	is_input   bool // true: transition -> place, false: place -> transition
}

// PetriNet is the model discovered from an event log.
pub struct PetriNet {
pub mut:
	start_activities []string
	end_activities   []string
	places           []Place
	arcs             []Arc
mut:
	place_keys map[string]bool
}

struct Candidate {
	inputs  []string
	outputs []string
}

fn key(c Candidate) string {
	return '${c.inputs.join('|')}=>${c.outputs.join('|')}'
}

fn conflicts(x string, set []string, fp Footprint) bool {
	for a in set {
		if fp.relation(x, a) != .conflict || fp.relation(a, x) != .conflict {
			return false
		}
	}
	return true
}

fn causes(x string, set []string, fp Footprint) bool {
	for b in set {
		if fp.relation(x, b) != .causality {
			return false
		}
	}
	return true
}

fn caused_by(set []string, y string, fp Footprint) bool {
	for a in set {
		if fp.relation(a, y) != .causality {
			return false
		}
	}
	return true
}

// discover_net constructs a Petri net from an event log and its footprint.
//
// Every causal pair is grown into all maximal (inputs, outputs) pairs. This is
// equivalent to the alpha algorithm's powerset search without materialising
// 2^n subsets, which is infeasible for real logs.
pub fn discover_net(log EventLog, fp Footprint) PetriNet {
	mut starts := []string{}
	mut ends := []string{}
	for _, trace in log.traces {
		events := trace.event_list()
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

	mut seen := map[string]bool{}
	mut queue := []Candidate{}
	mut net := PetriNet{}

	for a in log.activities {
		for b in log.activities {
			if fp.relation(a, b) != .causality {
				continue
			}
			seed := Candidate{ inputs: [a], outputs: [b] }
			k := key(seed)
			if k !in seen {
				seen[k] = true
				queue << seed
			}
		}
	}

	mut i := 0
	for i < queue.len {
		state := queue[i]
		i++
		mut extended := false

		for x in log.activities {
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

		for y in log.activities {
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
			place := Place{ inputs: state.inputs, outputs: state.outputs }
			k := place.key()
			if k !in net.place_keys && place.valid(fp) {
				net.place_keys[k] = true
				net.places << place
			}
		}
	}

	net.places << Place{ inputs: [], outputs: starts }
	net.places << Place{ inputs: ends, outputs: [] }
	net.start_activities = starts
	net.end_activities = ends

	for idx, place in net.places {
		for a in place.inputs {
			net.arcs << Arc{ transition: a, place: idx, is_input: true }
		}
		for b in place.outputs {
			net.arcs << Arc{ transition: b, place: idx, is_input: false }
		}
	}
	return net
}
