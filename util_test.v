module main

fn test_set_helpers() {
	assert set_is_subset([1, 2], [1, 2, 3])
	assert !set_is_subset([1, 4], [1, 2, 3])
	assert set_is_equal(['a', 'b'], ['b', 'a'])
	assert !set_is_equal(['a'], ['a', 'b'])
}

fn test_json_escape() {
	assert json_escape('plain') == 'plain'
	assert json_escape('a"b\\c') == 'a\\"b\\\\c'
	assert json_escape('line\nbreak') == 'line\\nbreak'
	assert json_escape('tab\there') == 'tab\\there'
}

fn test_dot_escape() {
	assert dot_escape('a"b') == 'a\\"b'
	assert dot_escape('a\\b') == 'a\\\\b'
	assert dot_escape('a\nb') == 'a b'
}

fn test_timestamp_formats() {
	iso := parse_timestamp('2024-01-02 03:04:05')!
	assert iso.year == 2024 && iso.month == 1 && iso.day == 2
	assert iso.hour == 3 && iso.minute == 4 && iso.second == 5

	dmy := parse_timestamp('02-01-2024 03:04:05')!
	assert dmy.year == 2024 && dmy.month == 1 && dmy.day == 2

	assert time_key(2024, 1, 2, 3, 4, 5) < time_key(2024, 1, 2, 3, 4, 6)
	assert time_key(2024, 1, 2, 3, 4, 5) < time_key(2024, 1, 3, 0, 0, 0)
}
