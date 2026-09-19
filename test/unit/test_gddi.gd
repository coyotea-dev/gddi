extends GutTest

func before_all():
	var node: Node = Node.new()
	node.name = 'Nested'
	GDDI.add_child(node)
	# GDDI.set_log_level(GDDI.LogLevel.NONE)

func after_each():
	GDDI.clear()
	await wait_idle_frames(1)
	for key in [&'inc', &'factory_calls', &'factory_invoked']:
		if GDDI.has_meta(key):
			GDDI.remove_meta(key)

func test_my_gddi_init_registers_its_dependency():
	var initializer_paths: PackedStringArray = ProjectSettings.get_setting(GDDI._INITIALIZERS_SETTING, PackedStringArray())
	assert_true(initializer_paths.has('res://test/scripts/my_gddi_init.gd'))
	assert_true(GDDI.has(&'initializer_test_value'))
	assert_eq(GDDI.inject(&'initializer_test_value'), 'initialized')

func test_provide_node():
	var node: Node = Node.new()

	assert_true(GDDI.provide_node(&'node', node, {
		'name': 'MyNode',
		'parent': null
	}), 'Failed to register node.')

	assert_true(GDDI.has(&'node'))
	assert_same(node.get_parent(), GDDI)
	assert_eq(node.name, 'MyNode')

	assert_same(GDDI.inject(&'node'), node)

	assert_true(GDDI.remove(&'node'))
	assert_false(GDDI.remove(&'node'))

	await wait_idle_frames(1)

	assert_freed(node)
	assert_false(GDDI.has(&'node'))

	node = Node.new()
	assert_true(GDDI.provide_node(&'node', node, {
		'parent': GDDI.get_child(0)
	}), 'Failed to register node.')

	assert_same(node.get_parent(), GDDI.get_child(0))
	assert_eq(node.name, node.get_class())

	var custom: MyNode = MyNode.new()

	assert_true(GDDI.provide_node(&'custom', custom))
	assert_same(custom.get_parent(), GDDI)
	assert_eq(custom.name, custom.get_script().get_global_name())

	var other: Node = Node.new()
	other.name = 'OtherNode'
	GDDI.get_child(0).add_child(other)

	assert_true(GDDI.provide_node(&'other', other))
	assert_same(other.get_parent(), GDDI.get_child(0))
	assert_eq(other.name, 'OtherNode')

	assert_eq(GDDI.get_provider_list(), PackedStringArray(['node', 'custom', 'other']))
	GDDI.clear()
	await wait_idle_frames(1)
	assert_freed(node)
	assert_freed(custom)
	assert_freed(other)

	assert_false(GDDI.remove(&'node'))

func test_provide_ref():
	var ref: MyRef = MyRef.new()
	ref.secret = 'dog food'
	assert_eq(ref.get_reference_count(), 1)
	assert_true(GDDI.provide_ref(&'custom', ref))
	assert_same(GDDI.inject(&'custom'), ref)
	assert_eq(GDDI.inject(&'custom').secret, 'dog food')
	assert_eq(ref.get_reference_count(), 2)
	assert_true(GDDI.remove(&'custom'))
	assert_eq(ref.get_reference_count(), 1)

func test_provide_factory():
	assert_true(GDDI.provide_factory(&'factory', func():
		var inc: int = GDDI.get_meta(&'inc', 0)
		GDDI.set_meta(&'inc', inc + 1)
		return MyRef.new()
	))

	var ref: Variant = GDDI.inject(&'factory')
	assert_is(ref, MyRef)
	assert_eq(GDDI.get_meta(&'inc'), 1)
	assert_not_same(GDDI.inject(&'factory'), ref)
	assert_eq(GDDI.get_meta(&'inc'), 2)
	GDDI.remove_meta(&'inc')

	assert_true(GDDI.provide_factory(&'secret_keeper', func(secret: String):
		var custom := MyRef.new()
		custom.secret = secret
		return custom
	))

	var custom_ref: MyRef = GDDI.inject(&'secret_keeper', 'lambda')
	assert_eq(custom_ref.secret, 'lambda')
	custom_ref = GDDI.injectv(&'secret_keeper', ['doggo'])
	assert_eq(custom_ref.secret, 'doggo')

	assert_true(GDDI.provide_factory(&'none', func():
		pass
	))

	assert_null(GDDI.inject(&'none'))

	assert_true(GDDI.provide_factory(&'node', func():
		return Node.new()
	))

	var node: Node = GDDI.inject(&'node')
	assert_null(node.get_parent())
	assert_eq(node.name, '')
	node.queue_free()

