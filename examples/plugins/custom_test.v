module plugins

import flowkit

fn test_example_plugin_registers() {
	mut reg := flowkit.new_registry()!
	register(mut reg)!
	info := flowkit.describe_registry(reg)
	assert info.contains('pipe')
	assert info.contains('simple_alpha')
	assert reg.reader_for('cases.log') != none
	assert reg.algorithm('simple_alpha') != none
}
