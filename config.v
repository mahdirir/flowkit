module main

struct Config {
mut:
	input        string = 'dataset.csv'
	output       string
	format       string = 'text'
	delimiter    u8     = `;`
	case_col     int
	time_col     int    = 1
	event_col    int    = 2
	activity_col int    = 3
	no_header    bool
	quiet        bool
	verbose      bool
	summary_only bool
}
