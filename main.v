module main

import os

const app_version = '1.0.0'

fn main() {
	code := run_cli(os.args)
	if code != 0 {
		exit(code)
	}
}
