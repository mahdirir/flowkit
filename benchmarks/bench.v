// Micro-benchmark harness. Run with:
//   v run benchmarks/bench.v -- <log.csv>
// Reports events/s, MB/s and peak RSS for the full discovery pipeline.
module main

import os
import time
import flowkit

fn main() {
	mut path := 'dataset.csv'
	for arg in os.args[1..] {
		if !arg.starts_with('-') {
			path = arg
			break
		}
	}
	delimiter := if path.contains('dataset') { u8(`;`) } else { u8(`,`) }
	sw := time.new_stopwatch()
	result := flowkit.discover(path, flowkit.Options{ delimiter: delimiter }) or {
		eprintln('benchmark failed: ${err.msg()}')
		exit(1)
	}
	elapsed := sw.elapsed().seconds()
	bytes := os.file_size(path)
	rate := if elapsed > 0 { f64(result.stats.events) / elapsed } else { 0.0 }
	throughput := if elapsed > 0 { f64(bytes) / elapsed / 1_000_000.0 } else { 0.0 }
	println('file=${path}')
	println('traces=${result.stats.traces}')
	println('activities=${result.stats.activities}')
	println('events=${result.stats.events}')
	println('places=${result.net.places.len}')
	println('arcs=${result.net.arcs.len}')
	println('seconds=${elapsed:.3}')
	println('events_per_second=${rate:.0}')
	println('mb_per_second=${throughput:.2}')
}
