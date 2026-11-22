// Module io reads and writes activity logs. Readers return the shared model
// types; CSV is parsed row by row so large logs never live in one string.
module io

import os
import time
import encoding.csv
import flowkit.model

pub fn parse_timestamp(raw string) !time.Time {
	s := raw.trim_space()
	if s.len < 19 {
		return error('unsupported timestamp "${s}"')
	}
	sep := if s[10] == `T` || s[10] == ` ` { s[10] } else { 0 }
	if sep == 0 {
		return error('unsupported timestamp "${s}"')
	}
	mut y := 0
	mut m := 0
	mut d := 0
	if s[4] == `-` && s[7] == `-` {
		y = digits(s, 0, 4)
		m = digits(s, 5, 7)
		d = digits(s, 8, 10)
	} else if (s[2] == `-` || s[2] == `/`) && (s[5] == `-` || s[5] == `/`) {
		d = digits(s, 0, 2)
		m = digits(s, 3, 5)
		y = digits(s, 6, 10)
	} else {
		return error('unsupported timestamp "${s}" (expected YYYY-MM-DD or DD-MM-YYYY)')
	}
	h := digits(s, 11, 13)
	mi := digits(s, 14, 16)
	se := digits(s, 17, 19)
	if y < 0 || m < 0 || d < 0 || h < 0 || mi < 0 || se < 0 {
		return error('non-numeric timestamp "${s}"')
	}
	return checked(y, m, d, h, mi, se)
}

fn checked(y int, m int, d int, h int, mi int, se int) !time.Time {
	if y < 1 || y > 9999 || m < 1 || m > 12 || d < 1 || d > 31 || h < 0 || h > 23 || mi < 0 || mi > 59 || se < 0 || se > 59 {
		return error('timestamp out of range: ${y}-${m}-${d} ${h}:${mi}:${se}')
	}
	return time.Time{ year: y, month: m, day: d, hour: h, minute: mi, second: se }
}

// read_csv streams a delimited activity log from a file.
pub fn read_csv(path string, opts model.ReadOptions) !model.EventLog {
	mut reader := csv.new_reader_from_file(path, delimiter: opts.delimiter) or {
		return error('cannot read ${path}: ${err.msg()}')
	}
	mut last := opts.case_col
	for candidate in [opts.time_col, opts.event_col, opts.activity_col] {
		if candidate > last {
			last = candidate
		}
	}
	mut log := model.EventLog{}
	mut row := 0
	for {
		cols := reader.read() or { break }
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
		log.add_event(model.Event{
			id:       cols[opts.event_col].trim_space()
			case_id:  case_id
			activity: activity
			time:     ts
			sort_key: model.timestamp_key(ts.year, ts.month, ts.day, ts.hour, ts.minute, ts.second)
		})
	}
	if log.trace_count() == 0 {
		return error('no events found in ${path}')
	}
	log.finish()
	return log
}

// parse_csv parses a delimited activity log from a string.
pub fn parse_csv(content string, opts model.ReadOptions) !model.EventLog {
	mut reader := csv.new_reader(content, delimiter: opts.delimiter)
	mut last := opts.case_col
	for candidate in [opts.time_col, opts.event_col, opts.activity_col] {
		if candidate > last {
			last = candidate
		}
	}
	mut log := model.EventLog{}
	mut row := 0
	for {
		cols := reader.read() or { break }
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
		log.add_event(model.Event{
			id:       cols[opts.event_col].trim_space()
			case_id:  case_id
			activity: activity
			time:     ts
			sort_key: model.timestamp_key(ts.year, ts.month, ts.day, ts.hour, ts.minute, ts.second)
		})
	}
	if log.trace_count() == 0 {
		return error('no events found in log')
	}
	log.finish()
	return log
}

fn attr(tag string, key string) string {
	needle := key + '="'
	at := tag.index(needle) or { return '' }
	start := at + needle.len
	rest := tag[start..]
	end := rest.index('"') or { return '' }
	return tag[start..start + end]
}

fn index_from(s string, from int, sub string) ?int {
	if from >= s.len {
		return none
	}
	at := s[from..].index(sub) or { return none }
	return from + at
}

