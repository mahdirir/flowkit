// Module contracts defines the extension points of flowkit.
//
// All extensions are plain function records: a reader turns a path into an
// event log, a writer serialises a result, an algorithm discovers a net, and
// hooks observe or modify the pipeline context at a specific phase.
module contracts

import flowkit.model
import flowkit.discovery
import flowkit.analysis
import flowkit.evaluation
import flowkit.conformance

pub const version = '1.1.0'

pub enum Phase {
	before_read
	after_read
	before_discover
	after_discover
	before_write
	after_write
}

pub fn (p Phase) str() string {
	return match p {
		.before_read { 'before_read' }
		.after_read { 'after_read' }
		.before_discover { 'before_discover' }
		.after_discover { 'after_discover' }
		.before_write { 'before_write' }
		.after_write { 'after_write' }
	}
}

pub fn parse_phase(s string) ?Phase {
	match s {
		'before_read' { return .before_read }
		'after_read' { return .after_read }
		'before_discover' { return .before_discover }
		'after_discover' { return .after_discover }
		'before_write' { return .before_write }
		'after_write' { return .after_write }
		else { return none }
	}
}

// Options is the shared configuration passed to every extension.
pub struct Options {
pub mut:
	method    discovery.Method = .alpha
	min_count u32              = 1
	filters   []analysis.Filter
	delimiter u8   = `;`
	header    bool = true
	algorithm string
	metadata  map[string]string
}

// Result is the complete output of a discovery run.
pub struct Result {
pub:
	log       model.EventLog
	footprint model.Footprint
	net       model.PetriNet
	stats     model.Stats
	quality   evaluation.Quality
	report    conformance.Report
	dfg       model.Dfg
}

// Context is passed through the pipeline and shared with hooks.
pub struct Context {
pub mut:
	path       string
	options    Options
	log        model.EventLog
	has_log    bool
	footprint  model.Footprint
	net        model.PetriNet
	result     Result
	has_result bool
	output     string
	rendered   string
	metadata   map[string]string
}

pub struct ReaderSpec {
pub:
	name       string
	extensions []string
	read       fn (path string, opts Options) !model.EventLog
}

pub struct ParserSpec {
pub:
	name       string
	extensions []string
	parse      fn (content string, opts Options) !model.EventLog
}

pub struct WriterSpec {
pub:
	name       string
	extensions []string
	write      fn (path string, result Result) !
}

pub struct RendererSpec {
pub:
	name   string
	render fn (result Result, opts Options) string
}

pub struct AlgorithmSpec {
pub:
	name     string
	discover fn (log model.EventLog, fp model.Footprint, opts Options) !model.PetriNet
}

pub struct HookSpec {
pub:
	name    string
	phase   Phase
	run     fn (mut ctx Context) !
	command string
}
