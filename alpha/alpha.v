// Module alpha implements process discovery from activity logs.
//
// It reads an event log, computes a footprint relation between activities,
// and discovers a Petri net with the alpha algorithm. The CLI lives in
// cmd/alpha-miner; this package can be imported by any V program:
//
//	import alpha
//
//	log := alpha.read_eventlog_csv('log.csv', alpha.CsvOptions{})!
//	net := alpha.discover_net(log, alpha.build_footprint(log))
//	println(alpha.render_dot(alpha.Analysis{ eventlog: log, net: net }))
module alpha

pub const version = '1.0.0'

// CsvOptions describes the layout of a delimited activity log.
pub struct CsvOptions {
pub:
	delimiter    u8 = `;`
	case_col     int
	time_col     int  = 1
	event_col    int  = 2
	activity_col int  = 3
	header       bool = true
}

// Analysis holds the event log, footprint and net produced by a discovery run.
pub struct Analysis {
pub:
	eventlog  EventLog
	footprint Footprint
	net       PetriNet
}

// analyze is the complete discover pipeline: read a log, build its footprint
// and discover the Petri net in one call.
pub fn analyze(path string, opts CsvOptions) !Analysis {
	log := read_eventlog_csv(path, opts)!
	footprint := build_footprint(log)
	net := discover_net(log, footprint)
	return Analysis{
		eventlog:  log
		footprint: footprint
		net:       net
	}
}