func test_provide_lazy():
	assert_true(GDDI.provide_lazy(&'lazy', func(secret: String):
		var custom := MyRef.new()
		custom.secret = secret
		return custom
	))
	@warning_ignore("static_called_on_instance")
	assert_is(Engine.get_singleton(GDDI._annotate_key(&'lazy')), GDDI._Factory)

	var ref: MyRef = GDDI.inject(&'lazy', '#1')
	assert_eq(ref.secret, '#1')
	@warning_ignore("static_called_on_instance")
	assert_is(Engine.get_singleton(GDDI._annotate_key(&'lazy')), GDDI._SolidRef)
	var other: MyRef = GDDI.inject(&'lazy', '#2')
	assert_true(other.secret != '#2')
	assert_same(ref, other)

	assert_true(GDDI.provide_lazy(&'node', func():
		return Node.new()
	))

	var node: Node = GDDI.inject(&'node')
	assert_eq(node.name, 'Node')
	assert_same(node.get_parent(), GDDI)
	assert_same(node, GDDI.inject(&'node'))

	assert_true(GDDI.provide_lazy(&'custom_node', func():
		return MyNode.new()
	))
	assert_eq(GDDI.inject(&'custom_node').name, 'MyNode')

	var non_orphan: Node = Node.new()
	non_orphan.name = 'NonOrphan'
	get_tree().current_scene.add_child(non_orphan)

	assert_true(GDDI.provide_lazy(&'non_orphan', func(node_arg: Node):
		node_arg.set_meta(&'being_lazy', true)
		return node_arg
	))

	var same_orphan: Node = GDDI.inject(&'non_orphan', non_orphan)
	assert_same(non_orphan, same_orphan)
	assert_eq(same_orphan.name, 'NonOrphan')
	assert_same(same_orphan.get_parent(), get_tree().current_scene)
	assert_true(same_orphan.get_meta(&'being_lazy'))
	same_orphan.set_meta(&'being_lazy', false)
	same_orphan = GDDI.inject(&'non_orphan', same_orphan)
	assert_false(same_orphan.get_meta(&'being_lazy'))
	assert_not_same(GDDI.inject(&'non_orphan', node), node)
	assert_same(GDDI.inject(&'non_orphan', node), non_orphan)

func test_provide():
	assert_true(GDDI.provide(&'obj', Node.new()))
	var node: Node = GDDI.inject(&'obj')
	assert_eq(node.get_parent(), null)
	assert_true(GDDI.remove(&'obj'))
	await wait_idle_frames(1)
	assert_freed(node)

func test_remove():
	var node1 := Node.new()
	var node2 := Node.new()
	var ref1 := GDDI._SolidRef.new(MyRef.new())
	assert_true(GDDI.provide(&'obj1', node1))
	assert_true(GDDI.provide(&'obj2', node2))
	assert_true(GDDI.provide(&'ref1', ref1))

	assert_true(GDDI.remove(&'obj1'))
	assert_true(GDDI.remove(&'obj2'))
	assert_true(GDDI.remove(&'ref1'))
	assert_false(GDDI.remove(&'obj1'))
	assert_freed(ref1)

	await wait_idle_frames(1)

	assert_freed(node1)
	assert_freed(node2)

	var non_freed := Node.new()
	assert_true(GDDI.provide(&'non_freed', non_freed))
	assert_true(GDDI.remove(&'non_freed', false))

	await wait_idle_frames(1)

	assert_not_freed(non_freed)
	non_freed.queue_free()

	assert_eq(GDDI.get_provider_list(), PackedStringArray([]))

	node1 = Node.new()
	node2 = Node.new()
	assert_true(GDDI.provide(&'obj1', node1))
	assert_true(GDDI.provide(&'obj2', node2))

	GDDI.clear()
	await wait_idle_frames(1)

	assert_freed(node1)
	assert_freed(node2)

func test_missing_and_empty_keys():
	assert_false(GDDI.has(&'missing'))
	assert_null(GDDI.inject(&'missing'))
	assert_null(GDDI.injectv(&'missing'))
	assert_eq(GDDI.get_provider_list(), PackedStringArray())

	var rejected_object := Node.new()
	assert_false(GDDI.provide(&'', rejected_object))
	assert_false(GDDI.provide_factory(&'', func(): return Node.new()))
	assert_false(GDDI.provide_lazy(&'', func(): return Node.new()))
	var rejected_node := Node.new()
	assert_false(GDDI.provide_node(&'', rejected_node))
	assert_false(GDDI.provide_ref(&'', MyRef.new()))
	assert_false(GDDI.remove(&''))
	assert_eq(GDDI.get_provider_list(), PackedStringArray())
	rejected_object.free()
	rejected_node.free()

