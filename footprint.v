module main

enum Relation {
	conflict // # : neither activity directly follows the other
	causality // -> : a directly follows b, but b never directly follows a
	concurrency // || : both activities directly follow each other
}

struct Footprint {
mut:
	rel map[string]map[string]Relation
}

fn relation_str(r Relation) string {
	match r {
		.conflict {
			return '#'
		}
		.causality {
			return '->'
		}
		.concurrency {
			return '||'
		}
	}
}

fn (f Footprint) of(a string, b string) Relation {
	if a !in f.rel {
		return .conflict
	}
	if b !in f.rel[a] {
		return .conflict
	}
	return f.rel[a][b]
}

fn build_footprint(e Eventlog) Footprint {
	mut f := Footprint{}
	mut direct := map[string]map[string]bool{}

	for x in e.activities {
		f.rel[x] = map[string]Relation{}
		direct[x] = map[string]bool{}
		for y in e.activities {
			f.rel[x][y] = .conflict
		}
	}

	for _, t in e.traces {
		for i := 1; i < t.events.len; i++ {
			x := t.events[i - 1].activity
			y := t.events[i].activity
			direct[x][y] = true
		}
	}

	for x in e.activities {
		for y in e.activities {
			xy := direct[x][y]
			yx := direct[y][x]
			if xy && yx {
				f.rel[x][y] = .concurrency
			} else if xy {
				f.rel[x][y] = .causality
			}
		}
	}

	return f
}
