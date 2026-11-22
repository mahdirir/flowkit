module model

fn test_relation_names() {
	assert Relation.causality.str() == '->'
	assert Relation.concurrency.str() == '||'
	assert Relation.conflict.str() == '#'
}

fn test_timestamp_key_ordering() {
	assert timestamp_key(2024, 1, 1, 8, 0, 0) < timestamp_key(2024, 1, 1, 8, 0, 1)
	assert timestamp_key(2024, 1, 1, 8, 0, 0) < timestamp_key(2024, 1, 2, 0, 0, 0)
}

fn test_trace_sort_and_dedup() {
	mut t := Trace{ id: 't' }
	t.add_event(Event{ id: 'e2', activity: 'B', sort_key: 2 })
	t.add_event(Event{ id: 'e1', activity: 'A', sort_key: 1 })
	t.add_event(Event{ id: 'e1', activity: 'A', sort_key: 1 })
	assert t.event_list().len == 2
	t.sort_events()
	events := t.event_list()
	assert events[0].activity == 'A'
	assert events[1].activity == 'B'
}

fn test_eventlog_helpers() {
	mut log := EventLog{}
	log.add_event(Event{ case_id: 'c1', activity: 'A', sort_key: 1 })
	log.add_event(Event{ case_id: 'c1', activity: 'B', sort_key: 2 })
	log.add_event(Event{ case_id: 'c2', activity: 'A', sort_key: 3 })
	assert log.trace_count() == 2
	assert log.activity_count() == 2
	assert log.event_count() == 3
	assert log.activity_id('A') == 0
	c1 := log.trace('c1') or { panic('missing case') }
	assert c1.event_list().len == 2
}
