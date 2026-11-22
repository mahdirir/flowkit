// Module analysis builds the derived views of an event log: footprint,
// statistics, variants and the directly-follows graph, plus log filtering.
module analysis

import flowkit.model

fn variant_key(trace model.Trace) string {
	mut parts := []string{}
	for event in trace.raw_events() {
		parts << event.activity
	}
	return parts.join('>')
}

pub fn build_footprint(log model.EventLog) model.Footprint {
	n := log.activity_count()
	mut ids := map[string]int{}
	for i, name in log.activities {
		ids[name] = i
	}
	mut direct := []u32{len: n * n, init: 0}
	for _, trace in log.traces {
		events := trace.raw_events()
		for i := 1; i < events.len; i++ {
			prev := events[i - 1].activity
			cur := events[i].activity
			a := ids[prev]
			b := ids[cur]
			direct[a * n + b]++
		}
	}
	mut matrix := []model.Relation{len: n * n, init: .conflict}
	for a := 0; a < n; a++ {
		for b := 0; b < n; b++ {
			forward := direct[a * n + b] > 0
			backward := direct[b * n + a] > 0
			if forward && backward {
				matrix[a * n + b] = .concurrency
			} else if forward {
				matrix[a * n + b] = .causality
			}
		}
	}
	return model.Footprint{ names: log.activities.clone(), index: ids, matrix: matrix, direct: direct }
}

pub fn compute_stats(log model.EventLog) model.Stats {
	mut activity_freq := map[string]int{}
	mut variant_freq := map[string]int{}
	mut rework := map[string]int{}
	mut events := 0
	mut min_key := i64(0)
	mut max_key := i64(0)
	for _, trace in log.traces {
		events += trace.raw_events().len
		variant := variant_key(trace)
		variant_freq[variant]++
		mut seen := map[string]bool{}
		for event in trace.raw_events() {
			activity_freq[event.activity]++
			if seen[event.activity] {
				rework[event.activity]++
			}
			seen[event.activity] = true
			if min_key == 0 || event.sort_key < min_key {
				min_key = event.sort_key
			}
			if event.sort_key > max_key {
				max_key = event.sort_key
			}
		}
	}
	return model.Stats{
		traces:        log.trace_count()
		activities:    log.activity_count()
		events:        events
		variants:      variant_freq.len
		min_key:       min_key
		max_key:       max_key
		activity_freq: activity_freq
		variant_freq:  variant_freq
		rework:        rework
	}
}

pub fn build_dfg(log model.EventLog, min_count u32) model.Dfg {
	mut ids := map[string]int{}
	for i, name in log.activities {
		ids[name] = i
	}
	n := log.activities.len
	mut counts := []u32{len: n * n, init: 0}
	for _, trace in log.traces {
		events := trace.raw_events()
		for i := 1; i < events.len; i++ {
			prev := events[i - 1].activity
			cur := events[i].activity
			counts[ids[prev] * n + ids[cur]]++
		}
	}
	mut edges := []model.DfgEdge{}
	for a := 0; a < n; a++ {
		for b := 0; b < n; b++ {
			count := counts[a * n + b]
			if count >= min_count {
				edges << model.DfgEdge{ from: log.activities[a], to: log.activities[b], count: count }
			}
		}
	}
	return model.Dfg{ activities: log.activities.clone(), edges: edges }
}

pub struct Filter {
pub:
	min_events         int
	max_events         int
	keep_activities    []string
	drop_activities    []string
	min_activity_count int
	from_key           i64
	to_key             i64
	max_variants       int
}

pub fn filter(log model.EventLog, opts Filter) model.EventLog {
	mut freq := map[string]int{}
	for _, trace in log.traces {
		for event in trace.raw_events() {
			freq[event.activity]++
		}
	}
	mut variants := map[string]int{}
	for _, trace in log.traces {
		variants[variant_key(trace)]++
	}
	mut var_keep := map[string]bool{}
	if opts.max_variants > 0 {
		mut names := []string{}
		for name, _ in variants {
			names << name
		}
		mut sorted := []string{}
		for names.len > 0 {
			mut best := 0
			for k := 1; k < names.len; k++ {
				if variants[names[k]] > variants[names[best]] {
					best = k
				}
			}
			sorted << names[best]
			mut rest := []string{}
			for k, name in names {
				if k != best {
					rest << name
				}
			}
			names = rest.clone()
		}
		names = sorted.clone()
		for i := 0; i < opts.max_variants && i < names.len; i++ {
			var_keep[names[i]] = true
		}
	}

	mut out := model.EventLog{}
	for _, trace in log.traces {
		events := trace.raw_events()
		if opts.min_events > 0 && events.len < opts.min_events {
			continue
		}
		if opts.max_events > 0 && events.len > opts.max_events {
			continue
		}
		if opts.max_variants > 0 && !var_keep[variant_key(trace)] {
			continue
		}
		for event in events {
			if opts.from_key != 0 && event.sort_key < opts.from_key {
				continue
			}
			if opts.to_key != 0 && event.sort_key > opts.to_key {
				continue
			}
			if opts.keep_activities.len > 0 && event.activity !in opts.keep_activities {
				continue
			}
			if event.activity in opts.drop_activities {
				continue
			}
			if opts.min_activity_count > 0 && freq[event.activity] < opts.min_activity_count {
				continue
			}
			out.add_event(event)
		}
	}
	out.finish()
	return out
}
