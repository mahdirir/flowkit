module main

import time

struct Event {
	id       string
	activity string
	time     time.Time
	key      i64
}

fn (a Event) is_same(b Event) bool {
	return a.id != '' && a.id == b.id
}

fn cmp_events_time(a &Event, b &Event) int {
	if a.key < b.key {
		return -1
	}
	if a.key > b.key {
		return 1
	}
	if a.id < b.id {
		return -1
	}
	if a.id > b.id {
		return 1
	}
	return 0
}
