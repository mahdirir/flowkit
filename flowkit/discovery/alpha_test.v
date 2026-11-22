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

fn test_alpha_net() {
	log := sample()
	fp := analysis.build_footprint(log)
	net := discover(log, fp, .alpha)
	assert net.start_activities == ['A']
	assert net.end_activities == ['B', 'C']
	assert net.places.len == 4
	assert net.arcs.len == 7
	for place in net.places {
		if place.inputs.len > 0 && place.outputs.len > 0 {
			assert place.valid(fp)
		}
	}
}

fn test_alpha_plus_short_loop() {
	log := io.parse_csv('c,t,e,a
1,2024-01-01 08:00:00,1,A
1,2024-01-01 08:01:00,2,A
1,2024-01-01 08:02:00,3,B
', model.ReadOptions{ delimiter: `,` }) or { panic(err.msg()) }
	fp := analysis.build_footprint(log)
	classic := discover(log, fp, .alpha)
	plus := discover(log, fp, .alpha_plus)
	assert plus.places.len > classic.places.len
	mut found := false
	for place in plus.places {
		if place.inputs == ['A'] && place.outputs == ['A'] {
			found = true
		}
	}
	assert found
}
