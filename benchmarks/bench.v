// Benchmark harness. Run with:
//   v run benchmarks/bench.v -- <log.csv>
// Reports total throughput and per-stage timings for the discovery pipeline.
module main

import os
import time
import flowkit

fn ms(sw time.StopWatch) f64 {
	return sw.elapsed().microseconds() / 1000.0
}

fn main() {
	mut path := 'dataset.csv'
	for arg in os.args[1..] {
		if !arg.starts_with('-') {
			path = arg
			break
		}
	}
	delimiter := if path.contains('dataset') { u8(`;`) } else { u8(`,`) }

	mut stage := time.new_stopwatch()
	_ = os.read_file(path) or { exit(1) }
	raw_read_ms := ms(stage)

	stage.restart()
	log := flowkit.read_csv(path, flowkit.ReadOptions{ delimiter: delimiter }) or {
		eprintln('benchmark failed: ${err.msg()}')
		exit(1)
	}
	read_ms := ms(stage)

	stage.restart()
	footprint := flowkit.build_footprint(log)
	footprint_ms := ms(stage)

	stage.restart()
	net := flowkit.discover_net(log, footprint, .alpha)
	discover_ms := ms(stage)

	stage.restart()
	stats := flowkit.compute_stats(log)
	stats_ms := ms(stage)

	stage.restart()
	quality := flowkit.evaluate(log, net)
	evaluate_ms := ms(stage)

	stage.restart()
	report := flowkit.check_footprints(log, net)
	conformance_ms := ms(stage)

	stage.restart()
	dfg := flowkit.build_dfg(log, 1)
	dfg_ms := ms(stage)

	result := flowkit.Result{
		log:       log
		footprint: footprint
		net:       net
		stats:     stats
		quality:   quality
		report:    report
		dfg:       dfg
	}
	stage.restart()
	text := flowkit.render_text(result, flowkit.TextOptions{ summary_only: true })
	render_ms := ms(stage)

	total := read_ms + footprint_ms + discover_ms + stats_ms + evaluate_ms + conformance_ms + dfg_ms + render_ms
	bytes := os.file_size(path)
	println('file=${path}')
	println('traces=${stats.traces}')
	println('activities=${stats.activities}')
	println('events=${stats.events}')
	println('places=${net.places.len}')
	println('arcs=${net.arcs.len}')
	println('raw_read_ms=${raw_read_ms:.1}')
	println('read_ms=${read_ms:.1}')
	println('footprint_ms=${footprint_ms:.1}')
	println('discover_ms=${discover_ms:.1}')
	println('stats_ms=${stats_ms:.1}')
	println('evaluate_ms=${evaluate_ms:.1}')
	println('conformance_ms=${conformance_ms:.1}')
	println('dfg_ms=${dfg_ms:.1}')
	println('render_ms=${render_ms:.1}')
	println('total_ms=${total:.1}')
	println('events_per_second=${if total > 0 { f64(stats.events) / (total / 1000.0) } else { 0.0 }:.0}')
	println('mb_per_second=${if total > 0 {
		f64(bytes) / (total / 1000.0) / 1_000_000.0
	} else {
		0.0
	}:.2}')
	_ = text
}
