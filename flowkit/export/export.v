// Module export renders logs, statistics and models to text and interchange
// formats. All output is deterministic so it can be golden-tested.
module export

import os
import strings
import flowkit.model
import flowkit.evaluation

pub struct TextOptions {
pub:
	summary_only bool
	footprint    bool = true
	explain      bool
}

pub fn render_text(log model.EventLog, stats model.Stats, net model.PetriNet, quality evaluation.Quality, opts TextOptions) string {
	mut b := strings.Builder{}
	b.writeln('flowkit - process discovery result')
	b.writeln('---------------------------------')
	b.writeln('')
	b.writeln('Traces:           ${stats.traces}')
	b.writeln('Activities:       ${stats.activities}')
	b.writeln('Events:           ${stats.events}')
	b.writeln('Variants:         ${stats.variants}')
	b.writeln('Places:           ${net.places.len}')
	b.writeln('Arcs:             ${net.arcs.len}')
	b.writeln('')
	b.writeln('Start activities: ${net.start_activities.join(', ')}')
	b.writeln('End activities:   ${net.end_activities.join(', ')}')
	b.writeln('Fitness proxy:    ${quality.fitness_proxy:.3}')
	b.writeln('Precision proxy:  ${quality.precision_proxy:.3}')
	b.writeln('Simplicity:       ${quality.simplicity:.3}')
	b.writeln('')
	if opts.summary_only {
		return b.str()
	}
	if stats.activity_freq.len <= 12 {
		b.writeln('Top activities:')
		for name in stats.top_activities(12) {
			b.writeln('  ${name}: ${stats.activity_freq[name]}')
		}
		b.writeln('')
	}
	b.writeln('Places:')
	for i, place in net.places {
		b.writeln('  p${i}: {${place.inputs.join(', ')}} -> {${place.outputs.join(', ')}}')
	}
	b.writeln('')
	b.writeln('Arcs:')
	for arc in net.arcs {
		if arc.is_input {
			b.writeln('  ${arc.transition} -> p${arc.place}')
		} else {
			b.writeln('  p${arc.place} -> ${arc.transition}')
		}
	}
	if opts.explain {
		b.writeln('')
		b.writeln('Explanation:')
		b.writeln('  Events were grouped by case and sorted by timestamp.')
		b.writeln('  A footprint of causality/concurrency/conflict was computed.')
		b.writeln('  Causal pairs were grown into maximal places and checked against the footprint.')
		b.writeln('  Quality values are structural proxies, not replay/alignment measurements.')
	}
	return b.str()
}

fn json_escape(s string) string {
	mut b := strings.Builder{}
	for i, c in s {
		match c {
			34 { b.write_string('\\"') }
			92 { b.write_string('\\\\') }
			10 { b.write_string('\\n') }
			13 { b.write_string('\\r') }
			9 { b.write_string('\\t') }
			else { b.write_string(s[i..i + 1]) }
		}
	}
	return b.str()
}

fn json_array(items []string) string {
	mut parts := []string{}
	for item in items {
		parts << '"${json_escape(item)}"'
	}
	return '[${parts.join(', ')}]'
}

pub fn render_json(log model.EventLog, stats model.Stats, net model.PetriNet, quality evaluation.Quality) string {
	mut b := strings.Builder{}
	b.writeln('{')
	b.writeln('  "tool": "flowkit",')
	b.writeln('  "summary": {"traces": ${stats.traces}, "activities": ${stats.activities}, "events": ${stats.events}, "variants": ${stats.variants}, "places": ${net.places.len}, "arcs": ${net.arcs.len}},')
	b.writeln('  "quality": {"fitness_proxy": ${quality.fitness_proxy:.4}, "precision_proxy": ${quality.precision_proxy:.4}, "simplicity": ${quality.simplicity:.4}},')
	b.writeln('  "activities": ${json_array(log.activities)},')
	b.writeln('  "start_activities": ${json_array(net.start_activities)},')
	b.writeln('  "end_activities": ${json_array(net.end_activities)},')
	b.writeln('  "places": [')
	for i, place in net.places {
		comma := if i == net.places.len - 1 { '' } else { ',' }
		b.writeln('    {"index": ${i}, "inputs": ${json_array(place.inputs)}, "outputs": ${json_array(place.outputs)}}${comma}')
	}
	b.writeln('  ],')
	b.writeln('  "arcs": [')
	for i, arc in net.arcs {
		comma := if i == net.arcs.len - 1 { '' } else { ',' }
		dir := if arc.is_input { 'in' } else { 'out' }
		b.writeln('    {"transition": "${json_escape(arc.transition)}", "place": ${arc.place}, "direction": "${dir}"}${comma}')
	}
	b.writeln('  ]')
	b.writeln('}')
	return b.str()
}

