module io

import os
import flowkit.model

const sample = 'case,time,event,activity
t1,2024-01-01 08:00:00,e1,A
t1,2024-01-01 08:01:00,e2,B
t2,2024-01-01 09:00:00,e3,A
t2,2024-01-01 09:01:00,e4,B
'

fn test_parse_csv() {
	log := parse_csv(sample, model.ReadOptions{ delimiter: `,` })!
	assert log.trace_count() == 2
	assert log.activity_count() == 2
	assert log.event_count() == 4
	c1 := log.trace('t1') or { panic('missing case') }
	assert c1.event_list()[0].activity == 'A'
	assert c1.event_list()[1].time.hour == 8
}

fn test_parse_csv_bad_row() {
	bad := 'c;t;e;a\n1;not-a-time;e;A\n'
	log := parse_csv(bad, model.ReadOptions{}) or { return }
	assert log.trace_count() < 0
}

fn test_xes_roundtrip() {
	dir := os_tmp_dir()
	path := dir + '/flowkit_test.xes'
	log := parse_csv(sample, model.ReadOptions{ delimiter: `,` })!
	write_xes(path, log)!
	read_back := read_xes(path)!
	assert read_back.trace_count() == 2
	assert read_back.activity_count() == 2
	assert read_back.event_count() == 4
}

fn os_tmp_dir() string {
	return os.vtmp_dir()
}
