module session

import contracts
import flowkit.analysis
import flowkit.builtins
import flowkit.io
import flowkit.model
import flowkit.process

fn review_log() model.EventLog {
	return io.parse_csv('c,t,e,a
1,2024-01-01 08:00:00,x,A>B
2,2024-01-01 09:00:00,y,A
2,2024-01-01 09:01:00,z,B
', model.ReadOptions{ delimiter: `,` }) or { panic(err.msg()) }
}

fn test_missing_case_reports_none() {
	mut log := model.EventLog{}
	log.add_event(model.Event{ case_id: 'a', activity: 'A', sort_key: 1 })
	mut missing := false
	log.trace('nope') or { missing = true }
	assert missing
}

fn test_non_digit_timestamp_rejected() {
	mut rejected := false
	io.parse_csv('c,t,e,a
1,2024-01-01 08:ab:cd,x,A
', model.ReadOptions{ delimiter: `,` }) or { rejected = true }
	assert rejected
}

fn test_activity_delimiter_does_not_collide() {
	assert analysis.compute_stats(review_log()).variants == 2
}

fn test_short_variant_does_not_panic() {
	tree := process.from_log(review_log())
	assert tree.op == .choice || tree.op == .sequence
}

fn test_filtered_log_reaches_context() {
	mut reg := builtins.default_registry()!
	mut ctx := contracts.Context{
		path:    'examples/simple.csv'
		options: contracts.Options{
			delimiter: `,`
			filters:   [analysis.Filter{ keep_activities: ['A'] }]
		}
	}
	result := run(mut reg, mut ctx)!
	assert ctx.log.event_count() == result.stats.events
}
