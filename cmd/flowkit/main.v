// flowkit CLI: process discovery and activity log analysis.
module main

import os
import flowkit

enum Action {
	discover
	stats
	convert
	help
	version
	completions
	usage_error
}

struct Options {
mut:
	input        string = 'dataset.csv'
	output       string
	format       string = 'text'
	delimiter    u8     = `;`
	case_col     int
	time_col     int            = 1
	event_col    int            = 2
	activity_col int            = 3
	header       bool           = true
	method       flowkit.Method = .alpha
	min_count    u32            = 1
	max_variants int
	summary_only bool
	explain      bool
	dry_run      bool
	conformance  bool
	quiet        bool
	verbose      bool
}

struct Outcome {
	action Action
	opts   Options
	msg    string
	shell  string
}

fn usage(o Options, msg string) Outcome {
	return Outcome{ action: .usage_error, opts: o, msg: msg }
}

fn value_for(args []string, i int, inline string) (string, int, bool) {
	if inline != '' {
		return inline, i + 1, true
	}
	if i + 1 < args.len {
		return args[i + 1], i + 2, true
	}
	return '', i + 1, false
}

fn nonnegative(s string) ?int {
	if s.len == 0 {
		return none
	}
	for c in s {
		if c < 48 || c > 57 {
			return none
		}
	}
	return s.int()
}

fn parse_delimiter(s string) ?u8 {
	if s == '\\t' || s == 'tab' {
		return 9
	}
	if s.len != 1 {
		return none
	}
	return s[0]
}

fn parse_format(s string) ?string {
	match s.to_lower() {
		'text', 'txt' { return 'text' }
		'json' { return 'json' }
		'dot', 'gv', 'graphviz' { return 'dot' }
		'pnml' { return 'pnml' }
		'xes' { return 'xes' }
		else { return none }
	}
}

fn parse_method(s string) ?flowkit.Method {
	match s.to_lower() {
		'alpha', 'classic' { return .alpha }
		'alpha+', 'alpha_plus', 'aplus' { return .alpha_plus }
		else { return none }
	}
}

