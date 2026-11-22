module conformance

import flowkit.model
import flowkit.io
import flowkit.analysis
import flowkit.discovery

fn sample() model.EventLog {
	return io.parse_csv('case,time,event,activity
t1,2024-01-01 08:00:00,e1,A
t1,2024-01-01 08:01:00,e2,B
t2,2024-01-01 09:00:00,e3,A
t2,2024-01-01 09:01:00,e4,B
', model.ReadOptions{ delimiter: `,` }) or { panic(err.msg()) }
}

fn test_replay_perfect_fit() {
	log := sample()
	net := discovery.discover(log, analysis.build_footprint(log), .alpha)
	result := replay(log, net)
	assert result.fitness > 0.99
	assert result.missing_tokens == 0
	assert result.remaining_tokens == 0
	assert result.traces.len == 2
}

fn test_replay_detects_deviation() {
	log := io.parse_csv('c,t,e,a
1,2024-01-01 08:00:00,1,A
1,2024-01-01 08:01:00,2,C
1,2024-01-01 08:02:00,3,B
', model.ReadOptions{ delimiter: `,` }) or { panic(err.msg()) }
	base := sample()
	net := discovery.discover(base, analysis.build_footprint(base), .alpha)
	result := replay(log, net)
	assert result.fitness < 1.0
	assert result.missing_tokens > 0 || result.remaining_tokens > 0
}

fn test_bounded_alignment() {
	log := sample()
	net := discovery.discover(log, analysis.build_footprint(log), .alpha)
	alignments := align(log, net, 200, 6)
	assert alignments.len == 2
	for a in alignments {
		assert a.fitness > 0.0 && a.fitness <= 1.0
		assert a.steps.len > 0
	}
}
