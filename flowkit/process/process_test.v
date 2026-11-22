module process

import flowkit.model
import flowkit.io

fn sample() model.EventLog {
	return io.parse_csv('case,time,event,activity
t1,2024-01-01 08:00:00,e1,A
t1,2024-01-01 08:01:00,e2,B
t2,2024-01-01 09:00:00,e3,A
t2,2024-01-01 09:01:00,e4,C
', model.ReadOptions{ delimiter: `,` }) or { panic(err.msg()) }
}

fn test_tree_from_log() {
	tree := from_log(sample())
	assert tree.op == .sequence
	mut has_choice := false
	for child in tree.children {
		if child.op == .choice {
			has_choice = true
		}
	}
	assert has_choice
}

fn test_tree_to_petri() {
	net := to_petri(from_log(sample()))
	assert net.start_activities == ['A']
	assert net.places.len > 0
	assert net.arcs.len > 0
}

fn test_bpmn_output() {
	xml := render_bpmn(from_log(sample()))
	assert xml.contains('<definitions')
	assert xml.contains('<startEvent')
	assert xml.contains('<endEvent')
	assert xml.contains('<task')
	assert xml.contains('gateway')
}
