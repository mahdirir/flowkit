module main

fn test_defaults() {
	o := parse(['alpha-miner'])
	assert o.action == .run
	assert o.opts.input == 'dataset.csv'
	assert o.opts.format == 'text'
	assert o.opts.delimiter == `;`
	assert o.opts.header
}

fn test_flags() {
	o := parse(['alpha-miner', '--input=log.csv', '-f', 'json', '-q', '--no-header', '--activity-col',
		'2'])
	assert o.action == .run
	assert o.opts.input == 'log.csv'
	assert o.opts.format == 'json'
	assert o.opts.quiet
	assert !o.opts.header
	assert o.opts.activity_col == 2
}

fn test_delimiter_and_formats() {
	o := parse(['alpha-miner', '-d', 'tab', '-f', 'gv'])
	assert o.action == .run
	assert o.opts.delimiter == 9
	assert o.opts.format == 'dot'

	o2 := parse(['alpha-miner', '--delimiter=,', '--format=txt'])
	assert o2.action == .run
	assert o2.opts.delimiter == 44
	assert o2.opts.format == 'text'
}

fn test_help_version_errors() {
	assert parse(['alpha-miner', '--help']).action == .help
	assert parse(['alpha-miner', '-V']).action == .version
	assert parse(['alpha-miner', '-f', 'xml']).action == .usage_error
	assert parse(['alpha-miner', '--bogus']).action == .usage_error
	assert parse(['alpha-miner', '-i']).action == .usage_error
	assert parse(['alpha-miner', 'a.csv', 'b.csv']).action == .usage_error
}
