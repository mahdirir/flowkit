module main

import time

fn event_at(activity string, h int) Event {
	return Event{
		id: '${activity}${h}'
		activity: activity
		time: time.Time{ year: 2024, month: 1, day: 1, hour: h }
		key: h
	}
}

fn abc_log() Eventlog {
	return Eventlog{
		activities: ['A', 'B', 'C']
		traces: {
			't1': Trace{ id: 't1', events: [event_at('A', 1), event_at('B', 2), event_at('C', 3)] }
			't2': Trace{ id: 't2', events: [event_at('A', 4), event_at('C', 5), event_at('B', 6)] }
		}
	}
}

fn test_footprint_relations() {
	f := build_footprint(abc_log())
	assert f.of('A', 'B') == .causality
	assert f.of('B', 'A') == .conflict
	assert f.of('A', 'C') == .causality
	assert f.of('C', 'A') == .conflict
	assert f.of('B', 'C') == .concurrency
	assert f.of('C', 'B') == .concurrency
	assert relation_str(f.of('A', 'B')) == '->'
	assert relation_str(f.of('B', 'C')) == '||'
}

fn test_place_validity() {
	f := build_footprint(abc_log())
	assert Place{ inputs: ['A'], outputs: ['B'] }.is_valid(f)
	assert !Place{ inputs: ['A'], outputs: ['B', 'C'] }.is_valid(f)
	assert !Place{ inputs: [], outputs: ['A'] }.is_valid(f)
}

fn test_petri_net() {
	e := abc_log()
	f := build_footprint(e)
	net := build_petrynet(e, f)

	assert net.start_activities.len == 1 && net.start_activities[0] == 'A'
	assert set_is_equal(net.end_activities, ['B', 'C'])
	assert net.places.len == 4
	assert net.arcs.len == 7

	mut has_ab := false
	mut has_ac := false
	mut has_input := false
	mut has_output := false
	for p in net.places {
		if set_is_equal(p.inputs, ['A']) && set_is_equal(p.outputs, ['B']) {
			has_ab = true
		}
		if set_is_equal(p.inputs, ['A']) && set_is_equal(p.outputs, ['C']) {
			has_ac = true
		}
		if p.inputs.len == 0 && set_is_equal(p.outputs, ['A']) {
			has_input = true
		}
		if p.outputs.len == 0 && set_is_equal(p.inputs, ['B', 'C']) {
			has_output = true
		}
	}
	assert has_ab && has_ac && has_input && has_output
}

fn test_generated_places_are_valid() {
	// A -> C and C -> B; C is not in conflict with A, so {A,C} must never
	// become the input set of a place.
	mut e := Eventlog{}
	e.activities = ['A', 'B', 'C']
	e.traces = {
		't1': Trace{ id: 't1', events: [event_at('A', 1), event_at('C', 2), event_at('B', 3)] }
		't2': Trace{ id: 't2', events: [event_at('A', 4), event_at('B', 5)] }
	}
	f := build_footprint(e)
	net := build_petrynet(e, f)
	for p in net.places {
		if p.inputs.len > 0 && p.outputs.len > 0 {
			assert p.is_valid(f)
		}
		assert !set_is_equal(p.inputs, ['A', 'C'])
	}
}

fn test_trace_sort_and_dedup() {
	mut t := Trace{ id: 't' }
	t.add_event(event_at('B', 2))
	t.add_event(event_at('A', 1))
	t.add_event(event_at('A', 1))
	assert t.events.len == 2
	t.sort_events()
	assert t.events[0].activity == 'A'
	assert t.events[1].activity == 'B'
}
