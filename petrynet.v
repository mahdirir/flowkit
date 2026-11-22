module main

struct Arc {
	transition string
	place      int
	is_input   bool // true: transition -> place, false: place -> transition
}

struct PetriNet {
mut:
	start_activities []string
	end_activities   []string
	places           []Place
	arcs             []Arc
}

struct PairState {
	inputs  []string
	outputs []string
}

fn pair_key(s PairState) string {
	return '${s.inputs.join('|')}=>${s.outputs.join('|')}'
}

fn all_conflict(x string, set []string, f Footprint) bool {
	for a in set {
		if f.of(x, a) != .conflict || f.of(a, x) != .conflict {
			return false
		}
	}
	return true
}

fn all_causal_from(x string, set []string, f Footprint) bool {
	for b in set {
		if f.of(x, b) != .causality {
			return false
		}
	}
	return true
}

fn all_causal_to(set []string, y string, f Footprint) bool {
	for a in set {
		if f.of(a, y) != .causality {
			return false
		}
	}
	return true
}

fn build_petrynet(e Eventlog, f Footprint) PetriNet {
	mut net := PetriNet{}

	for _, t in e.traces {
		if t.events.len == 0 {
			continue
		}
		start := t.events[0].activity
		end := t.events[t.events.len - 1].activity
		if start !in net.start_activities {
			net.start_activities << start
		}
		if end !in net.end_activities {
			net.end_activities << end
		}
	}
	net.start_activities.sort()
	net.end_activities.sort()

	// Every valid place contains at least one causal pair (a, b). Grow each
	// seed into all maximal (inputs, outputs) pairs instead of enumerating
	// the full powerset of activities, which is infeasible for real logs.
	mut seen := map[string]bool{}
	mut queue := []PairState{}
	mut place_keys := map[string]bool{}

	for a in e.activities {
		for b in e.activities {
			if f.of(a, b) != .causality {
				continue
			}
			seed := PairState{ inputs: [a], outputs: [b] }
			k := pair_key(seed)
			if k !in seen {
				seen[k] = true
				queue << seed
			}
		}
	}

	mut qi := 0
	for qi < queue.len {
		state := queue[qi]
		qi++
		mut extended := false

		for x in e.activities {
			if x in state.inputs || !all_conflict(x, state.inputs, f) || !all_causal_from(x, state.outputs, f) {
				continue
			}
			mut inputs := state.inputs.clone()
			inputs << x
			inputs.sort()
			next := PairState{ inputs: inputs, outputs: state.outputs.clone() }
			k := pair_key(next)
			if k !in seen {
				seen[k] = true
				queue << next
				extended = true
			}
		}

		for y in e.activities {
			if y in state.outputs || !all_conflict(y, state.outputs, f) || !all_causal_to(state.inputs, y, f) {
				continue
			}
			mut outputs := state.outputs.clone()
			outputs << y
			outputs.sort()
			next := PairState{ inputs: state.inputs.clone(), outputs: outputs }
			k := pair_key(next)
			if k !in seen {
				seen[k] = true
				queue << next
				extended = true
			}
		}

		if !extended {
			place := Place{ inputs: state.inputs, outputs: state.outputs }
			k := place.key()
			if k !in place_keys && place.is_valid(f) {
				place_keys[k] = true
				net.places << place
			}
		}
	}

	net.places << Place{ inputs: [], outputs: net.start_activities }
	net.places << Place{ inputs: net.end_activities, outputs: [] }

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
