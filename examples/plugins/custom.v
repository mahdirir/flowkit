// Example third-party extension package. Copy this directory into your own
// project, change the implementations, and register it with a flowkit registry.
// It has no dependency on flowkit internals beyond the public contracts.
module plugins

import os
import flowkit
import flowkit.model

fn read_pipe_log(path string, opts flowkit.Options) !model.EventLog {
	content := os.read_file(path) or {
		return error('cannot read ${path}: ${err.msg()}')
	}
	mut log := model.EventLog{}
	mut n := 0
	for line in content.split_into_lines() {
		if line.trim_space() == '' {
			continue
		}
		parts := line.split('|')
		if parts.len < 2 {
			return error('line ${n}: expected case|activity')
		}
		n++
		log.add_event(model.Event{
			id:       '${n}'
			case_id:  parts[0].trim_space()
			activity: parts[1].trim_space()
			sort_key: n
		})
	}
	if log.trace_count() == 0 {
		return error('empty log')
	}
	log.finish()
	return log
}

fn simple_alpha(log model.EventLog, fp model.Footprint, opts flowkit.Options) !model.PetriNet {
	return flowkit.discover_net(log, fp, .alpha)
}

// register adds all extensions in this package to a registry.
pub fn register(mut reg flowkit.Registry) ! {
	reg.add_reader(flowkit.ReaderSpec{
		name:       'pipe'
		extensions: ['log']
		read:       read_pipe_log
	})!
	reg.add_algorithm(flowkit.AlgorithmSpec{
		name:     'simple_alpha'
		discover: simple_alpha
	})!
	reg.add_hook(flowkit.normalize_hook())!
}

// usage:
//
//	mut reg := flowkit.new_registry()!
//	plugins.register(mut reg)!
//	ctx := flowkit.new_context('log.log', flowkit.Options{ algorithm: 'simple_alpha' })
//	result := flowkit.run(mut reg, mut ctx)!
