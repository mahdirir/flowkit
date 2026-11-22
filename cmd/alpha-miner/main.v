// alpha-miner discovers a Petri net from an activity log with the alpha
// algorithm. See the repository README for the full CLI reference.
module main

import os
import time
import alpha

enum Action {
	run
	help
	version
	usage_error
}

struct Options {
mut:
	input        string = 'dataset.csv'
	output       string
	format       string = 'text'
	delimiter    u8     = `;`
	case_col     int
	time_col     int  = 1
	event_col    int  = 2
	activity_col int  = 3
	header       bool = true
	summary_only bool
	quiet        bool
	verbose      bool
}

struct Outcome {
	action Action
	opts   Options
	msg    string
}

struct OptValue {
	value string
	next  int
	ok    bool
}

fn usage(opts Options, msg string) Outcome {
	return Outcome{ action: .usage_error, opts: opts, msg: msg }
}

fn value_for(args []string, i int, inline string) OptValue {
	if inline != '' {
		return OptValue{ value: inline, next: i + 1, ok: true }
	}
	if i + 1 < args.len {
		return OptValue{ value: args[i + 1], next: i + 2, ok: true }
	}
	return OptValue{ value: '', next: i + 1, ok: false }
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

fn delimiter(s string) ?u8 {
	if s == '\\t' || s == 'tab' {
		return 9
	}
	if s.len != 1 {
		return none
	}
	return s[0]
}

fn format_name(s string) ?string {
	match s.to_lower() {
		'text', 'txt' {
			return 'text'
		}
		'json' {
			return 'json'
		}
		'dot', 'gv', 'graphviz' {
			return 'dot'
		}
		else {
			return none
		}
	}
}

fn parse(args []string) Outcome {
	mut opts := Options{}
	mut input_set := false
	mut i := 1

	for i < args.len {
		arg := args[i]

		if arg == '--' {
			i++
			for i < args.len {
				if input_set {
					return usage(opts, 'unexpected argument: ${args[i]}')
				}
				opts.input = args[i]
				input_set = true
				i++
			}
			break
		}

		if arg == '-h' || arg == '--help' {
			return Outcome{ action: .help, opts: opts }
		}
		if arg == '-V' || arg == '--version' {
			return Outcome{ action: .version, opts: opts }
		}
		if arg == '-q' || arg == '--quiet' {
			opts.quiet = true
			i++
			continue
		}
		if arg == '-v' || arg == '--verbose' {
			opts.verbose = true
			i++
			continue
		}
		if arg == '--no-header' {
			opts.header = false
			i++
			continue
		}
		if arg == '--summary-only' {
			opts.summary_only = true
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
				v := value_for(args, i, inline)
				if !v.ok {
					return usage(opts, '${key} requires a value')
				}
				opts.input = v.value
				input_set = true
				i = v.next
			}
			'-o', '--output' {
				v := value_for(args, i, inline)
				if !v.ok {
					return usage(opts, '${key} requires a value')
				}
				opts.output = v.value
				i = v.next
			}
			'-f', '--format' {
				v := value_for(args, i, inline)
				if !v.ok {
					return usage(opts, '${key} requires a value')
				}
				name := format_name(v.value) or {
					return usage(opts, 'invalid format "${v.value}" (expected text, json or dot)')
				}
				opts.format = name
				i = v.next
			}
			'-d', '--delimiter' {
				v := value_for(args, i, inline)
				if !v.ok {
					return usage(opts, '${key} requires a value')
				}
				opts.delimiter = delimiter(v.value) or {
					return usage(opts, 'delimiter must be a single character (or "tab")')
				}
				i = v.next
			}
			'--case-col' {
				v := value_for(args, i, inline)
				if !v.ok {
					return usage(opts, '${key} requires a value')
				}
				opts.case_col = nonnegative(v.value) or {
					return usage(opts, '${key} expects a non-negative integer')
				}
				i = v.next
			}
			'--time-col' {
				v := value_for(args, i, inline)
				if !v.ok {
					return usage(opts, '${key} requires a value')
				}
				opts.time_col = nonnegative(v.value) or {
					return usage(opts, '${key} expects a non-negative integer')
				}
				i = v.next
			}
			'--event-col' {
				v := value_for(args, i, inline)
				if !v.ok {
					return usage(opts, '${key} requires a value')
				}
				opts.event_col = nonnegative(v.value) or {
					return usage(opts, '${key} expects a non-negative integer')
				}
				i = v.next
			}
			'--activity-col' {
				v := value_for(args, i, inline)
				if !v.ok {
					return usage(opts, '${key} requires a value')
				}
				opts.activity_col = nonnegative(v.value) or {
					return usage(opts, '${key} expects a non-negative integer')
				}
				i = v.next
			}
			else {
				if arg.starts_with('-') && arg.len > 1 {
					return usage(opts, 'unknown option: ${arg}')
				}
				if input_set {
					return usage(opts, 'unexpected argument: ${arg}')
				}
				opts.input = arg
				input_set = true
				i++
			}
		}
	}
	return Outcome{ action: .run, opts: opts }
}