fn parse(args []string) Outcome {
	mut o := Options{}
	mut action := Action.discover
	mut i := 1

	if i < args.len {
		match args[i] {
			'help', '-h', '--help' { return Outcome{ action: .help } }
			'version', '-V', '--version' { return Outcome{ action: .version } }
			'discover' { i++ }
			'stats' {
				action = .stats
				i++
			}
			'convert' {
				action = .convert
				i++
			}
			'completions' {
				if i + 1 >= args.len {
					return usage(o, 'completions requires a shell (bash, zsh, powershell)')
				}
				return Outcome{ action: .completions, shell: args[i + 1] }
			}
			else {}
		}
	}

	for i < args.len {
		arg := args[i]
		if arg == '--' {
			i++
			if i < args.len {
				o.input = args[i]
				i++
			}
			break
		}
		if arg == '-q' || arg == '--quiet' {
			o.quiet = true
			i++
			continue
		}
		if arg == '-v' || arg == '--verbose' {
			o.verbose = true
			i++
			continue
		}
		if arg == '--no-header' {
			o.header = false
			i++
			continue
		}
		if arg == '--summary-only' {
			o.summary_only = true
			i++
			continue
		}
		if arg == '--explain' {
			o.explain = true
			i++
			continue
		}
		if arg == '--conformance' {
			o.conformance = true
			i++
			continue
		}
		if arg == '--dry-run' {
			o.dry_run = true
			i++
			continue
		}
		if arg == '--no-color' {
			i++
			continue
		}

		mut key := arg
		mut inline := ''
		if arg.starts_with('--') && arg.contains('=') {
			parts := arg.split('=')
			key = parts[0]
			if parts.len > 1 {
				inline = parts[1..].join('=')
			}
		}
		match key {
			'-i', '--input' {
				v, next, ok := value_for(args, i, inline)
				if !ok { return usage(o, '${key} requires a value') }
				o.input = v
				i = next
			}
			'-o', '--output' {
				v, next, ok := value_for(args, i, inline)
				if !ok { return usage(o, '${key} requires a value') }
				o.output = v
				i = next
			}
			'-f', '--format' {
				v, next, ok := value_for(args, i, inline)
				if !ok { return usage(o, '${key} requires a value') }
				o.format = parse_format(v) or { return usage(o, 'invalid format "${v}" (text, json, dot, pnml, xes)') }
				i = next
			}
			'-d', '--delimiter' {
				v, next, ok := value_for(args, i, inline)
				if !ok { return usage(o, '${key} requires a value') }
				o.delimiter = parse_delimiter(v) or { return usage(o, 'delimiter must be one character or "tab"') }
				i = next
			}
			'--case-col' {
				v, next, ok := value_for(args, i, inline)
				if !ok { return usage(o, '${key} requires a value') }
				o.case_col = nonnegative(v) or { return usage(o, '${key} expects a non-negative integer') }
				i = next
			}
			'--time-col' {
				v, next, ok := value_for(args, i, inline)
				if !ok { return usage(o, '${key} requires a value') }
				o.time_col = nonnegative(v) or { return usage(o, '${key} expects a non-negative integer') }
				i = next
			}
			'--event-col' {
				v, next, ok := value_for(args, i, inline)
				if !ok { return usage(o, '${key} requires a value') }
				o.event_col = nonnegative(v) or { return usage(o, '${key} expects a non-negative integer') }
				i = next
			}
			'--activity-col' {
				v, next, ok := value_for(args, i, inline)
				if !ok { return usage(o, '${key} requires a value') }
				o.activity_col = nonnegative(v) or { return usage(o, '${key} expects a non-negative integer') }
				i = next
			}
			'--method' {
				v, next, ok := value_for(args, i, inline)
				if !ok { return usage(o, '${key} requires a value') }
				o.method = parse_method(v) or { return usage(o, 'invalid method "${v}" (alpha, alpha+)') }
				i = next
			}
			'--min-count' {
				v, next, ok := value_for(args, i, inline)
				if !ok { return usage(o, '${key} requires a value') }
				n := nonnegative(v) or { return usage(o, '${key} expects a non-negative integer') }
				o.min_count = u32(n)
				i = next
			}
			'--max-variants' {
				v, next, ok := value_for(args, i, inline)
				if !ok { return usage(o, '${key} requires a value') }
				o.max_variants = nonnegative(v) or { return usage(o, '${key} expects a non-negative integer') }
				i = next
			}
			else {
				if arg.starts_with('-') && arg.len > 1 {
					return usage(o, 'unknown option: ${arg}')
				}
				o.input = arg
				i++
			}
		}
	}
	return Outcome{ action: action, opts: o }
}

fn help() {
	println('flowkit ${flowkit.version} - activity log processing and process discovery')
	println('')
	println('Usage:')
	println('  flowkit [discover|stats|convert] [OPTIONS] [INPUT]')
	println('  flowkit completions <bash|zsh|powershell>')
	println('')
	println('Commands:')
	println('  discover   Discover a Petri net (default)')
	println('  stats      Print log statistics only')
	println('  convert    Convert a log to another format')
	println('')
	println('Options:')
	println('  -i, --input FILE       Log file: .csv or .xes (default: dataset.csv)')
	println('  -o, --output FILE      Write to file (default: stdout)')
	println('  -f, --format FORMAT    text, json, dot, pnml, xes (default: text)')
	println('  -d, --delimiter CHAR   CSV delimiter, or "tab" (default: ;)')
	println('      --case-col N       Case-id column, 0-based (default: 0)')
	println('      --time-col N       Timestamp column, 0-based (default: 1)')
	println('      --event-col N      Event-id column, 0-based (default: 2)')
	println('      --activity-col N   Activity column, 0-based (default: 3)')
	println('      --no-header        First row is data, not a header')
	println('      --method NAME      alpha or alpha+ (default: alpha)')
	println('      --min-count N      Minimum DFG edge frequency (default: 1)')
	println('      --max-variants N   Keep the N most frequent variants')
	println('      --summary-only     Counts and quality only')
	println('      --explain          Explain each step in the output')
	println('      --conformance      Print replay, alignment, precision and generalization')
	println('      --dry-run          Validate input without writing output')
	println('  -q, --quiet            Suppress progress messages')
	println('  -v, --verbose          Print extra detail')
	println('  -h, --help             Show help')
	println('  -V, --version          Show version')
	println('')
	println('Exit codes: 0 success, 1 runtime error, 2 usage error')
}

