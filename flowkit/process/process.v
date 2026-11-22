// Module process provides a process-tree model with conversions to Petri nets
// and BPMN 2.0 XML. The tree is discovered from trace variants with common
// prefix/suffix factoring, and the conversions are structural.
module process

import strings
import flowkit.model

pub enum Operator {
	activity
	sequence
	choice
	parallel
	loop
}

pub struct ProcessTree {
pub:
	op       Operator
	label    string
	children []ProcessTree
}

pub fn activity(name string) ProcessTree {
	return ProcessTree{ op: .activity, label: name }
}

pub fn sequence(children []ProcessTree) ProcessTree {
	return ProcessTree{ op: .sequence, children: children }
}

pub fn choice(children []ProcessTree) ProcessTree {
	return ProcessTree{ op: .choice, children: children }
}

pub fn parallel(children []ProcessTree) ProcessTree {
	return ProcessTree{ op: .parallel, children: children }
}

pub fn loop(child ProcessTree) ProcessTree {
	return ProcessTree{ op: .loop, children: [child] }
}

fn common_prefix(a []string, b []string) int {
	n := if a.len < b.len { a.len } else { b.len }
	mut i := 0
	for i < n && a[i] == b[i] {
		i++
	}
	return i
}

fn collapse_loops(events []string) []ProcessTree {
	mut out := []ProcessTree{}
	mut i := 0
	for i < events.len {
		mut j := i + 1
		for j < events.len && events[j] == events[i] {
			j++
		}
		if j - i > 1 {
			out << loop(activity(events[i]))
		} else {
			out << activity(events[i])
		}
		i = j
	}
	return out
}

// from_log builds a process tree from the trace variants of a log.
pub fn from_log(log model.EventLog) ProcessTree {
	mut variants := [][]string{}
	for _, trace in log.traces {
		mut events := []string{}
		for event in trace.raw_events() {
			events << event.activity
		}
		if events.len > 0 {
			variants << events
		}
	}
	if variants.len == 0 {
		return ProcessTree{ op: .sequence }
	}
	if variants.len == 1 {
		children := collapse_loops(variants[0])
		if children.len == 1 {
			return children[0]
		}
		return sequence(children)
	}

	mut prefix := variants[0].len
	for variant in variants[1..] {
		p := common_prefix(variants[0], variant)
		if p < prefix {
			prefix = p
		}
	}
	mut suffix := variants[0].len
	for variant in variants[1..] {
		a := variants[0]
		b := variant
		n := if a.len < b.len { a.len } else { b.len }
		mut k := 0
		for k < n && a[a.len - 1 - k] == b[b.len - 1 - k] {
			k++
		}
		if k < suffix {
			suffix = k
		}
	}
	mut min_len := variants[0].len
	for variant in variants {
		if variant.len < min_len {
			min_len = variant.len
		}
	}
	if prefix + suffix > min_len {
		suffix = min_len - prefix
	}

	mut middles := []ProcessTree{}
	for variant in variants {
		mid := variant[prefix..variant.len - suffix]
		if mid.len == 0 {
			middles << ProcessTree{ op: .sequence }
		} else {
			collapsed := collapse_loops(mid)
			middles << if collapsed.len == 1 { collapsed[0] } else { sequence(collapsed) }
		}
	}
	mut parts := []ProcessTree{}
	if prefix > 0 {
		pre := collapse_loops(variants[0][..prefix])
		parts << if pre.len == 1 { pre[0] } else { sequence(pre) }
	}
	parts << if middles.len == 1 { middles[0] } else { choice(middles) }
	if suffix > 0 {
		suf := collapse_loops(variants[0][variants[0].len - suffix..])
		parts << if suf.len == 1 { suf[0] } else { sequence(suf) }
	}
	return if parts.len == 1 { parts[0] } else { sequence(parts) }
}

struct Collected {
mut:
	starts []string
	ends   []string
	places []model.Place
}

fn add_unique(target []string, value string) []string {
	if value !in target {
		mut out := target.clone()
		out << value
		return out
	}
	return target.clone()
}

fn collect(tree ProcessTree, acc Collected) Collected {
	mut out := acc
	match tree.op {
		.activity {
			out.starts = add_unique(out.starts, tree.label)
			out.ends = add_unique(out.ends, tree.label)
		}
		.sequence {
			if tree.children.len == 0 {
				return out
			}
			first := collect(tree.children[0], Collected{})
			out.starts = first.starts.clone()
			out.ends = first.ends.clone()
			out.places = first.places.clone()
			for i := 1; i < tree.children.len; i++ {
				next := collect(tree.children[i], Collected{})
				for end in out.ends {
					for start in next.starts {
						out.places << model.Place{ inputs: [end], outputs: [start] }
					}
				}
				out.ends = next.ends.clone()
				out.places << next.places
			}
		}
		.choice, .parallel {
			if tree.children.len == 0 {
				return out
			}
			for child in tree.children {
				part := collect(child, Collected{})
				out.starts << part.starts
				out.ends << part.ends
				out.places << part.places
			}
		}
		.loop {
			if tree.children.len == 0 {
				return out
			}
			part := collect(tree.children[0], Collected{})
			out.starts = part.starts.clone()
			out.ends = part.ends.clone()
			out.places = part.places.clone()
			for end in part.ends {
				for start in part.starts {
					out.places << model.Place{ inputs: [end], outputs: [start] }
				}
			}
		}
	}
	return out
}

