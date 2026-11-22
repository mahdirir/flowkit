module main

fn test_cli_defaults() {
	o := parse_cli(['alpha'])
	assert o.action == .run
	assert o.config.input == 'dataset.csv'
	assert o.config.output == ''
	assert o.config.format == 'text'
	assert o.config.delimiter == `;`
	assert o.config.case_col == 0
	assert o.config.activity_col == 3
}

fn test_cli_flags() {
	o := parse_cli(['alpha', '--input=log.csv', '-f', 'json', '-q', '--no-header', '--activity-col', '2'])
	assert o.action == .run
	assert o.config.input == 'log.csv'
	assert o.config.format == 'json'
	assert o.config.quiet
	assert o.config.no_header
	assert o.config.activity_col == 2
}

fn test_cli_positional_and_separator() {
	o := parse_cli(['alpha', '--', 'my log.csv'])
	assert o.action == .run
	assert o.config.input == 'my log.csv'
}

fn test_cli_help_version_and_errors() {
	assert parse_cli(['alpha', '--help']).action == .help
	assert parse_cli(['alpha', '-h']).action == .help
	assert parse_cli(['alpha', '-V']).action == .version
	assert parse_cli(['alpha', '--version']).action == .version
	assert parse_cli(['alpha', '-f', 'xml']).action == .usage_error
	assert parse_cli(['alpha', '--bogus']).action == .usage_error
	assert parse_cli(['alpha', '-i']).action == .usage_error
	assert parse_cli(['alpha', 'one.csv', 'two.csv']).action == .usage_error
}

fn test_cli_delimiter_and_formats() {
	o := parse_cli(['alpha', '-d', 'tab', '-f', 'gv'])
	assert o.action == .run
	assert o.config.delimiter == 9
	assert o.config.format == 'dot'

	o2 := parse_cli(['alpha', '--delimiter=,', '--format=txt'])
	assert o2.action == .run
	assert o2.config.delimiter == 44
	assert o2.config.format == 'text'
}

fn cli_event(activity string, h int) Event {
	return Event{
		id: '${activity}${h}'
		activity: activity
		key: h
	}
}

fn cli_abc_log() Eventlog {
	return Eventlog{
		activities: ['A', 'B', 'C']
		traces: {
			't1': Trace{ id: 't1', events: [cli_event('A', 1), cli_event('B', 2), cli_event('C', 3)] }
			't2': Trace{ id: 't2', events: [cli_event('A', 4), cli_event('C', 5), cli_event('B', 6)] }
		}
	}
}

fn test_render_formats() {
	e := cli_abc_log()
	f := build_footprint(e)
	n := build_petrynet(e, f)
	r := build_result(e, f, n)

	text := render(r, Config{})
	assert text.contains('Traces:           2')
	assert text.contains('Footprint')
	assert text.contains('p0: {A} -> {B}')

	summary := render(r, Config{ summary_only: true })
	assert !summary.contains('  p0:')
	assert summary.contains('Places:           4')

	js := render(r, Config{ format: 'json' })
	assert js.contains('"activities": ["A", "B", "C"]')
	assert js.contains('"end_activities": ["B", "C"]')

	dot := render(r, Config{ format: 'dot' })
	assert dot.starts_with('digraph alpha {')
	assert dot.contains('"A" -> p0;')
}
