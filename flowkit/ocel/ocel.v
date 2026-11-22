// Module ocel reads object-centric event logs (OCEL 2.0 JSON), flattens them
// to traditional event logs for one object type, and builds object-centric
// views: the object type graph and the object-centric DFG.
//
// The JSON reader is intentionally small and dependency-free: it extracts the
// events/objects arrays and their string fields.
module ocel

import os
import strings
import flowkit.model
import flowkit.io

pub struct OcelRelationship {
pub:
	object_id   string
	object_type string
	qualifier   string
}

pub struct OcelEvent {
pub:
	id            string
	activity      string
	time          string
	relationships []OcelRelationship
}

pub struct OcelObject {
pub:
	id   string
	type string
}

pub struct OcelLog {
pub mut:
	events  []OcelEvent
	objects []OcelObject
}

fn skip_space(s string, from int) int {
	mut i := from
	for i < s.len && (s[i] == ` ` || s[i] == `\n` || s[i] == `\r` || s[i] == `\t`) {
		i++
	}
	return i
}

fn find_key(s string, key string) ?int {
	needle := '"' + key + '"'
	at := s.index(needle) or { return none }
	return at + needle.len
}

fn string_field(obj string, key string) string {
	after := find_key(obj, key) or { return '' }
	colon := obj[after..].index(':') or { return '' }
	start := skip_space(obj, after + colon + 1)
	if start >= obj.len || obj[start] != `"` {
		return ''
	}
	end := obj[start + 1..].index('"') or { return '' }
	return json_unescape(obj[start + 1..start + 1 + end])
}

fn json_unescape(s string) string {
	mut b := strings.Builder{}
	mut i := 0
	for i < s.len {
		if s[i] == 92 && i + 1 < s.len {
			next := s[i + 1]
			if next == `n` {
				b.write_string('\n')
			} else if next == `r` {
				b.write_string('\r')
			} else if next == `t` {
				b.write_string('\t')
			} else {
				b.write_string(s[i + 1..i + 2])
			}
			i += 2
			continue
		}
		b.write_string(s[i..i + 1])
		i++
	}
	return b.str()
}

fn array_field(obj string, key string) string {
	after := find_key(obj, key) or { return '' }
	colon := obj[after..].index(':') or { return '' }
	start := skip_space(obj, after + colon + 1)
	if start >= obj.len || obj[start] != `[` {
		return ''
	}
	mut depth := 0
	mut quoted := false
	mut escaped := false
	for i := start; i < obj.len; i++ {
		c := obj[i]
		if quoted {
			if escaped {
				escaped = false
			} else if c == `\\` {
				escaped = true
			} else if c == `"` {
				quoted = false
			}
			continue
		}
		if c == `"` {
			quoted = true
		} else if c == `[` || c == `{` {
			depth++
		} else if c == `]` || c == `}` {
			depth--
			if depth == 0 {
				return obj[start + 1..i]
			}
		}
	}
	return ''
}

fn split_objects(array string) []string {
	mut out := []string{}
	mut depth := 0
	mut quoted := false
	mut escaped := false
	mut start := -1
	for i := 0; i < array.len; i++ {
		c := array[i]
		if quoted {
			if escaped {
				escaped = false
			} else if c == `\\` {
				escaped = true
			} else if c == `"` {
				quoted = false
			}
			continue
		}
		if c == `"` {
			quoted = true
			continue
		}
		if c == `{` {
			if depth == 0 {
				start = i
			}
			depth++
		} else if c == `}` {
			depth--
			if depth == 0 && start >= 0 {
				out << array[start..i + 1]
				start = -1
			}
		}
	}
	return out
}

fn pick(primary string, fallback string) string {
	return if primary != '' { primary } else { fallback }
}

fn parse_relationship(obj string) OcelRelationship {
	return OcelRelationship{
		object_id:   pick(string_field(obj, 'objectId'), string_field(obj, 'ocel:oid'))
		object_type: pick(string_field(obj, 'objectType'), string_field(obj, 'ocel:type'))
		qualifier:   pick(string_field(obj, 'qualifier'), string_field(obj, 'ocel:qualifier'))
	}
}

fn parse_event(obj string) OcelEvent {
	mut relations := []OcelRelationship{}
	mut raw := array_field(obj, 'relationships')
	if raw == '' {
		raw = array_field(obj, 'ocel:relationships')
	}
	for item in split_objects(raw) {
		relations << parse_relationship(item)
	}
	return OcelEvent{
		id:            pick(string_field(obj, 'id'), string_field(obj, 'ocel:eid'))
		activity:      pick(string_field(obj, 'type'), string_field(obj, 'ocel:activity'))
		time:          pick(string_field(obj, 'time'), string_field(obj, 'ocel:timestamp'))
		relationships: relations
	}
}

fn parse_object(obj string) OcelObject {
	return OcelObject{
		id:   pick(string_field(obj, 'id'), string_field(obj, 'ocel:oid'))
		type: pick(string_field(obj, 'type'), string_field(obj, 'ocel:type'))
	}
}

pub fn read_ocel_json(path string) !OcelLog {
	content := os.read_file(path) or {
		return error('cannot read ${path}: ${err.msg()}')
	}
	mut log := OcelLog{}
	for item in split_objects(array_field(content, 'events')) {
		log.events << parse_event(item)
	}
	for item in split_objects(array_field(content, 'objects')) {
		log.objects << parse_object(item)
	}
	if log.events.len == 0 {
		return error('no events found in OCEL log ${path}')
	}
	return log
}

