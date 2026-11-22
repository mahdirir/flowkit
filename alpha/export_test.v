module alpha

fn export_sample() Analysis {
	log := parse_csv('case,time,event,activity
t1,2024-01-01 08:00:00,e1,A
t1,2024-01-01 08:01:00,e2,B
t1,2024-01-01 08:02:00,e3,C
t2,2024-01-01 09:00:00,e4,A
t2,2024-01-01 09:01:00,e5,C
t2,2024-01-01 09:02:00,e6,B
', CsvOptions{ delimiter: `,` }) or {
		panic(err.msg())
	}
	fp := build_footprint(log)
	return Analysis{ eventlog: log, footprint: fp, net: discover_net(log, fp) }
}

fn test_render_text() {
	a := export_sample()
	text := render_text(a, TextOptions{})
	assert text.contains('Traces:           2')
	assert text.contains('Footprint')
	assert text.contains('p0: {A} -> {B}')

	summary := render_text(a, TextOptions{ summary_only: true })
	assert !summary.contains('  p0:')
	assert summary.contains('Places:           4')
}

fn test_render_json() {
	js := render_json(export_sample())
	assert js.contains('"activities": ["A", "B", "C"]')
	assert js.contains('"end_activities": ["B", "C"]')
	assert js.contains('"places": [')
}

fn test_render_dot() {
	dot := render_dot(export_sample())
	assert dot.starts_with('digraph alpha {')
	assert dot.contains('"A" -> p0;')
	assert dot.contains('"C" -> p3;')
}

fn test_escaping() {
	assert json_escape('a"b\\c') == 'a\\"b\\\\c'
	assert json_escape('a\nb') == 'a\\nb'
	assert dot_escape('a"b') == 'a\\"b'
}
