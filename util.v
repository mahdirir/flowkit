module main

fn set_is_subset[T](a []T, b []T) bool {
	for item in a {
		if item !in b {
			return false
		}
	}
	return true
}

fn set_is_equal[T](a []T, b []T) bool {
	return a.len == b.len && set_is_subset(a, b)
}

fn json_escape(s string) string {
	mut out := ''
	for i, c in s {
		match c {
			34 {
				out += '\\"'
			}
			92 {
				out += '\\\\'
			}
			10 {
				out += '\\n'
			}
			13 {
				out += '\\r'
			}
			9 {
				out += '\\t'
			}
			else {
				out += s[i..i + 1]
			}
		}
	}
	return out
}

fn dot_escape(s string) string {
	mut out := ''
	for i, c in s {
		if c == 34 || c == 92 {
			out += '\\'
			out += s[i..i + 1]
		} else if c == 10 || c == 13 || c == 9 {
			out += ' '
		} else {
			out += s[i..i + 1]
		}
	}
	return out
}

fn json_array(items []string) string {
	mut parts := []string{}
	for item in items {
		parts << '"${json_escape(item)}"'
	}
	return '[${parts.join(', ')}]'
}
