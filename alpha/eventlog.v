module alpha

import os
import time
import encoding.csv

// Trace is one case: an ordered sequence of events.
pub struct Trace {
pub:
	id string
mut:
	events []Event
}

// events returns the events of the trace in chronological order.
pub fn (t Trace) event_list() []Event {
	return t.events.clone()
}

fn (mut t Trace) add_event(e Event) {
	if e.id != '' {
		for existing in t.events {
			if existing.id == e.id {
				return
			}
		}
	}
	t.events << e
}

fn (mut t Trace) sort_events() {
	t.events.sort_with_compare(compare_events)
}

// EventLog is a collection of traces plus the distinct activity names.
pub struct EventLog {
pub mut:
	traces     map[string]Trace
	activities []string
}

// trace returns the case with the given id, if present.
pub fn (e EventLog) trace(id string) ?Trace {
	return e.traces[id]
}

// trace_count returns the number of cases in the log.
pub fn (e EventLog) trace_count() int {
	return e.traces.len
}

// activity_count returns the number of distinct activities in the log.
pub fn (e EventLog) activity_count() int {
	return e.activities.len
}

// event_count returns the total number of events in the log.
pub fn (e EventLog) event_count() int {
	mut total := 0
	for _, trace in e.traces {
		total += trace.events.len
	}
	return total
}

fn timestamp_key(year int, month int, day int, hour int, minute int, second int) i64 {
	return ((((i64(year) * 13 + i64(month)) * 32 + i64(day)) * 24 + i64(hour)) * 60 + i64(minute)) * 60 + i64(second)
}

fn parse_timestamp(s string) !time.Time {
	if s.len < 19 {
		return error('unsupported timestamp "${s}"')
	}
	if s[4] == `-` && s[7] == `-` && s[10] == ` ` {
		return checked_time(s[0..4].int(), s[5..7].int(), s[8..10].int(), s[11..13].int(), s[14..16].int(), s[17..19].int())
	}
	if (s[2] == `-` || s[2] == `/`) && (s[5] == `-` || s[5] == `/`) && s[10] == ` ` {
		return checked_time(s[6..10].int(), s[3..5].int(), s[0..2].int(), s[11..13].int(), s[14..16].int(), s[17..19].int())
	}
	return error('unsupported timestamp "${s}" (expected YYYY-MM-DD or DD-MM-YYYY)')
}

fn checked_time(y int, m int, d int, h int, mi int, se int) !time.Time {
	if y < 1 || y > 9999 || m < 1 || m > 12 || d < 1 || d > 31 || h < 0 || h > 23 || mi < 0 || mi > 59 || se < 0 || se > 59 {
		return error('timestamp out of range: ${y}-${m}-${d} ${h}:${mi}:${se}')
	}
	return time.Time{ year: y, month: m, day: d, hour: h, minute: mi, second: se }
}

// read_eventlog_csv reads a delimited activity log from a file.
// Each row is one event; columns are selected by CsvOptions.
pub fn read_eventlog_csv(path string, opts CsvOptions) !EventLog {
	content := os.read_file(path) or {
		return error('cannot read ${path}: ${err.msg()}')
	}
	return parse_csv(content, opts)
}

// parse_csv reads a delimited activity log from a string.
pub fn parse_csv(content string, opts CsvOptions) !EventLog {
	mut reader := csv.new_reader(content, delimiter: opts.delimiter)

	mut last := opts.case_col
	if opts.time_col > last {
		last = opts.time_col
	}
	if opts.event_col > last {
		last = opts.event_col
	}
	if opts.activity_col > last {
		last = opts.activity_col
	}

	mut log := EventLog{}
	mut row := 0
	for {
		cols := reader.read() or {
			break
		}
		if cols.len == 0 {
			continue
		}
		row++
		if row == 1 && opts.header {
			continue
		}
		if cols.len <= last {
			return error('row ${row}: expected at least ${last + 1} columns, got ${cols.len}')
		}

		case_id := cols[opts.case_col].trim_space()
		activity := cols[opts.activity_col].trim_space()
		if case_id == '' || activity == '' {
			return error('row ${row}: empty case id or activity')
		}
		ts := parse_timestamp(cols[opts.time_col].trim_space()) or {
			return error('row ${row}: ${err.msg()}')
		}

		mut trace := log.traces[case_id] or {
			Trace{ id: case_id }
		}
		trace.add_event(Event{
			id:       cols[opts.event_col].trim_space()
			activity: activity
			time:     ts
			sort_key: timestamp_key(ts.year, ts.month, ts.day, ts.hour, ts.minute, ts.second)
		})
		log.traces[case_id] = trace
		if activity !in log.activities {
			log.activities << activity
		}
	}

	if log.traces.len == 0 {
		return error('no events found in log')
	}
	for _, mut trace in log.traces {
		trace.sort_events()
	}
	return log
}
