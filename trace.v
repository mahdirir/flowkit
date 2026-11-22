module main

struct Trace {
	id string
mut:
	events []Event
}

fn (mut t Trace) sort_events() {
	t.events.sort_with_compare(cmp_events_time)
}

fn (mut t Trace) add_event(e Event) {
	if e.id != '' {
		for event in t.events {
			if event.id == e.id {
				return
			}
		}
	}
	t.events << e
}
