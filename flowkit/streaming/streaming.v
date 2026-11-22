// Module streaming supports incremental event processing. Counters and DFG
// edges are updated one event at a time, so arbitrarily large logs can be
// summarised without holding the full event log in memory.
module streaming

import os
import encoding.csv
import flowkit.model
import flowkit.io

pub struct StreamStats {
pub mut:
	events     int
	cases      map[string]bool
	activities map[string]int
	edges      map[string]u32
mut:
	last  map[string]string
	order []string
}

pub fn new() StreamStats {
	return StreamStats{}
}

pub fn (mut s StreamStats) push(case_id string, activity string) {
	s.events++
	s.cases[case_id] = true
	s.activities[activity]++
	if activity !in s.order {
		s.order << activity
	}
	previous := s.last[case_id]
	if previous != '' {
		edge := '${previous}>${activity}'
		s.edges[edge]++
	}
	s.last[case_id] = activity
}

pub fn (s StreamStats) case_count() int {
	return s.cases.len
}

pub fn (s StreamStats) activity_count() int {
	return s.order.len
}

pub fn (s StreamStats) dfg(min_count u32) model.Dfg {
	mut edges := []model.DfgEdge{}
	for edge, count in s.edges {
		if count < min_count {
			continue
		}
		parts := edge.split('>')
		if parts.len == 2 {
			edges << model.DfgEdge{ from: parts[0], to: parts[1], count: count }
		}
	}
	edges.sort_with_compare(fn (a &model.DfgEdge, b &model.DfgEdge) int {
		if a.count > b.count {
			return -1
		}
		if a.count < b.count {
			return 1
		}
		if a.from < b.from {
			return -1
		}
		return 0
	})
	return model.Dfg{ activities: s.order.clone(), edges: edges }
}

pub fn (s StreamStats) top_activities(limit int) []string {
	mut names := s.order.clone()
	mut sorted := []string{}
	for names.len > 0 {
		mut best := 0
		for i := 1; i < names.len; i++ {
			if s.activities[names[i]] > s.activities[names[best]] {
				best = i
			}
		}
		sorted << names[best]
		mut rest := []string{}
		for i, name in names {
			if i != best {
				rest << name
			}
		}
		names = rest.clone()
	}
	if limit > 0 && limit < sorted.len {
		return sorted[..limit]
	}
	return sorted
}

pub fn follow_csv(path string, opts model.ReadOptions) !StreamStats {
	mut reader := csv.new_reader_from_file(path, delimiter: opts.delimiter) or {
		return error('cannot read ${path}: ${err.msg()}')
	}
	mut last := opts.case_col
	for candidate in [opts.time_col, opts.event_col, opts.activity_col] {
		if candidate > last {
			last = candidate
		}
	}
	mut stats := new()
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
		raw_time := cols[opts.time_col].trim_space()
		if raw_time != '' {
			_ = io.parse_timestamp(raw_time) or {
				return error('row ${row}: ${err.msg()}')
			}
		}
		stats.push(case_id, activity)
	}
	if stats.events == 0 {
		return error('no events found in ${path}')
	}
	return stats
}

pub fn from_file(path string) !StreamStats {
	return if path.ends_with('.csv') {
		follow_csv(path, model.ReadOptions{ delimiter: `,` })
	} else {
		follow_csv(path, model.ReadOptions{})
	}
}

pub fn file_exists(path string) bool {
	_ = os.read_file(path) or { return false }
	return true
}
