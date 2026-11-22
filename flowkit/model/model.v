// Module model holds the data types shared by every flowkit package.
// It has no dependencies on other flowkit modules, so importing it is cheap.
module model

import time

pub enum Relation {
	conflict    // # : neither activity directly follows the other
	causality   // -> : a directly follows b, but b never follows a
	concurrency // || : a and b directly follow each other
}

pub fn (r Relation) str() string {
	return match r {
		.conflict { '#' }
		.causality { '->' }
		.concurrency { '||' }
	}
}

pub struct Event {
pub:
	id       string
	case_id  string
	activity string
	time     time.Time
	sort_key i64
}

pub fn (e Event) same_activity(other Event) bool {
	return e.activity == other.activity
}

pub struct Trace {
pub:
	id string
mut:
	events []Event
}

pub fn (t Trace) event_list() []Event {
	return t.events.clone()
}

pub fn (t Trace) raw_events() []Event {
	return t.events
}

pub fn (mut t Trace) add_event(e Event) {
	if e.id != '' {
		for existing in t.events {
			if existing.id == e.id {
				return
			}
		}
	}
	t.events << e
}

pub fn (mut t Trace) sort_events() {
	t.events.sort_with_compare(cmp_events)
}

fn cmp_events(a &Event, b &Event) int {
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

pub struct ReadOptions {
pub:
	delimiter    u8 = `;`
	case_col     int
	time_col     int  = 1
	event_col    int  = 2
	activity_col int  = 3
	header       bool = true
}

pub struct EventLog {
pub mut:
	traces     map[string]Trace
	activities []string
mut:
	index map[string]int
}

pub fn (e EventLog) trace(id string) ?Trace {
	return e.traces[id]
}

pub fn (e EventLog) trace_count() int {
	return e.traces.len
}

pub fn (e EventLog) activity_count() int {
	return e.activities.len
}

pub fn (e EventLog) event_count() int {
	mut total := 0
	for _, trace in e.traces {
		total += trace.events.len
	}
	return total
}

pub fn (e EventLog) activity_names() []string {
	return e.activities.clone()
}

pub fn (mut e EventLog) add_event(ev Event) {
	mut trace := e.traces[ev.case_id] or { Trace{ id: ev.case_id } }
	trace.add_event(ev)
	e.traces[ev.case_id] = trace
	if e.index[ev.activity] == 0 {
		e.activities << ev.activity
		e.index[ev.activity] = e.activities.len
	}
}

pub fn (mut e EventLog) add_event_unchecked(ev Event) {
	mut trace := e.traces[ev.case_id] or { Trace{ id: ev.case_id } }
	trace.events << ev
	e.traces[ev.case_id] = trace
	if e.index[ev.activity] == 0 {
		e.activities << ev.activity
		e.index[ev.activity] = e.activities.len
	}
}

pub fn (mut e EventLog) finish() {
	for _, mut trace in e.traces {
		trace.sort_events()
	}
}

pub fn (e EventLog) activity_id(name string) int {
	position := e.index[name]
	return if position == 0 { -1 } else { position - 1 }
}

pub fn timestamp_key(year int, month int, day int, hour int, minute int, second int) i64 {
	return ((((i64(year) * 13 + i64(month)) * 32 + i64(day)) * 24 + i64(hour)) * 60 + i64(minute)) * 60 + i64(second)
}

// Footprint stores relations in a flat n*n matrix addressed by interned
// activity ids. This keeps lookups O(1) and allocation-free in hot loops.
pub struct Footprint {
pub mut:
	names  []string
	index  map[string]int
	matrix []Relation
	direct []u32
}

pub fn (f Footprint) relation(a string, b string) Relation {
	i := f.index[a] or { return .conflict }
	j := f.index[b] or { return .conflict }
	return f.matrix[i * f.names.len + j]
}

pub fn (f Footprint) relation_id(a int, b int) Relation {
	if a < 0 || b < 0 || a >= f.names.len || b >= f.names.len {
		return .conflict
	}
	return f.matrix[a * f.names.len + b]
}

pub fn (f Footprint) direct_id(a int, b int) u32 {
	if a < 0 || b < 0 || a >= f.names.len || b >= f.names.len {
		return 0
	}
	return f.direct[a * f.names.len + b]
}

pub fn (f Footprint) activity_names() []string {
	return f.names.clone()
}

pub struct Place {
pub:
	inputs  []string
	outputs []string
}

pub fn (p Place) key() string {
	return '${p.inputs.join('|')}=>${p.outputs.join('|')}'
}

pub fn (p Place) valid(f Footprint) bool {
	if p.inputs.len == 0 || p.outputs.len == 0 {
		return false
	}
	for a in p.inputs {
		for b in p.inputs {
			if a != b && f.relation(a, b) != .conflict {
				return false
			}
		}
	}
	for a in p.outputs {
		for b in p.outputs {
			if a != b && f.relation(a, b) != .conflict {
				return false
			}
		}
	}
	for a in p.inputs {
		for b in p.outputs {
			if f.relation(a, b) != .causality {
				return false
			}
		}
	}
	return true
}

pub struct Arc {
pub:
	transition string
	place      int
	is_input   bool
}

pub struct PetriNet {
pub mut:
	start_activities []string
	end_activities   []string
	places           []Place
	arcs             []Arc
	place_keys       map[string]bool
}

pub fn (p PetriNet) place_count() int {
	return p.places.len
}

pub fn (p PetriNet) arc_count() int {
	return p.arcs.len
}

pub struct DfgEdge {
pub:
	from  string
	to    string
	count u32
}

pub struct Dfg {
pub:
	activities []string
	edges      []DfgEdge
}

pub struct Stats {
pub:
	traces        int
	activities    int
	events        int
	variants      int
	min_key       i64
	max_key       i64
	activity_freq map[string]int
	variant_freq  map[string]int
	rework        map[string]int
}

pub fn (s Stats) duration_seconds() f64 {
	return f64(s.max_key - s.min_key)
}

pub fn (s Stats) top_activities(limit int) []string {
	mut remaining := []string{}
	for name, _ in s.activity_freq {
		remaining << name
	}
	mut sorted := []string{}
	for remaining.len > 0 {
		mut best := 0
		for i := 1; i < remaining.len; i++ {
			if s.activity_freq[remaining[i]] > s.activity_freq[remaining[best]] {
				best = i
			}
		}
		sorted << remaining[best]
		mut next := []string{}
		for i, name in remaining {
			if i != best {
				next << name
			}
		}
		remaining = next.clone()
	}
	if limit > 0 && limit < sorted.len {
		return sorted[..limit]
	}
	return sorted
}