fn fail(msg string) int {
	eprintln('flowkit: error: ${msg}')
	eprintln('Run "flowkit help" for usage.')
	return 2
}

fn completions(shell string) int {
	match shell {
		'bash' {
			println('complete -F _flowkit flowkit')
			println('_flowkit() { COMPREPLY=( $(compgen -W "discover stats convert completions --input --output --format --method --quiet --verbose --help" -- "' + '$' + '{COMP_WORDS[COMP_CWORD]}") ); }')
		}
		'zsh' {
			println('#compdef flowkit')
			println('compdef _flowkit flowkit')
		}
		'powershell' {
			println('Register-ArgumentCompleter -Native -CommandName flowkit -ScriptBlock {')
			println('  param($wordToComplete)')
			println('  @("discover","stats","convert","--input","--output","--format","--method") | Where-Object { $_ -like "$wordToComplete*" }')
			println('}')
		}
		else {
			return fail('unsupported shell "${shell}"')
		}
	}
	return 0
}

fn execute(action Action, o Options) int {
	mut filters := []flowkit.Filter{}
	if o.max_variants > 0 {
		filters << flowkit.Filter{ max_variants: o.max_variants }
	}
	result := flowkit.discover(o.input, flowkit.Options{
		method:    o.method
		min_count: o.min_count
		filters:   filters
		delimiter: o.delimiter
		header:    o.header
	}) or {
		eprintln('flowkit: error: ${err.msg()}')
		return 1
	}

	if !o.quiet {
		eprintln('flowkit: ${result.stats.traces} traces, ${result.stats.activities} activities, ${result.stats.events} events')
	}
	if o.verbose {
		eprintln('flowkit: ${result.net.places.len} places, ${result.net.arcs.len} arcs, ${result.stats.variants} variants')
	}
	if o.dry_run {
		eprintln('flowkit: dry run - input is valid; no output written')
		return 0
	}

	mut output := ''
	if action == .convert && o.format == 'text' && o.output.ends_with('.xes') {
		flowkit.write_xes(o.output, result.log) or {
			eprintln('flowkit: error: ${err.msg()}')
			return 1
		}
		return 0
	}
	output = match o.format {
		'json' { flowkit.render_json(result) }
		'dot' { flowkit.render_dot(result) }
		'pnml' { flowkit.render_pnml(result) }
		'xes' {
			if o.output == '' {
				return fail('format xes requires --output')
			}
			flowkit.write_xes(o.output, result.log) or {
				eprintln('flowkit: error: ${err.msg()}')
				return 1
			}
			return 0
		}
		else {
			flowkit.render_text(result, flowkit.TextOptions{
				summary_only: o.summary_only || action == .stats
				explain:      o.explain
			})
		}
	}
	if o.conformance && (o.format == 'text' || o.format == 'txt') {
		replay_result := flowkit.replay(result.log, result.net)
		alignment := flowkit.alignment_fitness(result.log, result.net, 200, 8)
		precision := flowkit.precision(result.log, result.net, 1)
		generalized := flowkit.generalization(result.log, result.net)
		output += '\nConformance:\n'
		output += '  Replay fitness:    ${replay_result.fitness:.3}\n'
		output += '  Alignment fitness: ${alignment:.3}\n'
		output += '  Precision:         ${precision:.3}\n'
		output += '  Generalization:    ${generalized:.3}\n'
		output += '  Missing tokens:    ${replay_result.missing_tokens}\n'
		output += '  Remaining tokens:  ${replay_result.remaining_tokens}\n'
	}
	if o.output == '' {
		print(output)
	} else {
		flowkit.write_file(o.output, output) or {
			eprintln('flowkit: error: cannot write ${o.output}: ${err.msg()}')
			return 1
		}
		if !o.quiet {
			eprintln('flowkit: wrote ${o.output}')
		}
	}
	return 0
}

fn main() {
	outcome := parse(os.args)
	code := match outcome.action {
		.help {
			help()
			0
		}
		.version {
			println('flowkit ${flowkit.version}')
			0
		}
		.completions { completions(outcome.shell) }
		.usage_error { fail(outcome.msg) }
		else { execute(outcome.action, outcome.opts) }
	}
	if code != 0 {
		exit(code)
	}
}
