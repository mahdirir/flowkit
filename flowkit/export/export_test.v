module export

import flowkit
import flowkit.model
import flowkit.io
import flowkit.analysis
import flowkit.discovery
import flowkit.evaluation

fn result() flowkit.Result {
	log := io.parse_csv('case,time,event,activity
t1,2024-01-01 08:00:00,e1,A
t1,2024-01-01 08:01:00,e2,B
t2,2024-01-01 09:00:00,e3,A
t2,2024-01-01 09:01:00,e4,B
', model.ReadOptions{ delimiter: `,` }) or { panic(err.msg()) }
	fp := analysis.build_footprint(log)
	net := discovery.discover(log, fp, .alpha)
	return flowkit.Result{ log: log, footprint: fp, net: net, stats: analysis.compute_stats(log), quality: evaluation.evaluate(log, net) }
}

fn test_text() {
	r := result()
	text := render_text(r.log, r.stats, r.net, r.quality, TextOptions{})
	assert text.contains('Traces:           2')
	assert text.contains('p0: {A} -> {B}')
	assert text.contains('Fitness proxy')
	short := render_text(r.log, r.stats, r.net, r.quality, TextOptions{ summary_only: true })
	assert !short.contains('  p0:')
}

fn test_json() {
	r := result()
	js := render_json(r.log, r.stats, r.net, r.quality)
	assert js.contains('"activities": ["A", "B"]')
	assert js.contains('"places": [')
	assert js.contains('"fitness_proxy"')
}

fn test_dot_and_pnml() {
	r := result()
	dot := render_dot(r.log, r.net)
	assert dot.starts_with('digraph flowkit {')
	assert dot.contains('"A" -> p0;')
	pnml := render_pnml(r.net)
	assert pnml.contains('<place id="p0">')
	assert pnml.contains('<transition id="t-A">')
}
