module streaming

import flowkit.model

fn test_push() {
	mut stats := new()
	stats.push('c1', 'A')
	stats.push('c1', 'B')
	stats.push('c2', 'A')
	stats.push('c2', 'B')
	assert stats.events == 4
	assert stats.case_count() == 2
	assert stats.activity_count() == 2
	assert stats.edges[model.pair_key('A', 'B')] == 2
	assert stats.top_activities(1)[0] == 'A' || stats.top_activities(1)[0] == 'B'
}

fn test_dfg() {
	mut stats := new()
	stats.push('c1', 'A')
	stats.push('c1', 'B')
	dfg := stats.dfg(1)
	assert dfg.edges.len == 1
	assert dfg.edges[0].from == 'A'
	assert dfg.edges[0].to == 'B'
}

fn test_follow_csv() {
	stats := follow_csv('examples/simple.csv', model.ReadOptions{ delimiter: `,` })!
	assert stats.events == 6
	assert stats.case_count() == 2
	assert stats.activity_count() == 3
}
