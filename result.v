module main

import os
import time

struct Result {
	traces     int
	activities int
	places     int
	arcs       int
	eventlog   Eventlog
	footprint  Footprint
	net        PetriNet
}

fn build_result(e Eventlog, f Footprint, p PetriNet) Result {
	return Result{
		traces: e.traces.len
		activities: e.activities.len
		places: p.places.len
		arcs: p.arcs.len
		eventlog: e
		footprint: f
		net: p
	}
}

fn render(r Result, cfg Config) string {
	if cfg.format == 'json' {
		return render_json(r)
	}
	if cfg.format == 'dot' {
		return render_dot(r)
	}
	return render_text(r, cfg)
}

fn render_text(r Result, cfg Config) string {
	mut lines := []string{}
	lines << 'alpha ${app_version} - process discovery result'
	lines << '---------------------------------------------'
	lines << ''
	lines << 'Traces:           ${r.traces}'
	lines << 'Activities:       ${r.activities}'
	lines << 'Places:           ${r.places}'
	lines << 'Arcs:             ${r.arcs}'
	lines << ''
	lines << 'Start activities: ${r.net.start_activities.join(', ')}'
	lines << 'End activities:   ${r.net.end_activities.join(', ')}'
	lines << ''
	if !cfg.summary_only && r.activities <= 12 {
		lines << 'Footprint (# never follows, -> causality, || concurrency):'
		for a in r.eventlog.activities {
			mut cells := []string{}
			for b in r.eventlog.activities {
				cells << relation_str(r.footprint.of(a, b))
			}
			lines << '  ${a}: ${cells.join('  ')}'
		}
		lines << ''
	}
	if !cfg.summary_only {
		lines << 'Places:'
		for i, p in r.net.places {
			lines << '  p${i}: {${p.inputs.join(', ')}} -> {${p.outputs.join(', ')}}'
		}
		lines << ''
		lines << 'Arcs:'
		for a in r.net.arcs {
			if a.is_input {
				lines << '  ${a.transition} -> p${a.place}'
			} else {
				lines << '  p${a.place} -> ${a.transition}'
			}
		}
	}
	return lines.join('\n') + '\n'
}

fn render_json(r Result) string {
	mut lines := []string{}
	lines << '{'
	lines << '  "version": "${app_version}",'
	lines << '  "summary": {"traces": ${r.traces}, "activities": ${r.activities}, "places": ${r.places}, "arcs": ${r.arcs}},'
	lines << '  "activities": ${json_array(r.eventlog.activities)},'
	lines << '  "start_activities": ${json_array(r.net.start_activities)},'
	lines << '  "end_activities": ${json_array(r.net.end_activities)},'
	lines << '  "places": ['
	for i, p in r.net.places {
		comma := if i == r.net.places.len - 1 { '' } else { ',' }
		lines << '    {"index": ${i}, "inputs": ${json_array(p.inputs)}, "outputs": ${json_array(p.outputs)}}${comma}'
	}
	lines << '  ],'
	lines << '  "arcs": ['
	for i, a in r.net.arcs {
		comma := if i == r.net.arcs.len - 1 { '' } else { ',' }
		direction := if a.is_input { 'in' } else { 'out' }
		lines << '    {"transition": "${json_escape(a.transition)}", "place": ${a.place}, "direction": "${direction}"}${comma}'
	}
	lines << '  ]'
	lines << '}'
	return lines.join('\n') + '\n'
}

fn render_dot(r Result) string {
	mut lines := []string{}
	lines << 'digraph alpha {'
	lines << '  rankdir=LR;'
	lines << '  labelloc="t";'
	lines << '  label="alpha ${app_version} - ${r.traces} traces, ${r.activities} activities";'
	lines << '  node [shape=box];'
	for activity in r.eventlog.activities {
		lines << '  "${dot_escape(activity)}";'
	}
	lines << '  node [shape=circle, label=""];'
	for i, _ in r.net.places {
		lines << '  p${i};'
	}
	lines << ''
	for a in r.net.arcs {
		if a.is_input {
			lines << '  "${dot_escape(a.transition)}" -> p${a.place};'
		} else {
			lines << '  p${a.place} -> "${dot_escape(a.transition)}";'
		}
	}
	lines << '}'
	return lines.join('\n') + '\n'
}

fn execute(cfg Config) int {
	sw := time.new_stopwatch()
	if !cfg.quiet {
		eprintln('alpha: reading ${cfg.input}')
	}
	mut log := build_eventlog(cfg.input, cfg) or {
		eprintln('alpha: error: ${err.msg()}')
		return 1
	}
	if !cfg.quiet {
		eprintln('alpha: ${log.traces.len} traces, ${log.activities.len} activities')
	}
	footprint := build_footprint(log)
	net := build_petrynet(log, footprint)
	result := build_result(log, footprint, net)
	output := render(result, cfg)

	if cfg.output == '' {
		print(output)
	} else {
		os.write_file(cfg.output, output) or {
			eprintln('alpha: error: cannot write ${cfg.output}: ${err.msg()}')
			return 1
		}
		if !cfg.quiet {
			eprintln('alpha: wrote ${cfg.output}')
		}
	}
	if cfg.verbose {
		eprintln('alpha: ${net.places.len} places, ${net.arcs.len} arcs')
	}
	if !cfg.quiet {
		eprintln('alpha: finished in ${sw.elapsed().seconds()}s')
	}
	return 0
}
