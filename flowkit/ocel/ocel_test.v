module ocel

fn test_read_and_flatten() {
	log := read_ocel_json('examples/example.jsonocel')!
	assert log.events.len == 4
	assert log.objects.len == 3
	types := object_types(log)
	assert types == ['Order', 'Product']
	flat := flatten(log, 'Order')!
	assert flat.trace_count() == 2
	assert flat.event_count() == 4
	assert flat.activity_count() == 2
	first := flat.trace('o1') or { panic('missing object') }
	assert first.event_list()[0].activity == 'Create Order'
	assert first.event_list()[1].activity == 'Pay'
}

fn test_object_type_graph() {
	log := read_ocel_json('examples/example.jsonocel')!
	graph := object_type_graph(log)
	assert graph.len == 1
	assert graph[0].first == 'Order'
	assert graph[0].second == 'Product'
}

fn test_ocdfg() {
	log := read_ocel_json('examples/example.jsonocel')!
	dfg := ocdfg(log, 'Order', 1)
	assert dfg.edges.len == 1
	assert dfg.edges[0].from == 'Create Order'
	assert dfg.edges[0].to == 'Pay'
	assert dfg.edges[0].count == 2
}
