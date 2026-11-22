module alpha

import time

// Event is a single activity occurrence inside a case.
pub struct Event {
pub:
	id       string
	activity string
	time     time.Time
	sort_key i64
}

// same_activity reports whether two events refer to the same activity.
pub fn (a Event) same_activity(b Event) bool {
	return a.activity == b.activity
}

fn compare_events(a &Event, b &Event) int {
	if a.sort_key < b.sort_key {
		return -1
	}
	if a.sort_key > b.sort_key {
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
