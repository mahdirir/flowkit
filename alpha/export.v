module alpha

// TextOptions controls the human-readable renderer.
pub struct TextOptions {
pub:
	summary_only bool
}

// render_text renders an analysis as a human-readable report.
pub fn render_text(a Analysis, opts TextOptions) string {
	mut lines := []string{}
	lines << 'alpha ${version} - process discovery result'
	lines << '---------------------------------------------'
	lines << ''
	lines << 'Traces:           ${a.eventlog.trace_count()}'
	lines << 'Activities:       ${a.eventlog.activity_count()}'
	lines << 'Places:           ${a.net.places.len}'
	lines << 'Arcs:             ${a.net.arcs.len}'
	lines << ''
	lines << 'Start activities: ${a.net.start_activities.join(', ')}'
	lines << 'End activities:   ${a.net.end_activities.join(', ')}'
	lines << ''

	if opts.summary_only {
		return lines.join('\n') + '\n'
	}

	if a.eventlog.activity_count() <= 12 {
		lines << 'Footprint (# never follows, -> causality, || concurrency):'
		for activity in a.eventlog.activities {
			mut cells := []string{}
			for other in a.eventlog.activities {
				cells << a.footprint.relation(activity, other).str()
			}
			lines << '  ${activity}: ${cells.join('  ')}'
		}
		lines << ''
	}

	lines << 'Places:'
	for i, place in a.net.places {
		lines << '  p${i}: {${place.inputs.join(', ')}} -> {${place.outputs.join(', ')}}'
	}
	lines << ''
	lines << 'Arcs:'
	for arc in a.net.arcs {
		if arc.is_input {
			lines << '  ${arc.transition} -> p${arc.place}'
		} else {
			lines << '  p${arc.place} -> ${arc.transition}'
		}
	}
	return lines.join('\n') + '\n'
}

fn json_escape(s string) string {
	mut out := ''
	for i, c in s {
		match c {
			34 {
				out += '\\"'
			}
			92 {
				out += '\\\\'
			}
			10 {
				out += '\\n'
			}
			13 {
				out += '\\r'
			}
			9 {
				out += '\\t'
			}
			else {
				out += s[i..i + 1]
			}
		}
	}
	return out
}

fn dot_escape(s string) string {
	mut out := ''
	for i, c in s {
		if c == 34 || c == 92 {
			out += '\\'
			out += s[i..i + 1]
		} else if c == 10 || c == 13 || c == 9 {
			out += ' '
		} else {
			out += s[i..i + 1]
		}
	}
	return out
}

fn json_array(items []string) string {
	mut parts := []string{}
	for item in items {
		parts << '"${json_escape(item)}"'
	}
	return '[${parts.join(', ')}]'
}

// render_json renders an analysis as a JSON document.
pub fn render_json(a Analysis) string {
	mut lines := []string{}
	lines << '{'
	lines << '  "version": "${version}",'
	lines << '  "summary": {"traces": ${a.eventlog.trace_count()}, "activities": ${a.eventlog.activity_count()}, "places": ${a.net.places.len}, "arcs": ${a.net.arcs.len}},'
	lines << '  "activities": ${json_array(a.eventlog.activities)},'
	lines << '  "start_activities": ${json_array(a.net.start_activities)},'
	lines << '  "end_activities": ${json_array(a.net.end_activities)},'
	lines << '  "places": ['
	for i, place in a.net.places {
		comma := if i == a.net.places.len - 1 { '' } else { ',' }
		lines << '    {"index": ${i}, "inputs": ${json_array(place.inputs)}, "outputs": ${json_array(place.outputs)}}${comma}'
	}
	lines << '  ],'
	lines << '  "arcs": ['
	for i, arc in a.net.arcs {
		comma := if i == a.net.arcs.len - 1 { '' } else { ',' }
		direction := if arc.is_input { 'in' } else { 'out' }
		lines << '    {"transition": "${json_escape(arc.transition)}", "place": ${arc.place}, "direction": "${direction}"}${comma}'
	}
	lines << '  ]'
	lines << '}'
	return lines.join('\n') + '\n'
}

// render_dot renders an analysis as a Graphviz directed graph.
pub fn render_dot(a Analysis) string {
	mut lines := []string{}
	lines << 'digraph alpha {'
	lines << '  rankdir=LR;'
	lines << '  labelloc="t";'
	lines << '  label="alpha ${version} - ${a.eventlog.trace_count()} traces, ${a.eventlog.activity_count()} activities";'
	lines << '  node [shape=box];'
	for activity in a.eventlog.activities {
		lines << '  "${dot_escape(activity)}";'
	}
	lines << '  node [shape=circle, label=""];'
	for i, _ in a.net.places {
		lines << '  p${i};'
	}
	lines << ''
	for arc in a.net.arcs {
		if arc.is_input {
			lines << '  "${dot_escape(arc.transition)}" -> p${arc.place};'
		} else {
			lines << '  p${arc.place} -> "${dot_escape(arc.transition)}";'
		}
	}
	lines << '}'
	return lines.join('\n') + '\n'
}
