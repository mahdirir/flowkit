module main

import os
import time
import encoding.csv

struct Eventlog {
mut:
	traces     map[string]Trace
	activities []string
}

fn (mut e Eventlog) get_case(id string) Trace {
	return e.traces[id] or {
		Trace{ id: id }
	}
}

fn (mut e Eventlog) update_case(id string, t Trace) {
	e.traces[id] = t
}

fn time_key(year int, month int, day int, hour int, minute int, second int) i64 {
	return ((((i64(year) * 13 + i64(month)) * 32 + i64(day)) * 24 + i64(hour)) * 60 + i64(minute)) * 60 + i64(second)
}

fn parse_timestamp(s string) !time.Time {
	if s.len < 19 {
		return error('unsupported timestamp "${s}"')
	}
	if s[4] == `-` && s[7] == `-` && s[10] == ` ` {
		y := s[0..4].int()
		m := s[5..7].int()
		d := s[8..10].int()
		h := s[11..13].int()
		mi := s[14..16].int()
		se := s[17..19].int()
		return checked_time(y, m, d, h, mi, se)
	}
	if (s[2] == `-` || s[2] == `/`) && (s[5] == `-` || s[5] == `/`) && s[10] == ` ` {
		d := s[0..2].int()
		m := s[3..5].int()
		y := s[6..10].int()
		h := s[11..13].int()
		mi := s[14..16].int()
		se := s[17..19].int()
		return checked_time(y, m, d, h, mi, se)
	}
	return error('unsupported timestamp "${s}" (expected YYYY-MM-DD or DD-MM-YYYY)')
}

fn checked_time(y int, m int, d int, h int, mi int, se int) !time.Time {
	if y < 1 || y > 9999 || m < 1 || m > 12 || d < 1 || d > 31 || h < 0 || h > 23 || mi < 0 || mi > 59 || se < 0 || se > 59 {
		return error('timestamp out of range: ${y}-${m}-${d} ${h}:${mi}:${se}')
	}
	return time.Time{
		year: y
		month: m
		day: d
		hour: h
		minute: mi
		second: se
	}
}

fn build_eventlog(path string, cfg Config) !Eventlog {
	content := os.read_file(path) or {
		return error('cannot read input file ${path}: ${err.msg()}')
	}
	mut reader := csv.new_reader(content, delimiter: cfg.delimiter)

	mut max_col := cfg.case_col
	if cfg.time_col > max_col {
		max_col = cfg.time_col
	}
	if cfg.event_col > max_col {
		max_col = cfg.event_col
	}
	if cfg.activity_col > max_col {
		max_col = cfg.activity_col
	}

	mut e := Eventlog{}
	mut row := 0
	for {
		cols := reader.read() or {
			break
		}
		if cols.len == 0 {
			continue
		}
		row++
		if row == 1 && !cfg.no_header {
			continue
		}
		if cols.len <= max_col {
			return error('row ${row}: expected at least ${max_col + 1} columns, got ${cols.len}')
		}
		cid := cols[cfg.case_col].trim_space()
		act := cols[cfg.activity_col].trim_space()
		if cid == '' || act == '' {
			return error('row ${row}: empty case id or activity')
		}
		raw_time := cols[cfg.time_col].trim_space()
		ts := parse_timestamp(raw_time) or {
			return error('row ${row}: ${err.msg()}')
		}

		mut trace := e.get_case(cid)
		ev := Event{
			id: cols[cfg.event_col].trim_space()
			activity: act
			time: ts
			key: time_key(ts.year, ts.month, ts.day, ts.hour, ts.minute, ts.second)
		}
		trace.add_event(ev)
		e.update_case(cid, trace)
		if act !in e.activities {
			e.activities << act
		}
	}
	if e.traces.len == 0 {
		return error('no events found in ${path}')
	}
	for _, mut t in e.traces {
		t.sort_events()
	}
	return e
}
