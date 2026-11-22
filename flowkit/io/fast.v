// Fast CSV reader: one pass over the file bytes, no per-row string splitting.
// Quoted fields fall back to the standard csv reader.
module io

import os
import time
import flowkit.model

fn digits(s string, from int, to int) int {
	mut n := 0
	for i := from; i < to; i++ {
		c := s[i]
		if c < 48 || c > 57 {
			return -1
		}
		n = n * 10 + int(c - 48)
	}
	return n
}

fn fast_time(s string) !time.Time {
	if s.len < 19 {
		return error('unsupported timestamp "${s}"')
	}
	mut y := 0
	mut mo := 0
	mut d := 0
	if s[4] == `-` && s[7] == `-` {
		y = digits(s, 0, 4)
		mo = digits(s, 5, 7)
		d = digits(s, 8, 10)
	} else if (s[2] == `-` || s[2] == `/`) && (s[5] == `-` || s[5] == `/`) {
		d = digits(s, 0, 2)
		mo = digits(s, 3, 5)
		y = digits(s, 6, 10)
	} else {
		return error('unsupported timestamp "${s}"')
	}
	h := digits(s, 11, 13)
	mi := digits(s, 14, 16)
	se := digits(s, 17, 19)
	if y < 1 || mo < 1 || mo > 12 || d < 1 || d > 31 || h < 0 || h > 23 || mi < 0 || mi > 59 || se < 0 || se > 59 {
		return error('timestamp out of range: ${s}')
	}
	return time.Time{ year: y, month: mo, day: d, hour: h, minute: mi, second: se }
}

fn column(s string, starts []int, ends []int, idx int) string {
	if idx >= starts.len || starts[idx] < 0 {
		return ''
	}
	mut a := starts[idx]
	mut b := ends[idx]
	for a < b && (s[a] == ` ` || s[a] == `\r` || s[a] == `\t`) {
		a++
	}
	for b > a && (s[b - 1] == ` ` || s[b - 1] == `\r` || s[b - 1] == `\t`) {
		b--
	}
	return s[a..b]
}

// read_csv_fast parses an unquoted delimited log in a single pass.
pub fn read_csv_fast(path string, opts model.ReadOptions) !model.EventLog {
	content := os.read_file(path) or {
		return error('cannot read ${path}: ${err.msg()}')
	}
	mut max_col := opts.case_col
	for candidate in [opts.time_col, opts.event_col, opts.activity_col] {
		if candidate > max_col {
			max_col = candidate
		}
	}
	if max_col >= 32 {
		return read_csv(path, opts)
	}

	mut log := model.EventLog{}
	mut starts := []int{len: 32, init: -1}
	mut ends := []int{len: 32, init: -1}
	mut offset := 0
	mut row := 0
	for offset < content.len {
		mut line_end := offset
		for line_end < content.len && content[line_end] != `\n` {
			line_end++
		}
		line := content[offset..line_end]
		offset = line_end + 1
		if line.len == 0 {
			continue
		}
		has_quote := line.index('"') or { -1 }
		if has_quote >= 0 {
			return read_csv(path, opts)
		}
		row++
		if row == 1 && opts.header {
			continue
		}

		for i := 0; i <= max_col; i++ {
			starts[i] = -1
			ends[i] = -1
		}
		mut col := 0
		mut start := 0
		for j := 0; j < line.len && col <= max_col; j++ {
			if line[j] == opts.delimiter {
				starts[col] = start
				ends[col] = j
				col++
				start = j + 1
			}
		}
		if col <= max_col {
			starts[col] = start
			ends[col] = line.len
		}

		case_id := column(line, starts, ends, opts.case_col)
		activity := column(line, starts, ends, opts.activity_col)
		if case_id == '' || activity == '' {
			return error('row ${row}: empty case id or activity')
		}
		raw_time := column(line, starts, ends, opts.time_col)
		ts := fast_time(raw_time) or {
			return error('row ${row}: ${err.msg()}')
		}
		log.add_event_unchecked(model.Event{
			id:       column(line, starts, ends, opts.event_col)
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

pub fn read_csv_smart(path string, opts model.ReadOptions) !model.EventLog {
	return read_csv_fast(path, opts)
}
