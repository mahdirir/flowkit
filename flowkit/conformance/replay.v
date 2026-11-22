// Token-based replay and bounded alignment-based conformance checking.
//
// The net convention used here: a place's `inputs` are transitions that
// produce tokens into it, and its `outputs` are transitions that consume
// tokens from it.
module conformance

import flowkit.model

pub struct TraceReplay {
pub:
	case_id   string
	fitness   f64
	missing   int
	remaining int
	consumed  int
	produced  int
}

pub struct ReplayResult {
pub mut:
	fitness          f64
	missing_tokens   int
	remaining_tokens int
	consumed         int
	produced         int
	traces           []TraceReplay
}

fn initial_marking(net model.PetriNet) []int {
	mut marking := []int{len: net.places.len, init: 0}
	for i, place in net.places {
		if place.inputs.len == 0 && place.outputs.len > 0 {
			marking[i] = 1
		}
	}
	return marking
}

fn final_places(net model.PetriNet) []bool {
	mut final := []bool{len: net.places.len, init: false}
	for i, place in net.places {
		if place.outputs.len == 0 && place.inputs.len > 0 {
			final[i] = true
		}
	}
	return final
}

fn enabled(mut marking []int, candidates []int) (int, int) {
	// Prefer an AND-join (every place consuming this activity holds a token).
	mut all_ok := true
	mut deficit := 0
	for p in candidates {
		if marking[p] == 0 {
			all_ok = false
			deficit++
		}
	}
	if all_ok {
		for p in candidates {
			marking[p]--
		}
		return candidates.len, 0
	}
	// Otherwise choose the XOR branch with the smallest token deficit.
	mut best := -1
	mut best_deficit := 1 << 30
	for p in candidates {
		d := if marking[p] > 0 { 0 } else { 1 }
		if d < best_deficit {
			best_deficit = d
			best = p
		}
	}
	if best < 0 {
		return 0, deficit
	}
	if marking[best] > 0 {
		marking[best]--
		return 1, 0
	}
	return 1, 1
}

pub fn replay(log model.EventLog, net model.PetriNet) ReplayResult {
	final := final_places(net)
	mut result := ReplayResult{ fitness: 1.0 }
	mut entries := []TraceReplay{}

	for _, trace in log.traces {
		mut marking := initial_marking(net)
		mut missing := 0
		mut remaining := 0
		mut consumed := 0
		mut produced := 0
		for event in trace.raw_events() {
			mut candidates := []int{}
			for i, place in net.places {
				if event.activity in place.outputs {
					candidates << i
				}
			}
			if candidates.len > 0 {
				c, m := enabled(mut marking, candidates)
				consumed += c
				missing += m
			} else {
				missing++
			}
			for i, place in net.places {
				if event.activity in place.inputs {
					marking[i]++
					produced++
				}
			}
		}
		for i, count in marking {
			if !final[i] {
				remaining += count
			}
		}
		fit := replay_fitness(missing, remaining, consumed, produced)
		entries << TraceReplay{
			case_id:   trace.id
			fitness:   fit
			missing:   missing
			remaining: remaining
			consumed:  consumed
			produced:  produced
		}
		result.missing_tokens += missing
		result.remaining_tokens += remaining
		result.consumed += consumed
		result.produced += produced
	}
	result.traces = entries
	result.fitness = replay_fitness(result.missing_tokens, result.remaining_tokens, result.consumed, result.produced)
	return result
}

fn replay_fitness(missing int, remaining int, consumed int, produced int) f64 {
	total := consumed + produced
	if total == 0 {
		return if missing + remaining == 0 { 1.0 } else { 0.0 }
	}
	value := 1.0 - f64(missing + remaining) / f64(total)
	if value < 0.0 {
		return 0.0
	}
	return value
}

pub struct AlignmentStep {
pub:
	model string
	log   string
}

pub struct Alignment {
pub:
	case_id  string
	distance int
	fitness  f64
	steps    []AlignmentStep
}

fn transitions(net model.PetriNet) []string {
	mut out := []string{}
	for arc in net.arcs {
		if arc.transition !in out {
			out << arc.transition
		}
	}
	out.sort()
	return out
}

