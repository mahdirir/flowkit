module analysis

import flowkit.model
import flowkit.io

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

fn test_footprint() {
	fp := build_footprint(sample())
	assert fp.relation('A', 'B') == .causality
	assert fp.relation('B', 'A') == .conflict
	assert fp.relation('B', 'C') == .concurrency
	assert fp.relation('C', 'B') == .concurrency
}

fn test_stats() {
	s := compute_stats(sample())
	assert s.traces == 2
	assert s.events == 6
	assert s.variants == 2
	assert s.activity_freq['A'] == 2
	assert s.top_activities(1)[0] == 'A'
}

fn test_dfg() {
	dfg := build_dfg(sample(), 1)
	assert dfg.edges.len > 0
	for edge in dfg.edges {
		assert edge.count >= 1
	}
}

fn test_filter() {
	log := filter(sample(), Filter{ keep_activities: ['A', 'B'] })
	assert log.activity_count() == 2
	assert log.event_count() == 4
}
