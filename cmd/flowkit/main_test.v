module main

fn test_defaults() {
	o := parse(['flowkit'])
	assert o.action == .discover
	assert o.opts.input == 'dataset.csv'
	assert o.opts.format == 'text'
	assert o.opts.method == .alpha
}

fn test_flags_and_subcommands() {
	o := parse(['flowkit', 'stats', '--input=log.xes', '-f', 'json', '--method', 'alpha+',
		'--max-variants', '5'])
	assert o.action == .stats
	assert o.opts.input == 'log.xes'
	assert o.opts.format == 'json'
	assert o.opts.method == .alpha_plus
	assert o.opts.max_variants == 5
}

fn test_help_and_errors() {
	assert parse(['flowkit', '--help']).action == .help
	assert parse(['flowkit', 'completions', 'bash']).action == .completions
	assert parse(['flowkit', '-f', 'xml']).action == .usage_error
	assert parse(['flowkit', '--method', 'bogus']).action == .usage_error
	assert parse(['flowkit', '--unknown']).action == .usage_error
}