fn block(content string, from int, open string, close string) (int, string) {
	start := index_from(content, from, open) or { return -1, '' }
	end := index_from(content, start, close) or { return -1, '' }
	return end + close.len, content[start..end + close.len]
}

// read_xes parses an XES 1.0 event log. It understands trace/event blocks with
// concept:name and time:timestamp attributes, which covers the standard
// exchange format used by ProM and PM4Py.
pub fn read_xes(path string) !model.EventLog {
	content := os.read_file(path) or {
		return error('cannot read ${path}: ${err.msg()}')
	}
	mut log := model.EventLog{}
	mut pos := 0
	mut case_no := 0
	for {
		next, trace_tag := block(content, pos, '<trace', '</trace>')
		if next < 0 {
			break
		}
		pos = next
		case_no++
		mut case_id := attr(trace_tag, 'value')
		if case_id == '' {
			case_id = 'case-${case_no}'
		}
		mut event_pos := 0
		for {
			ev_next, ev_tag := block(trace_tag, event_pos, '<event', '</event>')
			if ev_next < 0 {
				break
			}
			event_pos = ev_next
			mut activity := ''
			mut timestamp := ''
			mut event_id := ''
			mut tag_pos := 0
			for {
				tag_next, tag := block(ev_tag, tag_pos, '<string', '/>')
				if tag_next < 0 {
					break
				}
				tag_pos = tag_next
				key := attr(tag, 'key')
				value := attr(tag, 'value')
				if key == 'concept:name' {
					if activity == '' {
						activity = value
					} else if event_id == '' {
						event_id = value
					}
				}
			}
			mut date_pos := 0
			for {
				date_next, tag := block(ev_tag, date_pos, '<date', '/>')
				if date_next < 0 {
					break
				}
				date_pos = date_next
				if attr(tag, 'key') == 'time:timestamp' {
					timestamp = attr(tag, 'value')
				}
			}
			if activity == '' {
				continue
			}
			mut key := i64(case_no) * 1_000_000 + i64(log.event_count())
			if timestamp != '' {
				ts := parse_timestamp(timestamp) or { time.Time{} }
				if ts.year > 0 {
					key = model.timestamp_key(ts.year, ts.month, ts.day, ts.hour, ts.minute, ts.second)
					log.add_event(model.Event{
						id:       event_id
						case_id:  case_id
						activity: activity
						time:     ts
						sort_key: key
					})
					continue
				}
			}
			log.add_event(model.Event{
				id:       event_id
				case_id:  case_id
				activity: activity
				sort_key: key
			})
		}
	}
	if log.trace_count() == 0 {
		return error('no traces found in ${path}')
	}
	log.finish()
	return log
}

fn xml_escape(s string) string {
	mut out := ''
	for i, c in s {
		match c {
			38 { out += '&amp;' }
			60 { out += '&lt;' }
			62 { out += '&gt;' }
			34 { out += '&quot;' }
			39 { out += '&apos;' }
			else { out += s[i..i + 1] }
		}
	}
	return out
}

pub fn xml_attr(s string) string {
	return xml_escape(s)
}

// write_xes writes a traditional event log in XES 1.0 format.
pub fn write_xes(path string, log model.EventLog) ! {
	mut out := '<?xml version="1.0" encoding="UTF-8"?>\n'
	out += '<log xes.version="1.0" xmlns="http://www.xes-standard.org/">\n'
	for _, trace in log.traces {
		out += '  <trace>\n'
		out += '    <string key="concept:name" value="${xml_escape(trace.id)}"/>\n'
		for event in trace.event_list() {
			out += '    <event>\n'
			out += '      <string key="concept:name" value="${xml_escape(event.activity)}"/>\n'
			if event.id != '' {
				out += '      <string key="event:id" value="${xml_escape(event.id)}"/>\n'
			}
			if event.time.year > 0 {
				stamp := event.time.str().replace(' ', 'T') + '.000+00:00'
				out += '      <date key="time:timestamp" value="${stamp}"/>\n'
			}
			out += '    </event>\n'
		}
		out += '  </trace>\n'
	}
	out += '</log>\n'
	os.write_file(path, out)!
}
