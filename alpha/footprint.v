module alpha

// Relation is the direct-follow relation between two activities.
pub enum Relation {
	conflict    // # : neither activity directly follows the other
	causality   // -> : a directly follows b, but b never directly follows a
	concurrency // || : both activities directly follow each other
}

// str returns the symbolic name of the relation.
pub fn (r Relation) str() string {
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

// Footprint is the relation matrix of an event log.
pub struct Footprint {
mut:
	rel map[string]map[string]Relation
}

// relation returns the relation from activity a to activity b.
pub fn (f Footprint) relation(a string, b string) Relation {
	if a !in f.rel {
		return .conflict
	}
	if b !in f.rel[a] {
		return .conflict
	}
	return f.rel[a][b]
}

// build_footprint computes the footprint of an event log.
pub fn build_footprint(log EventLog) Footprint {
	mut fp := Footprint{}
	mut direct := map[string]map[string]bool{}

	for activity in log.activities {
		fp.rel[activity] = map[string]Relation{}
		direct[activity] = map[string]bool{}
		for other in log.activities {
			fp.rel[activity][other] = .conflict
		}
	}

	for _, trace in log.traces {
		events := trace.event_list()
		for i := 1; i < events.len; i++ {
			direct[events[i - 1].activity][events[i].activity] = true
		}
	}

	for activity in log.activities {
		for other in log.activities {
			forward := direct[activity][other]
			backward := direct[other][activity]
			if forward && backward {
				fp.rel[activity][other] = .concurrency
			} else if forward {
				fp.rel[activity][other] = .causality
			}
		}
	}
	return fp
}
