// Module ml turns activity logs into numeric feature tables suitable for
// scikit-learn, Weka or any CSV/JSON consumer. Encodings are deterministic:
// feature names and case order are sorted.
module ml

import strings
import flowkit.model

pub struct Features {
pub:
	names    []string
	case_ids []string
	rows     [][]f64
}

fn case_activities(log model.EventLog) map[string][]string {
	mut out := map[string][]string{}
	for _, trace in log.traces {
		mut events := []string{}
		for event in trace.raw_events() {
			events << event.activity
		}
		out[trace.id] = events
	}
	return out
}

fn sorted_ids(cases map[string][]string) []string {
	mut ids := []string{}
	for id, _ in cases {
		ids << id
	}
	ids.sort()
	return ids
}

fn sorted_names(seen map[string]bool) []string {
	mut names := []string{}
	for name, _ in seen {
		names << name
	}
	names.sort()
	return names
}

fn make_features(names []string, ids []string, rows [][]f64) Features {
	return Features{ names: names, case_ids: ids, rows: rows }
}

pub fn one_hot(log model.EventLog) Features {
	cases := case_activities(log)
	ids := sorted_ids(cases)
	mut seen := map[string]bool{}
	for _, events in cases {
		for event in events {
			seen[event] = true
		}
	}
	names := sorted_names(seen)
	mut rows := [][]f64{}
	for id in ids {
		mut row := []f64{len: names.len, init: 0.0}
		for i, name in names {
			if name in cases[id] {
				row[i] = 1.0
			}
		}
		rows << row
	}
	return make_features(names, ids, rows)
}

pub fn count2vec(log model.EventLog) Features {
	cases := case_activities(log)
	ids := sorted_ids(cases)
	mut seen := map[string]bool{}
	for _, events in cases {
		for event in events {
			seen[event] = true
		}
	}
	names := sorted_names(seen)
	mut rows := [][]f64{}
	for id in ids {
		mut row := []f64{len: names.len, init: 0.0}
		for i, name in names {
			for event in cases[id] {
				if event == name {
					row[i]++
				}
			}
		}
		rows << row
	}
	return make_features(names, ids, rows)
}

pub fn ngram(log model.EventLog, n int) Features {
	cases := case_activities(log)
	ids := sorted_ids(cases)
	mut seen := map[string]bool{}
	for _, events in cases {
		for i := 0; i + n <= events.len; i++ {
			mut parts := []string{}
			for k := 0; k < n; k++ {
				parts << events[i + k]
			}
			seen[parts.join('>')] = true
		}
	}
	names := sorted_names(seen)
	mut rows := [][]f64{}
	for id in ids {
		events := cases[id]
		mut row := []f64{len: names.len, init: 0.0}
		for i := 0; i + n <= events.len; i++ {
			mut parts := []string{}
			for k := 0; k < n; k++ {
				parts << events[i + k]
			}
			key := parts.join('>')
			for j, name in names {
				if name == key {
					row[j]++
				}
			}
		}
		rows << row
	}
	return make_features(names, ids, rows)
}

pub fn tfidf(log model.EventLog) Features {
	counts := count2vec(log)
	n := counts.case_ids.len
	mut idf := []f64{len: counts.names.len, init: 0.0}
	for j, _ in counts.names {
		mut documents := 0
		for row in counts.rows {
			if row[j] > 0 {
				documents++
			}
		}
		idf[j] = if documents == 0 { 0.0 } else { 1.0 + log_n(f64(n) / f64(documents)) }
	}
	mut rows := [][]f64{}
	for row in counts.rows {
		mut total := 0.0
		for v in row {
			total += v
		}
		mut out := []f64{len: row.len, init: 0.0}
		for j, v in row {
			tf := if total == 0 { 0.0 } else { v / total }
			out[j] = tf * idf[j]
		}
		rows << out
	}
	return make_features(counts.names.clone(), counts.case_ids.clone(), rows)
}

fn log_n(x f64) f64 {
	if x <= 0 {
		return 0.0
	}
	return 2.302585092994046 * ln_impl(x)
}

fn ln_impl(x f64) f64 {
	// Newton iteration for natural log, adequate for feature scaling.
	mut y := 0.0
	mut z := x
	for z > 2.0 {
		z /= 2.718281828459045
		y += 1.0
	}
	for z < 0.5 {
		z *= 2.718281828459045
		y -= 1.0
	}
	mut t := (z - 1.0) / (z + 1.0)
	mut sum := t
	mut power := t
	for i := 1; i < 12; i++ {
		power *= t * t
		sum += power / f64(2 * i + 1)
	}
	return y + 2.0 * sum
}

fn csv_escape(s string) string {
	mut b := strings.Builder{}
	for i, c in s {
		if c == 34 {
			b.write_string('""')
		} else {
			b.write_string(s[i..i + 1])
		}
	}
	return b.str()
}

pub fn to_csv(features Features) string {
	mut b := strings.Builder{}
	b.write_string('case_id')
	for name in features.names {
		b.write_string(',"${csv_escape(name)}"')
	}
	b.write_string('\n')
	for i, id in features.case_ids {
		b.write_string('"${csv_escape(id)}"')
		for value in features.rows[i] {
			b.write_string(',${value:.6}')
		}
		b.write_string('\n')
	}
	return b.str()
}

pub fn to_json(features Features) string {
	mut b := strings.Builder{}
	b.writeln('{')
	b.writeln('  "names": [${quote_list(features.names)}],')
	b.writeln('  "case_ids": [${quote_list(features.case_ids)}],')
	b.writeln('  "rows": [')
	for i, row in features.rows {
		comma := if i == features.rows.len - 1 { '' } else { ',' }
		mut values := []string{}
		for v in row {
			values << '${v:.6}'
		}
		b.writeln('    [${values.join(', ')}]${comma}')
	}
	b.writeln('  ]')
	b.writeln('}')
	return b.str()
}

fn quote_list(items []string) string {
	mut parts := []string{}
	for item in items {
		escaped := item.replace('"', '\\"')
		parts << '"${escaped}"'
	}
	return parts.join(', ')
}
