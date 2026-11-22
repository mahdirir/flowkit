module main

struct Place {
	inputs  []string
	outputs []string
}

fn (p Place) key() string {
	return '${p.inputs.join('|')}=>${p.outputs.join('|')}'
}

fn (p Place) is_valid(f Footprint) bool {
	if p.inputs.len == 0 || p.outputs.len == 0 {
		return false
	}
	for a in p.inputs {
		for b in p.inputs {
			if a != b && f.of(a, b) != .conflict {
				return false
			}
		}
	}
	for a in p.outputs {
		for b in p.outputs {
			if a != b && f.of(a, b) != .conflict {
				return false
			}
		}
	}
	for a in p.inputs {
		for b in p.outputs {
			if f.of(a, b) != .causality {
				return false
			}
		}
	}
	return true
}
