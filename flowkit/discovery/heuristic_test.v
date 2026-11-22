module discovery

import flowkit.model
import flowkit.io
import flowkit.analysis

fn sample() model.EventLog {
	return io.parse_csv('case,time,event,activity
t1,2024-01-01 08:00:00,e1,A
t1,2024-01-01 08:01:00,e2,B
t1,2024-01-01 08:02:00,e3,C
t2,2024-01-01 09:00:00,e4,A
t2,2024-01-01 09:01:00,e5,C
t2,2024-01-01 09:02:00,e6,B
', model.ReadOptions{ delimiter: `,` }) or { panic(err.msg()) }
}

fn test_heuristic_net() {
	log := sample()
	fp := analysis.build_footprint(log)
	net := discover_heuristic(log, fp, 0.4)
	assert net.start_activities == ['A']
	assert net.end_activities == ['B', 'C']
	assert net.places.len > 0
	assert net.arcs.len > 0
	mut found := false
	for place in net.places {
		if place.inputs == ['A'] && (place.outputs == ['B'] || place.outputs == ['C']) {
			found = true
		}
	}
	assert found
}

fn test_threshold_filters_weak_edges() {
	log := sample()
	fp := analysis.build_footprint(log)
	loose := discover_heuristic(log, fp, 0.1)
	strict := discover_heuristic(log, fp, 0.9)
	assert loose.places.len >= strict.places.len
}
