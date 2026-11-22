module alpha

const sample_csv = 'case,time,event,activity
t1,2024-01-01 08:00:00,e1,A
t1,2024-01-01 08:01:00,e2,B
t1,2024-01-01 08:02:00,e3,C
t2,2024-01-01 09:00:00,e4,A
t2,2024-01-01 09:01:00,e5,C
t2,2024-01-01 09:02:00,e6,B
'

fn must_log(data string, opts CsvOptions) EventLog {
	return parse_csv(data, opts) or {
		panic(err.msg())
	}
}

fn sample_log() EventLog {
	return must_log(sample_csv, CsvOptions{ delimiter: `,` })
}

fn test_eventlog() {
	log := sample_log()
	assert log.trace_count() == 2
	assert log.activity_count() == 3
	assert log.event_count() == 6
	t1 := log.trace('t1') or { panic('missing trace') }
	assert t1.event_list()[0].activity == 'A'
}

fn test_footprint() {
	fp := build_footprint(sample_log())
	assert fp.relation('A', 'B') == .causality
	assert fp.relation('B', 'A') == .conflict
	assert fp.relation('A', 'C') == .causality
	assert fp.relation('C', 'A') == .conflict
	assert fp.relation('B', 'C') == .concurrency
	assert fp.relation('C', 'B') == .concurrency
	assert fp.relation('A', 'B').str() == '->'
	assert fp.relation('B', 'C').str() == '||'
}

fn test_net() {
	log := sample_log()
	net := discover_net(log, build_footprint(log))
	assert net.start_activities == ['A']
	assert net.end_activities == ['B', 'C']
	assert net.places.len == 4
	assert net.arcs.len == 7

	mut found := 0
	for place in net.places {
		if place.inputs == ['A'] && place.outputs == ['B'] {
			found++
		}
		if place.inputs == ['A'] && place.outputs == ['C'] {
			found++
		}
		if place.inputs.len == 0 && place.outputs == ['A'] {
			found++
		}
		if place.inputs == ['B', 'C'] && place.outputs.len == 0 {
			found++
		}
	}
	assert found == 4
}

fn test_place_validity() {
	fp := build_footprint(sample_log())
	assert Place{ inputs: ['A'], outputs: ['B'] }.valid(fp)
	assert !Place{ inputs: ['A'], outputs: ['B', 'C'] }.valid(fp)
	assert !Place{ inputs: [], outputs: ['A'] }.valid(fp)
}

fn test_generated_places_match_footprint() {
	log := must_log('case,time,event,activity
t1,2024-01-01 08:00:00,e1,A
t1,2024-01-01 08:01:00,e2,C
t1,2024-01-01 08:02:00,e3,B
t2,2024-01-01 09:00:00,e4,A
t2,2024-01-01 09:01:00,e5,B
', CsvOptions{ delimiter: `,` })
	fp := build_footprint(log)
	net := discover_net(log, fp)
	for place in net.places {
		if place.inputs.len > 0 && place.outputs.len > 0 {
			assert place.valid(fp)
		}
		assert !(place.inputs == ['A', 'C'])
	}
}

fn test_timestamp_and_dedup() {
	iso := must_log('c,t,e,a
1,2024-01-02 03:04:05,x,A
1,2024-01-02 03:04:06,y,B
', CsvOptions{ delimiter: `,` })
	iso_trace := iso.trace('1') or { panic('missing trace') }
	assert iso_trace.event_list()[0].time.year == 2024
	assert iso_trace.event_list()[0].time.hour == 3

	dmy := must_log('c;t;e;a
1;02-01-2024 03:04:05;x;A
', CsvOptions{})
	dmy_trace := dmy.trace('1') or { panic('missing trace') }
	assert dmy_trace.event_list()[0].time.day == 2
	assert dmy_trace.event_list()[0].time.month == 1
}