fn json_escape(s string) string {
	mut b := strings.Builder{}
	for i, c in s {
		if c == 34 || c == 92 {
			b.write_string('\\')
			b.write_string(s[i..i + 1])
		} else {
			b.write_string(s[i..i + 1])
		}
	}
	return b.str()
}

pub fn write_ocel_json(path string, log OcelLog) ! {
	mut b := strings.Builder{}
	b.writeln('{')
	b.writeln('  "events": [')
	for i, event in log.events {
		comma := if i == log.events.len - 1 { '' } else { ',' }
		b.write_string('    {"id":"${json_escape(event.id)}","type":"${json_escape(event.activity)}","time":"${json_escape(event.time)}","relationships":[')
		for j, rel in event.relationships {
			sep := if j == event.relationships.len - 1 { '' } else { ',' }
			b.write_string('{"objectId":"${json_escape(rel.object_id)}","objectType":"${json_escape(rel.object_type)}","qualifier":"${json_escape(rel.qualifier)}"}${sep}')
		}
		b.writeln(']}${comma}')
	}
	b.writeln('  ],')
	b.writeln('  "objects": [')
	for i, object in log.objects {
		comma := if i == log.objects.len - 1 { '' } else { ',' }
		b.writeln('    {"id":"${json_escape(object.id)}","type":"${json_escape(object.type)}"}${comma}')
	}
	b.writeln('  ]')
	b.writeln('}')
	os.write_file(path, b.str())!
}

pub fn object_types(log OcelLog) []string {
	mut types := []string{}
	for event in log.events {
		for rel in event.relationships {
			if rel.object_type != '' && rel.object_type !in types {
				types << rel.object_type
			}
		}
	}
	types.sort()
	return types
}

fn event_key(e OcelEvent) i64 {
	if e.time == '' {
		return 0
	}
	ts := io.parse_timestamp(e.time) or { return 0 }
	return model.timestamp_key(ts.year, ts.month, ts.day, ts.hour, ts.minute, ts.second)
}

fn ordered_events(log OcelLog, object_id string) []OcelEvent {
	mut events := []OcelEvent{}
	for event in log.events {
		for rel in event.relationships {
			if rel.object_id == object_id {
				events << event
				break
			}
		}
	}
	events.sort_with_compare(fn (a &OcelEvent, b &OcelEvent) int {
		ka := event_key(a)
		kb := event_key(b)
		if ka < kb {
			return -1
		}
		if ka > kb {
			return 1
		}
		if a.id < b.id {
			return -1
		}
		return 0
	})
	return events
}

// flatten projects the object-centric log onto one object type.
pub fn flatten(log OcelLog, object_type string) !model.EventLog {
	mut result := model.EventLog{}
	mut objects := []string{}
	for object in log.objects {
		if object_type == '' || object.type == object_type {
			objects << object.id
		}
	}
	if objects.len == 0 {
		for event in log.events {
			for rel in event.relationships {
				if object_type == '' || rel.object_type == object_type {
					objects << rel.object_id
				}
			}
		}
	}
	mut seen := map[string]bool{}
	for object_id in objects {
		if seen[object_id] {
			continue
		}
		seen[object_id] = true
		for event in ordered_events(log, object_id) {
			result.add_event(model.Event{
				id:       event.id
				case_id:  object_id
				activity: event.activity
				sort_key: event_key(event)
			})
		}
	}
	if result.trace_count() == 0 {
		return error('no events found for object type "${object_type}"')
	}
	result.finish()
	return result
}

pub struct TypeRelation {
pub:
	first  string
	second string
	count  u32
}

pub fn object_type_graph(log OcelLog) []TypeRelation {
	mut counts := map[string]u32{}
	for event in log.events {
		mut types := []string{}
		for rel in event.relationships {
			if rel.object_type != '' && rel.object_type !in types {
				types << rel.object_type
			}
		}
		types.sort()
		for i := 0; i < types.len; i++ {
			for j := i + 1; j < types.len; j++ {
				counts[model.pair_key(types[i], types[j])]++
			}
		}
	}
	mut out := []TypeRelation{}
	for key, count in counts {
		first, second := model.split_pair(key)
		if first != '' || second != '' {
			out << TypeRelation{ first: first, second: second, count: count }
		}
	}
	out.sort_with_compare(fn (a &TypeRelation, b &TypeRelation) int {
		if a.count > b.count {
			return -1
		}
		if a.count < b.count {
			return 1
		}
		return 0
	})
	return out
}

pub fn ocdfg(log OcelLog, object_type string, min_count u32) model.Dfg {
	flat := flatten(log, object_type) or { return model.Dfg{} }
	mut counts := map[string]u32{}
	for _, trace in flat.traces {
		events := trace.raw_events()
		for i := 1; i < events.len; i++ {
			counts[model.pair_key(events[i - 1].activity, events[i].activity)]++
		}
	}
	mut edges := []model.DfgEdge{}
	for key, count in counts {
		if count < min_count {
			continue
		}
		from, to := model.split_pair(key)
		if from != '' || to != '' {
			edges << model.DfgEdge{ from: from, to: to, count: count }
		}
	}
	return model.Dfg{ activities: flat.activities.clone(), edges: edges }
}
