// Module registry stores and resolves flowkit extensions.
module registry

import os
import strings
import contracts

pub struct Registry {
mut:
	readers    []contracts.ReaderSpec
	parsers    []contracts.ParserSpec
	writers    []contracts.WriterSpec
	renderers  []contracts.RendererSpec
	algorithms []contracts.AlgorithmSpec
	hooks      []contracts.HookSpec
}

pub fn new() Registry {
	return Registry{}
}

fn taken(names []string, name string) bool {
	return name in names
}

fn unique(items []string) []string {
	mut seen := map[string]bool{}
	mut out := []string{}
	for item in items {
		if !seen[item] {
			seen[item] = true
			out << item
		}
	}
	return out
}

fn reader_names_of(items []contracts.ReaderSpec) []string {
	mut out := []string{}
	for item in items {
		out << item.name
	}
	return out
}

fn parser_names_of(items []contracts.ParserSpec) []string {
	mut out := []string{}
	for item in items {
		out << item.name
	}
	return out
}

fn writer_names_of(items []contracts.WriterSpec) []string {
	mut out := []string{}
	for item in items {
		out << item.name
	}
	return out
}

fn renderer_names_of(items []contracts.RendererSpec) []string {
	mut out := []string{}
	for item in items {
		out << item.name
	}
	return out
}

fn algorithm_names_of(items []contracts.AlgorithmSpec) []string {
	mut out := []string{}
	for item in items {
		out << item.name
	}
	return out
}

pub fn (mut r Registry) add_reader(spec contracts.ReaderSpec) ! {
	if taken(reader_names_of(r.readers), spec.name) {
		return error('reader "${spec.name}" is already registered')
	}
	r.readers << spec
}

pub fn (mut r Registry) add_parser(spec contracts.ParserSpec) ! {
	if taken(parser_names_of(r.parsers), spec.name) {
		return error('parser "${spec.name}" is already registered')
	}
	r.parsers << spec
}

pub fn (mut r Registry) add_writer(spec contracts.WriterSpec) ! {
	if taken(writer_names_of(r.writers), spec.name) {
		return error('writer "${spec.name}" is already registered')
	}
	r.writers << spec
}

pub fn (mut r Registry) add_renderer(spec contracts.RendererSpec) ! {
	if taken(renderer_names_of(r.renderers), spec.name) {
		return error('renderer "${spec.name}" is already registered')
	}
	r.renderers << spec
}

pub fn (mut r Registry) add_algorithm(spec contracts.AlgorithmSpec) ! {
	if taken(algorithm_names_of(r.algorithms), spec.name) {
		return error('algorithm "${spec.name}" is already registered')
	}
	r.algorithms << spec
}

pub fn (mut r Registry) add_hook(spec contracts.HookSpec) ! {
	mut names := []string{}
	for hook in r.hooks {
		names << '${hook.phase.str()}:${hook.name}'
	}
	if taken(names, '${spec.phase.str()}:${spec.name}') {
		return error('hook "${spec.name}" (${spec.phase.str()}) is already registered')
	}
	r.hooks << spec
}

fn ext_of(path string) string {
	ext := os.file_ext(path)
	return ext.trim_left('.').to_lower()
}

pub fn (r Registry) reader_for(path string) ?contracts.ReaderSpec {
	ext := ext_of(path)
	for spec in r.readers {
		for candidate in spec.extensions {
			if candidate.to_lower() == ext {
				return spec
			}
		}
	}
	return none
}

pub fn (r Registry) parser(name string) ?contracts.ParserSpec {
	for spec in r.parsers {
		if spec.name == name {
			return spec
		}
	}
	return none
}

pub fn (r Registry) writer(name string) ?contracts.WriterSpec {
	for spec in r.writers {
		if spec.name == name {
			return spec
		}
	}
	return none
}

pub fn (r Registry) writer_for(path string) ?contracts.WriterSpec {
	ext := ext_of(path)
	for spec in r.writers {
		for candidate in spec.extensions {
			if candidate.to_lower() == ext {
				return spec
			}
		}
	}
	return none
}

pub fn (r Registry) renderer(name string) ?contracts.RendererSpec {
	for spec in r.renderers {
		if spec.name == name {
			return spec
		}
	}
	return none
}

pub fn (r Registry) algorithm(name string) ?contracts.AlgorithmSpec {
	for spec in r.algorithms {
		if spec.name == name {
			return spec
		}
	}
	return none
}

pub fn (r Registry) hooks_for(phase contracts.Phase) []contracts.HookSpec {
	mut out := []contracts.HookSpec{}
	for hook in r.hooks {
		if hook.phase == phase {
			out << hook
		}
	}
	return out
}

pub fn (r Registry) format_names() []string {
	mut out := writer_names_of(r.writers)
	out << renderer_names_of(r.renderers)
	out = unique(out)
	out.sort()
	return out
}

pub fn (r Registry) reader_names() []string {
	mut out := reader_names_of(r.readers)
	out << parser_names_of(r.parsers)
	out = unique(out)
	out.sort()
	return out
}

pub fn (r Registry) algorithm_names() []string {
	mut out := algorithm_names_of(r.algorithms)
	out = unique(out)
	out.sort()
	return out
}

pub fn (r Registry) hook_count() int {
	return r.hooks.len
}

pub fn describe(r Registry) string {
	mut b := strings.Builder{}
	b.writeln('readers:    ${r.reader_names().join(', ')}')
	b.writeln('writers:    ${r.format_names().join(', ')}')
	b.writeln('algorithms: ${r.algorithm_names().join(', ')}')
	b.writeln('hooks:      ${r.hook_count()}')
	return b.str()
}