func test_duplicate_registration_does_not_replace_provider():
	var original := Node.new()
	var rejected := Node.new()
	assert_true(GDDI.provide(&'duplicate', original))
	assert_false(GDDI.provide(&'duplicate', rejected))
	assert_false(GDDI.provide_factory(&'duplicate', func(): return Node.new()))
	assert_false(GDDI.provide_lazy(&'duplicate', func(): return Node.new()))
	assert_false(GDDI.provide_node(&'duplicate', rejected))
	assert_same(GDDI.inject(&'duplicate'), original)
	assert_null(rejected.get_parent())
	assert_eq(rejected.name, '')
	assert_true(GDDI.remove(&'duplicate'))
	original.free()
	rejected.free()

func test_key_annotation_and_engine_singleton_isolation():
	@warning_ignore("static_called_on_instance")
	assert_eq(GDDI._annotate_key(&'service'), &'GDDI_service')
	assert_false(GDDI.has(&'Node'))
	assert_null(GDDI.inject(&'Node'))
	var service := Node.new()
	assert_true(GDDI.provide(&'Node', service))
	assert_true(GDDI.has(&'Node'))
	assert_same(GDDI.inject(&'Node'), service)
	assert_true(GDDI.get_provider_list().has('Node'))

func test_provide_node_reparents_and_keeps_name_by_default():
	var old_parent := Node.new()
	var new_parent := Node.new()
	GDDI.add_child(old_parent)
	GDDI.add_child(new_parent)
	var node := Node.new()
	node.name = 'KeptName'
	old_parent.add_child(node)
	assert_true(GDDI.provide_node(&'moved', node, {'parent': new_parent}))
	assert_same(node.get_parent(), new_parent)
	assert_eq(node.name, 'KeptName')
	assert_same(GDDI.inject(&'moved'), node)
	var unnamed := Node.new()
	assert_true(GDDI.provide_node(&'unnamed', unnamed, {'name': ''}))
	assert_eq(unnamed.name, 'Node')
	assert_same(unnamed.get_parent(), GDDI)
	old_parent.queue_free()
	new_parent.queue_free()

func test_factory_argument_mismatch_and_invalid_callable():
	assert_true(GDDI.provide_factory(&'invalid', Callable()))
	assert_null(GDDI.inject(&'invalid'))
	assert_true(GDDI.provide_factory(&'one_arg', func(_value: String):
		GDDI.set_meta(&'factory_invoked', true)
		return Node.new()
	))
	assert_null(GDDI.inject(&'one_arg'))
	assert_false(GDDI.get_meta(&'factory_invoked', false))
	assert_null(GDDI.inject(&'one_arg', 'a', 'b'))
	assert_false(GDDI.get_meta(&'factory_invoked', false))

func test_lazy_factory_caches_object_and_handles_null():
	assert_true(GDDI.provide_lazy(&'lazy_object', func():
		GDDI.set_meta(&'factory_calls', GDDI.get_meta(&'factory_calls', 0) + 1)
		return Object.new()
	))
	var first: Object = GDDI.inject(&'lazy_object')
	assert_not_null(first)
	assert_same(GDDI.inject(&'lazy_object'), first)
	assert_eq(GDDI.get_meta(&'factory_calls'), 1)
	assert_true(GDDI.remove(&'lazy_object'))
	assert_freed(first)

	assert_true(GDDI.provide_lazy(&'lazy_null', func(): return null))
	assert_null(GDDI.inject(&'lazy_null'))
	assert_false(GDDI.has(&'lazy_null'))

func test_remove_uninstantiated_factories_and_non_free_object():
	assert_true(GDDI.provide_factory(&'factory', func():
		GDDI.set_meta(&'factory_calls', GDDI.get_meta(&'factory_calls', 0) + 1)
		return Node.new()
	))
	assert_true(GDDI.remove(&'factory'))
	assert_eq(GDDI.get_meta(&'factory_calls', 0), 0)
	assert_true(GDDI.provide_lazy(&'lazy', func():
		GDDI.set_meta(&'factory_calls', GDDI.get_meta(&'factory_calls', 0) + 1)
		return Node.new()
	))
	assert_true(GDDI.remove(&'lazy'))
	assert_eq(GDDI.get_meta(&'factory_calls', 0), 0)

	var obj := Object.new()
	assert_true(GDDI.provide(&'object', obj))
	assert_true(GDDI.remove(&'object', false))
	assert_not_freed(obj)
	obj.free()