fn fire(net model.PetriNet, marking []int, activity string) ?[]int {
	mut next := marking.clone()
	mut consumers := []int{}
	for i, place in net.places {
		if activity in place.outputs {
			if next[i] == 0 {
				return none
			}
			consumers << i
		}
	}
	if consumers.len == 0 {
		return none
	}
	for i in consumers {
		next[i]--
	}
	for i, place in net.places {
		if activity in place.inputs {
			next[i]++
		}
	}
	return next
}

fn marking_key(marking []int) string {
	mut out := ''
	for count in marking {
		out += '${count},'
	}
	return out
}

pub fn model_sequences(net model.PetriNet, max_states int, max_len int) [][]string {
	mut states := [][]string{}
	mut queue := [][]string{}
	mut seen := map[string]bool{}
	start := initial_marking(net)
	queue << []string{}
	seen[marking_key(start)] = true
	mut head := 0
	for head < queue.len && states.len < max_states {
		seq := queue[head]
		head++
		mut marking := start.clone()
		for activity in seq {
			marking = fire(net, marking, activity) or { marking.clone() }
		}
		for t in transitions(net) {
			if next := fire(net, marking, t) {
				mut candidate := seq.clone()
				candidate << t
				k := marking_key(next) + '|' + candidate.join('>')
				if k !in seen {
					seen[k] = true
					queue << candidate
					if candidate.len >= max_len {
						states << candidate
					}
				}
			}
		}
		if seq.len > 0 && reaches_final(net, marking) {
			states << seq
		}
	}
	if states.len == 0 {
		states << []string{}
	}
	return states
}

fn reaches_final(net model.PetriNet, marking []int) bool {
	final := final_places(net)
	for i, _ in net.places {
		if final[i] && marking[i] > 0 {
			return true
		}
	}
	return false
}

fn edit_distance(a []string, b []string) (int, []AlignmentStep) {
	mut dp := []int{len: (a.len + 1) * (b.len + 1), init: 0}
	for i := 0; i <= a.len; i++ {
		dp[i * (b.len + 1)] = i
	}
	for j := 0; j <= b.len; j++ {
		dp[j] = j
	}
	for i := 1; i <= a.len; i++ {
		for j := 1; j <= b.len; j++ {
			cost := if a[i - 1] == b[j - 1] { 0 } else { 1 }
			del := dp[(i - 1) * (b.len + 1) + j] + 1
			ins := dp[i * (b.len + 1) + j - 1] + 1
			sub := dp[(i - 1) * (b.len + 1) + j - 1] + cost
			mut best := del
			if ins < best {
				best = ins
			}
			if sub < best {
				best = sub
			}
			dp[i * (b.len + 1) + j] = best
		}
	}
	mut steps := []AlignmentStep{}
	mut i := a.len
	mut j := b.len
	for i > 0 || j > 0 {
		if i > 0 && j > 0 {
			cost := if a[i - 1] == b[j - 1] { 0 } else { 1 }
			if dp[i * (b.len + 1) + j] == dp[(i - 1) * (b.len + 1) + j - 1] + cost {
				steps << AlignmentStep{ model: b[j - 1], log: a[i - 1] }
				i--
				j--
				continue
			}
		}
		if i > 0 && dp[i * (b.len + 1) + j] == dp[(i - 1) * (b.len + 1) + j] + 1 {
			steps << AlignmentStep{ model: '-', log: a[i - 1] }
			i--
			continue
		}
		steps << AlignmentStep{ model: b[j - 1], log: '-' }
		j--
	}
	steps.reverse()
	return dp[a.len * (b.len + 1) + b.len], steps
}

pub fn align(log model.EventLog, net model.PetriNet, max_states int, max_len int) []Alignment {
	sequences := model_sequences(net, max_states, max_len)
	mut out := []Alignment{}
	for _, trace in log.traces {
		mut observed := []string{}
		for event in trace.raw_events() {
			observed << event.activity
		}
		mut best_distance := 1 << 30
		mut best_steps := []AlignmentStep{}
		for candidate in sequences {
			distance, steps := edit_distance(observed, candidate)
			if distance < best_distance {
				best_distance = distance
				best_steps = steps.clone()
			}
		}
		mut denom := observed.len
		if denom == 0 {
			denom = 1
		}
		out << Alignment{
			case_id:  trace.id
			distance: best_distance
			fitness:  1.0 - f64(best_distance) / f64(denom)
			steps:    best_steps
		}
	}
	return out
}