// to_petri converts a process tree to the shared Petri net model.
pub fn to_petri(tree ProcessTree) model.PetriNet {
	acc := collect(tree, Collected{})
	mut net := model.PetriNet{}
	mut seen := map[string]bool{}
	for place in acc.places {
		k := place.key()
		if k !in seen {
			seen[k] = true
			net.places << place
		}
	}
	mut starts := []string{}
	mut ends := []string{}
	for s in acc.starts {
		if s !in starts {
			starts << s
		}
	}
	for e in acc.ends {
		if e !in ends {
			ends << e
		}
	}
	starts.sort()
	ends.sort()
	net.places << model.Place{ inputs: [], outputs: starts }
	net.places << model.Place{ inputs: ends, outputs: [] }
	net.start_activities = starts
	net.end_activities = ends
	for i, place in net.places {
		for a in place.inputs {
			net.arcs << model.Arc{ transition: a, place: i, is_input: true }
		}
		for b in place.outputs {
			net.arcs << model.Arc{ transition: b, place: i, is_input: false }
		}
	}
	return net
}

struct Fragment {
	entry string
	exit  string
	xml   string
}

fn bpmn_escape(s string) string {
	mut b := strings.Builder{}
	for i, c in s {
		match c {
			38 { b.write_string('&amp;') }
			60 { b.write_string('&lt;') }
			62 { b.write_string('&gt;') }
			34 { b.write_string('&quot;') }
			else { b.write_string(s[i..i + 1]) }
		}
	}
	return b.str()
}

fn build_bpmn(tree ProcessTree, counter int) (Fragment, int) {
	mut n := counter
	match tree.op {
		.activity {
			id := 'task_${n}'
			n++
			f := Fragment{ entry: id, exit: id, xml: '      <task id="${id}" name="${bpmn_escape(tree.label)}"/>\n' }
			return f, n
		}
		.sequence {
			if tree.children.len == 0 {
				f := Fragment{ xml: '' }
				return f, n
			}
			mut parts := []Fragment{}
			for child in tree.children {
				part, next := build_bpmn(child, n)
				parts << part
				n = next
			}
			mut xml := ''
			for part in parts {
				xml += part.xml
			}
			for i := 1; i < parts.len; i++ {
				xml += '      <sequenceFlow id="flow_${n}" sourceRef="${parts[i - 1].exit}" targetRef="${parts[i].entry}"/>\n'
				n++
			}
			f := Fragment{ entry: parts[0].entry, exit: parts[parts.len - 1].exit, xml: xml }
			return f, n
		}
		.choice, .parallel {
			kind := if tree.op == .choice { 'Exclusive' } else { 'Parallel' }
			split := 'gw_${n}'
			n++
			join := 'gw_${n}'
			n++
			mut xml := '      <gateway id="${split}" name="${kind} split" gatewayDirection="Diverging"/>\n'
			xml += '      <gateway id="${join}" name="${kind} join" gatewayDirection="Converging"/>\n'
			mut parts := []Fragment{}
			for child in tree.children {
				part, next := build_bpmn(child, n)
				parts << part
				n = next
				xml += part.xml
			}
			for part in parts {
				xml += '      <sequenceFlow id="flow_${n}" sourceRef="${split}" targetRef="${part.entry}"/>\n'
				n++
				xml += '      <sequenceFlow id="flow_${n}" sourceRef="${part.exit}" targetRef="${join}"/>\n'
				n++
			}
			f := Fragment{ entry: split, exit: join, xml: xml }
			return f, n
		}
		.loop {
			if tree.children.len == 0 {
				f := Fragment{ xml: '' }
				return f, n
			}
			part, next := build_bpmn(tree.children[0], n)
			n = next
			split := 'gw_${n}'
			n++
			join := 'gw_${n}'
			n++
			mut xml := '      <gateway id="${split}" name="Loop split" gatewayDirection="Diverging"/>\n'
			xml += '      <gateway id="${join}" name="Loop join" gatewayDirection="Converging"/>\n'
			xml += part.xml
			xml += '      <sequenceFlow id="flow_${n}" sourceRef="${split}" targetRef="${part.entry}"/>\n'
			n++
			xml += '      <sequenceFlow id="flow_${n}" sourceRef="${part.exit}" targetRef="${join}"/>\n'
			n++
			xml += '      <sequenceFlow id="flow_${n}" sourceRef="${join}" targetRef="${split}"/>\n'
			n++
			f := Fragment{ entry: split, exit: join, xml: xml }
			return f, n
		}
	}
}

pub fn render_bpmn(tree ProcessTree) string {
	root, n := build_bpmn(tree, 1)
	mut b := strings.Builder{}
	b.writeln('<?xml version="1.0" encoding="UTF-8"?>')
	b.writeln('<definitions xmlns="http://www.omg.org/spec/BPMN/20100524/MODEL" id="Definitions_1" targetNamespace="http://flowkit.local/bpmn">')
	b.writeln('  <process id="Process_1" isExecutable="false">')
	b.writeln('    <startEvent id="start"/>')
	b.writeln(root.xml)
	b.writeln('    <endEvent id="end"/>')
	b.writeln('    <sequenceFlow id="flow_start" sourceRef="start" targetRef="${root.entry}"/>')
	b.writeln('    <sequenceFlow id="flow_end" sourceRef="${root.exit}" targetRef="end"/>')
	b.writeln('  </process>')
	b.writeln('</definitions>')
	_ = n
	return b.str()
}
