// A frequency-based heuristic miner. It extends the footprint with a
// dependency measure and collapses concurrent successors/predecessors into
// AND-splits and AND-joins, producing smaller models than alpha on noisy logs.
module discovery

import flowkit.model

fn dependency(direct u32, reverse u32) f64 {
	if direct == 0 {
		return 0.0
	}
	return f64(direct) / f64(direct + reverse + 1)
}

fn concurrent(fp model.Footprint, a int, b int) bool {
	return fp.relation_id(a, b) == .concurrency && fp.relation_id(b, a) == .concurrency
}

fn group_concurrent(ids []int, fp model.Footprint) [][]int {
	mut groups := [][]int{}
	mut used := []bool{len: ids.len, init: false}
	for i := 0; i < ids.len; i++ {
		if used[i] {
			continue
		}
		mut group := [ids[i]]
		used[i] = true
		for j := i + 1; j < ids.len; j++ {
			if used[j] {
				continue
			}
			mut fits := true
			for member in group {
				if !concurrent(fp, member, ids[j]) {
					fits = false
					break
				}
			}
			if fits {
				group << ids[j]
				used[j] = true
			}
		}
		groups << group
	}
	return groups
}

fn to_names(ids []int, all []string) []string {
	mut out := []string{cap: ids.len}
	for id in ids {
		out << all[id]
	}
	return out
}

// discover_heuristic discovers a Petri net using a dependency threshold.
// A threshold around 0.5 works well for moderately noisy logs.
pub fn discover_heuristic(log model.EventLog, fp model.Footprint, threshold f64) model.PetriNet {
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
	add_place := fn (mut target model.PetriNet, inputs []string, outputs []string) {
		p := model.Place{ inputs: inputs, outputs: outputs }
		k := p.key()
		if k !in target.place_keys {
			target.place_keys[k] = true
			target.places << p
		}
	}

	for a := 0; a < n; a++ {
		mut successors := []int{}
		mut predecessors := []int{}
		for b := 0; b < n; b++ {
			if a == b {
				continue
			}
			forward := f64(fp.direct_id(a, b))
			backward := f64(fp.direct_id(b, a))
			if dependency(fp.direct_id(a, b), fp.direct_id(b, a)) >= threshold && forward > 0 {
				successors << b
			}
			if dependency(fp.direct_id(b, a), fp.direct_id(a, b)) >= threshold && backward > 0 {
				predecessors << b
			}
		}
		for group in group_concurrent(successors, fp) {
			add_place(mut net, [log.activities[a]], to_names(group, log.activities))
		}
		for group in group_concurrent(predecessors, fp) {
			add_place(mut net, to_names(group, log.activities), [log.activities[a]])
		}
	}

	add_place(mut net, [], starts)
	add_place(mut net, ends, [])
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
