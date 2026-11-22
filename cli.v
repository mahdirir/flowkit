module main

enum CliAction {
	run
	help
	version
	usage_error
}

struct ParseOutcome {
	action CliAction
	config Config
	msg    string
}

struct OptValue {
	value string
	next  int
	ok    bool
}

fn usage(cfg Config, msg string) ParseOutcome {
	return ParseOutcome{ action: .usage_error, config: cfg, msg: msg }
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

fn parse_nonneg_int(s string) ?int {
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

fn normalize_format(s string) ?string {
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

fn parse_cli(args []string) ParseOutcome {
	mut cfg := Config{}
	mut input_set := false
	mut i := 1

	for i < args.len {
		a := args[i]

		if a == '--' {
			i++
			for i < args.len {
				if input_set {
					return usage(cfg, 'unexpected argument: ${args[i]}')
				}
				cfg.input = args[i]
				input_set = true
				i++
			}
			break
		}

		if a == '-h' || a == '--help' {
			return ParseOutcome{ action: .help, config: cfg }
		}
		if a == '-V' || a == '--version' {
			return ParseOutcome{ action: .version, config: cfg }
		}
		if a == '-q' || a == '--quiet' {
			cfg.quiet = true
			i++
			continue
		}
		if a == '-v' || a == '--verbose' {
			cfg.verbose = true
			i++
			continue
		}
		if a == '--no-header' {
			cfg.no_header = true
			i++
			continue
		}
		if a == '--summary-only' {
			cfg.summary_only = true
			i++
			continue
		}

		mut key := a
		mut inline := ''
		if a.starts_with('--') && a.contains('=') {
			parts := a.split('=')
			key = parts[0]
			if parts.len > 1 {
				inline = parts[1..].join('=')
			}
		}

		match key {
			'-i', '--input' {
				v := value_for(args, i, inline)
				if !v.ok {
					return usage(cfg, '${key} requires a value')
				}
				cfg.input = v.value
				input_set = true
				i = v.next
			}
			'-o', '--output' {
				v := value_for(args, i, inline)
				if !v.ok {
					return usage(cfg, '${key} requires a value')
				}
				cfg.output = v.value
				i = v.next
			}
			'-f', '--format' {
				v := value_for(args, i, inline)
				if !v.ok {
					return usage(cfg, '${key} requires a value')
				}
				fmt := normalize_format(v.value) or {
					return usage(cfg, 'invalid format "${v.value}" (expected text, json or dot)')
				}
				cfg.format = fmt
				i = v.next
			}
			'-d', '--delimiter' {
				v := value_for(args, i, inline)
				if !v.ok {
					return usage(cfg, '${key} requires a value')
				}
				delim := parse_delimiter(v.value) or {
					return usage(cfg, 'delimiter must be a single character (or "\\t")')
				}
				cfg.delimiter = delim
				i = v.next
			}
			'--case-col' {
				v := value_for(args, i, inline)
				if !v.ok {
					return usage(cfg, '${key} requires a value')
				}
				cfg.case_col = parse_nonneg_int(v.value) or {
					return usage(cfg, '${key} expects a non-negative integer')
				}
				i = v.next
			}
			'--time-col' {
				v := value_for(args, i, inline)
				if !v.ok {
					return usage(cfg, '${key} requires a value')
				}
				cfg.time_col = parse_nonneg_int(v.value) or {
					return usage(cfg, '${key} expects a non-negative integer')
				}
				i = v.next
			}
			'--event-col' {
				v := value_for(args, i, inline)
				if !v.ok {
					return usage(cfg, '${key} requires a value')
				}
				cfg.event_col = parse_nonneg_int(v.value) or {
					return usage(cfg, '${key} expects a non-negative integer')
				}
				i = v.next
			}
			'--activity-col' {
				v := value_for(args, i, inline)
				if !v.ok {
					return usage(cfg, '${key} requires a value')
				}
				cfg.activity_col = parse_nonneg_int(v.value) or {
					return usage(cfg, '${key} expects a non-negative integer')
				}
				i = v.next
			}
			else {
				if a.starts_with('-') && a.len > 1 {
					return usage(cfg, 'unknown option: ${a}')
				}
				if input_set {
					return usage(cfg, 'unexpected argument: ${a}')
				}
				cfg.input = a
				input_set = true
				i++
			}
		}
	}

	return ParseOutcome{ action: .run, config: cfg }
}

fn print_help() {
	println('alpha ${app_version} - process mining alpha algorithm')
	println('Discover a Petri net from an event log CSV.')
	println('')
	println('Usage:')
	println('  alpha [OPTIONS] [INPUT]')
	println('')
	println('Options:')
	println('  -i, --input FILE       Event log CSV (default: dataset.csv)')
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
	println('')
	println('Examples:')
	println('  alpha                                   # dataset.csv -> stdout')
	println('  alpha -i log.csv -f json -o net.json')
	println('  alpha -i log.csv -f dot -o net.dot')
	println('  alpha --delimiter , --activity-col 2 log.csv')
	println('')
	println('Exit codes: 0 success, 1 runtime error, 2 usage error')
}

fn fail(msg string) int {
	eprintln('alpha: error: ${msg}')
	eprintln('Run "alpha --help" for usage.')
	return 2
}

fn run_cli(args []string) int {
	outcome := parse_cli(args)
	match outcome.action {
		.help {
			print_help()
			return 0
		}
		.version {
			println('alpha ${app_version}')
			return 0
		}
		.usage_error {
			return fail(outcome.msg)
		}
		.run {
			return execute(outcome.config)
		}
	}
}
