module ml

import flowkit.model
import flowkit.io

fn sample() model.EventLog {
	return io.parse_csv('case,time,event,activity
c1,2024-01-01 08:00:00,e1,A
c1,2024-01-01 08:01:00,e2,B
c2,2024-01-01 09:00:00,e3,A
c2,2024-01-01 09:01:00,e4,A
', model.ReadOptions{ delimiter: `,` }) or { panic(err.msg()) }
}

fn test_one_hot() {
	f := one_hot(sample())
	assert f.names == ['A', 'B']
	assert f.case_ids == ['c1', 'c2']
	assert f.rows.len == 2
	assert f.rows[0][0] == 1.0 && f.rows[0][1] == 1.0
	assert f.rows[1][0] == 1.0 && f.rows[1][1] == 0.0
}

fn test_count_and_ngram() {
	counts := count2vec(sample())
	assert counts.rows[1][0] == 2.0
	grams := ngram(sample(), 2)
	assert grams.names == ['A>A', 'A>B']
}

fn test_tfidf_and_export() {
	f := tfidf(sample())
	assert f.rows.len == 2
	csv := to_csv(f)
	assert csv.starts_with('case_id,"A","B"')
	js := to_json(f)
	assert js.contains('"names"')
}
