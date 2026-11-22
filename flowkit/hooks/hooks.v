// Module hooks provides built-in pipeline hooks and external command hooks.
// External hooks exchange a small flat JSON object through a temporary file.
module hooks

import os
import time
import strings
import contracts
import flowkit.model

fn json_escape(s string) string {
	mut b := strings.Builder{}
	for i, c in s {
		if c == 34 || c == 92 {
			b.write_string('\\')
			b.write_string(s[i..i + 1])
		} else if c == 10 {
			b.write_string('\\n')
		} else if c == 13 {
			b.write_string('\\r')
		} else if c == 9 {
			b.write_string('\\t')
		} else {
			b.write_string(s[i..i + 1])
		}
	}
	return b.str()
}

fn field(text string, key string) string {
	needle := '"' + key + '"'
	at := text.index(needle) or { return '' }
	colon := text[at + needle.len..].index(':') or { return '' }
	mut start := at + needle.len + colon + 1
	for start < text.len && (text[start] == ` ` || text[start] == `\n`) {
		start++
	}
	if start >= text.len || text[start] != `"` {
		return ''
	}
	end := text[start + 1..].index('"') or { return '' }
	return unescape(text[start + 1..start + 1 + end])
}

fn unescape(s string) string {
	mut b := strings.Builder{}
	mut i := 0
	for i < s.len {
		if s[i] == 92 && i + 1 < s.len {
			next := s[i + 1]
			if next == `n` {
				b.write_string('\n')
				i += 2
				continue
			}
			if next == `r` {
				b.write_string('\r')
				i += 2
				continue
			}
			if next == `t` {
				b.write_string('\t')
				i += 2
				continue
			}
			if next == 92 {
				b.write_string('\\')
				i += 2
				continue
			}
			if next == 34 {
				b.write_string('"')
				i += 2
				continue
			}
			b.write_string(s[i..i + 2])
			i += 2
			continue
		}
		b.write_string(s[i..i + 1])
		i++
	}
	return b.str()
}

fn encode_context(ctx contracts.Context) string {
	mut b := strings.Builder{}
	b.write_string('{"path":"')
	b.write_string(json_escape(ctx.path))
	b.write_string('","output":"')
	b.write_string(json_escape(ctx.output))
	b.write_string('","rendered":"')
	b.write_string(json_escape(ctx.rendered))
	for key, value in ctx.metadata {
		b.write_string('","')
		b.write_string(json_escape(key))
		b.write_string('":"')
		b.write_string(json_escape(value))
	}
	b.write_string('"}')
	return b.str()
}

fn apply_context(mut ctx contracts.Context, text string) {
	p := field(text, 'path')
	if p != '' {
		ctx.path = p
	}
	output := field(text, 'output')
	if output != '' {
		ctx.output = output
	}
	rendered := field(text, 'rendered')
	if rendered != '' {
		ctx.rendered = rendered
	}
	for key, _ in ctx.metadata {
		updated := field(text, key)
		if updated != '' {
			ctx.metadata[key] = updated
		}
	}
}

pub fn normalize_activities() contracts.HookSpec {
	return contracts.HookSpec{
		name:  'normalize_activities'
		phase: .after_read
		run:   fn (mut ctx contracts.Context) ! {
			if !ctx.has_log {
				return
			}
			mut log := model.EventLog{}
			for _, trace in ctx.log.traces {
				for event in trace.event_list() {
					mut copy := event
					activity := event.activity.trim_space()
					if activity == event.activity {
						log.add_event(event)
					} else {
						copy = model.Event{
							id:       event.id
							case_id:  event.case_id
							activity: activity
							time:     event.time
							sort_key: event.sort_key
						}
						log.add_event(copy)
					}
				}
			}
			log.finish()
			ctx.log = log
		}
	}
}

pub fn annotate() contracts.HookSpec {
	return contracts.HookSpec{
		name:  'annotate'
		phase: .after_discover
		run:   fn (mut ctx contracts.Context) ! {
			if !ctx.has_log {
				return
			}
			ctx.metadata['places'] = ctx.net.places.len.str()
			ctx.metadata['arcs'] = ctx.net.arcs.len.str()
			ctx.metadata['activities'] = ctx.log.activity_count().str()
		}
	}
}

// command creates a hook that runs an external program with the context file
// path as its final argument. The program edits that file in place.
pub fn command(name string, phase contracts.Phase, command_line string) contracts.HookSpec {
	return contracts.HookSpec{
		name:    name
		phase:   phase
		command: command_line
		run:     fn [command_line, name] (mut ctx contracts.Context) ! {
			path := os.vtmp_dir() + '/flowkit_hook_' + time.ticks().str() + '.json'
			os.write_file(path, encode_context(ctx)) or {
				return error('cannot write hook context: ${err.msg()}')
			}
			defer {
				os.rm(path) or {}
			}
			mut args := command_line.split(' ')
			args << path
			result := os.execute(args.join(' '))
			if result.exit_code != 0 {
				return error('hook ${name} failed (${result.exit_code}): ${result.output}')
			}
			content := os.read_file(path) or {
				return error('cannot read hook result: ${err.msg()}')
			}
			apply_context(mut ctx, content)
		}
	}
}
