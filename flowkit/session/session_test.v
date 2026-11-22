module session

import contracts
import flowkit.builtins
import flowkit.hooks
import flowkit.model

fn test_builtin_registry() {
	reg := builtins.default_registry()!
	assert reg.reader_names().len >= 3
	assert reg.format_names().len >= 6
	assert reg.algorithm_names().len >= 3
	assert reg.reader_for('log.csv') != none
	assert reg.reader_for('log.xes') != none
	assert reg.reader_for('log.jsonocel') != none
	assert reg.algorithm('alpha') != none
	assert reg.algorithm('nope') == none
}

fn test_duplicate_registration() {
	mut reg := builtins.default_registry()!
	spec := contracts.AlgorithmSpec{
		name:     'alpha'
		discover: fn (log model.EventLog, fp model.Footprint, opts contracts.Options) !model.PetriNet {
			return model.PetriNet{}
		}
	}
	mut rejected := false
	reg.add_algorithm(spec) or { rejected = true }
	assert rejected
}

fn test_session_run() {
	mut reg := builtins.default_registry()!
	reg.add_hook(hooks.annotate())!
	mut ctx := contracts.Context{
		path:    'examples/tiny.csv'
		options: contracts.Options{ delimiter: `,` }
	}
	result := run(mut reg, mut ctx)!
	assert result.stats.traces == 2
	assert result.stats.activities == 2
	assert ctx.metadata['places'] != ''
	assert ctx.rendered.contains('flowkit')
}

fn test_custom_algorithm() {
	mut reg := builtins.default_registry()!
	reg.add_algorithm(contracts.AlgorithmSpec{
		name:     'custom'
		discover: fn (log model.EventLog, fp model.Footprint, opts contracts.Options) !model.PetriNet {
			return model.PetriNet{ start_activities: ['custom'] }
		}
	})!
	mut ctx := contracts.Context{
		path:    'examples/tiny.csv'
		options: contracts.Options{ delimiter: `,`, algorithm: 'custom' }
	}
	result := run(mut reg, mut ctx)!
	assert result.net.start_activities == ['custom']
}