fn dot_escape(s string) string {
	mut b := strings.Builder{}
	for i, c in s {
		if c == 34 || c == 92 {
			b.write_string('\\')
			b.write_string(s[i..i + 1])
		} else if c == 10 || c == 13 || c == 9 {
			b.write_string(' ')
		} else {
			b.write_string(s[i..i + 1])
		}
	}
	return b.str()
}

pub fn render_dot(log model.EventLog, net model.PetriNet) string {
	mut b := strings.Builder{}
	b.writeln('digraph flowkit {')
	b.writeln('  rankdir=LR;')
	b.writeln('  labelloc="t";')
	b.writeln('  label="flowkit - ${log.trace_count()} traces, ${log.activity_count()} activities";')
	b.writeln('  node [shape=box];')
	for activity in log.activities {
		b.writeln('  "${dot_escape(activity)}";')
	}
	b.writeln('  node [shape=circle, label=""];')
	for i, _ in net.places {
		b.writeln('  p${i};')
	}
	b.writeln('')
	for arc in net.arcs {
		if arc.is_input {
			b.writeln('  "${dot_escape(arc.transition)}" -> p${arc.place};')
		} else {
			b.writeln('  p${arc.place} -> "${dot_escape(arc.transition)}";')
		}
	}
	b.writeln('}')
	return b.str()
}

pub fn render_pnml(net model.PetriNet) string {
	mut b := strings.Builder{}
	b.writeln('<?xml version="1.0" encoding="UTF-8"?>')
	b.writeln('<pnml xmlns="http://www.pnml.org/version-2009/grammar/pnml">')
	b.writeln('  <net id="flowkit-net" type="http://www.pnml.org/version-2009/grammar/ptnet">')
	b.writeln('    <page id="page0">')
	for i, _ in net.places {
		b.writeln('      <place id="p${i}"><name><text>p${i}</text></name></place>')
	}
	mut transitions := []string{}
	for arc in net.arcs {
		if arc.transition !in transitions {
			transitions << arc.transition
		}
	}
	mut ids := map[string]string{}
	for i, t in transitions {
		id := 't_${i}_${pnml_name(t)}'
		ids[t] = id
		b.writeln('      <transition id="${id}"><name><text>${xml(t)}</text></name></transition>')
	}
	mut arc_id := 0
	for arc in net.arcs {
		tid := ids[arc.transition]
		source := if arc.is_input { tid } else { 'p${arc.place}' }
		target := if arc.is_input { 'p${arc.place}' } else { tid }
		b.writeln('      <arc id="a${arc_id}" source="${source}" target="${target}"/>')
		arc_id++
	}
	b.writeln('    </page>')
	b.writeln('  </net>')
	b.writeln('</pnml>')
	return b.str()
}

fn pnml_name(s string) string {
	mut out := ''
	for i, c in s {
		ok := (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == `_` || c == `-` || c == `.`
		if ok {
			out += s[i..i + 1]
		} else {
			out += '_'
		}
	}
	if out == '' {
		return 'transition'
	}
	return out
}

fn xml(s string) string {
	mut b := strings.Builder{}
	for i, c in s {
		match c {
			38 { b.write_string('&amp;') }
			60 { b.write_string('&lt;') }
			62 { b.write_string('&gt;') }
			34 { b.write_string('&quot;') }
			else { b.write_string(s[i..i + 1]) }
		}
	}
	return b.str()
}

pub fn write_file(path string, content string) ! {
	os.write_file(path, content)!
}