fn help() {
	println('alpha-miner ${alpha.version} - process discovery from activity logs')
	println('')
	println('Usage:')
	println('  alpha-miner [OPTIONS] [INPUT]')
	println('')
	println('Options:')
	println('  -i, --input FILE       Activity log CSV (default: dataset.csv)')
	println('  -o, --output FILE      Write result to FILE (default: stdout)')
	println('  -f, --format FORMAT    Output format: text, json, dot (default: text)')
	println('  -d, --delimiter CHAR   CSV delimiter, or "tab" (default: ;)')
	println('      --case-col N       Case-id column, 0-based (default: 0)')
	println('      --time-col N       Timestamp column, 0-based (default: 1)')
	println('      --event-col N      Event-id column, 0-based (default: 2)')
	println('      --activity-col N   Activity column, 0-based (default: 3)')
	println('      --no-header        First row is data, not a header')
	println('      --summary-only     Text output: counts only, no places/arcs')
	println('  -q, --quiet            Suppress progress messages')
	println('  -v, --verbose          Print detailed progress')
	println('  -h, --help             Show this help')
	println('  -V, --version          Show version')
	println('')
	println('Timestamps: YYYY-MM-DD HH:mm:ss or DD-MM-YYYY HH:mm:ss')
	println('Exit codes: 0 success, 1 runtime error, 2 usage error')
}

fn fail(msg string) int {
	eprintln('alpha-miner: error: ${msg}')
	eprintln('Run "alpha-miner --help" for usage.')
	return 2
}

fn execute(o Options) int {
	sw := time.new_stopwatch()
	if !o.quiet {
		eprintln('alpha-miner: reading ${o.input}')
	}
	result := alpha.analyze(o.input, alpha.CsvOptions{
		delimiter:    o.delimiter
		case_col:     o.case_col
		time_col:     o.time_col
		event_col:    o.event_col
		activity_col: o.activity_col
		header:       o.header
	}) or {
		eprintln('alpha-miner: error: ${err.msg()}')
		return 1
	}
	if !o.quiet {
		eprintln('alpha-miner: ${result.eventlog.trace_count()} traces, ${result.eventlog.activity_count()} activities')
	}

	output := match o.format {
		'json' {
			alpha.render_json(result)
		}
		'dot' {
			alpha.render_dot(result)
		}
		else {
			alpha.render_text(result, alpha.TextOptions{ summary_only: o.summary_only })
		}
	}

	if o.output == '' {
		print(output)
	} else {
		os.write_file(o.output, output) or {
			eprintln('alpha-miner: error: cannot write ${o.output}: ${err.msg()}')
			return 1
		}
		if !o.quiet {
			eprintln('alpha-miner: wrote ${o.output}')
		}
	}
	if o.verbose {
		eprintln('alpha-miner: ${result.net.places.len} places, ${result.net.arcs.len} arcs')
	}
	if !o.quiet {
		eprintln('alpha-miner: finished in ${sw.elapsed().seconds()}s')
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
			println('alpha-miner ${alpha.version}')
			0
		}
		.usage_error {
			fail(outcome.msg)
		}
		.run {
			execute(outcome.opts)
		}
	}
	if code != 0 {
		exit(code)
	}
}
