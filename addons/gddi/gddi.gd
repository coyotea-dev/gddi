## Dependency injection container for registering and resolving application services.
## Add this script as the `GDDI` autoload to make its API globally available.
extends DI

const _META_PREFIX: String = "GDDI_"
const _INITIALIZERS_SETTING: StringName = &"application/GDDI/initializers"
const _VERBOSE_SETTING: StringName = &"application/GDDI/verbose"

## Factory wrapper for dynamically instantiating objects via a `Callable`.
class _Factory extends Object:
	var callable: Callable

	func make(args: Array[Variant] = []) -> Variant:
		GDDILogger.debug("Creating factory instance with %d argument(s)." % args.size())
		if not callable.is_valid():
			GDDILogger.warn("Factory callable is invalid; no instance was created.")
			return null
		if args.size() != callable.get_argument_count():
			GDDILogger.warn("Factory expected %d argument(s), received %d; no instance was created." % [callable.get_argument_count(), args.size()])
			return null
		var instance: Variant = callable.callv(args)
		GDDILogger.info("Factory created %s." % (instance.get_class() if instance is Object else type_string(typeof(instance))))
		return instance

	func _init(factory: Callable) -> void:
		callable = factory

## Strong reference wrapper to prevent `RefCounted` instances from being garbage collected by Godot.
class _SolidRef extends Object:
	var target: RefCounted

	func get_ref() -> RefCounted:
		return target

	@warning_ignore("shadowed_variable")
	func _init(target: RefCounted) -> void:
		self.target = target

## Sets the minimum severity emitted by the GDDI logger.
## [enum GDDILogger.LogLevel] values include that level and more severe messages; [constant GDDILogger.LogLevel.NONE] disables logging.
func set_log_level(level: GDDILogger.LogLevel) -> void:
	GDDILogger.current_log_level = level
	GDDILogger.debug("Log level set to %s." % GDDILogger.LogLevel.keys()[level])

func _init() -> void:
	if ProjectSettings.get_setting(_VERBOSE_SETTING, false):
		GDDILogger.current_log_level = GDDILogger.LogLevel.DEBUG if OS.has_feature('debug') else GDDILogger.LogLevel.WARNING
	else:
		GDDILogger.current_log_level = GDDILogger.LogLevel.NONE

	var paths: PackedStringArray = ProjectSettings.get_setting(_INITIALIZERS_SETTING, PackedStringArray())
	GDDILogger.debug("Loading %d configured initializer(s)." % paths.size())
	for path in paths:
		GDDILogger.debug("Loading initializer '%s'." % path)
		if not ResourceLoader.exists(path, "GDScript"):
			GDDILogger.warn("Initializer '%s' does not exist; skipping it." % path)
			continue
		var script: GDScript = ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		if script == null:
			GDDILogger.error("Failed to load initializer '%s'." % path)
			continue
		var init: GDDInit = script.new()
		init._registering_dependencies(self)
		GDDILogger.info("Initialized dependencies from '%s'." % path)

## Returns whether a provider is registered under [param key].
func has(key: StringName) -> bool:
	GDDILogger.debug("Checking provider '%s'." % key)
	var found: bool = Engine.has_singleton(_annotate_key(key))
	GDDILogger.debug("Provider '%s' %s." % [key, "exists" if found else "does not exist"])
	return found

## Returns the keys of all currently registered providers.
func get_provider_list() -> PackedStringArray:
	GDDILogger.debug("Listing registered providers.")
	var providers: PackedStringArray = []
	for key in Engine.get_singleton_list():
		if key.begins_with(_META_PREFIX):
			providers.append(key.trim_prefix(_META_PREFIX))
	GDDILogger.info("Found %d registered provider(s)." % providers.size())
	return providers

## Resolves and returns a registered dependency by key.
## If the dependency is a factory, it constructs and returns the instance, passing any optional arguments.
## If the factory was registered as lazy, it replaces the factory registration with the generated instance.
## Returns [code]null[/code] and logs a warning when no provider exists for [param key].
func inject(key: StringName, ...args: Array[Variant]) -> Variant:
	return injectv(key, args)

## Resolves [param key], passing [param args] to a registered factory when applicable.
## A lazy factory is replaced by its generated object after successful creation.
func injectv(key: StringName, args: Array[Variant] = []) -> Variant:
	GDDILogger.debug("Resolving provider '%s' with %d argument(s)." % [key, args.size()])
	if not has(key):
		GDDILogger.warn("Provider '%s' is not registered; injection returned null." % key)
		return null
	var annotated_key := _annotate_key(key)
	var singleton: Object = Engine.get_singleton(annotated_key)

	if singleton is _Factory:
		var instance: Variant = singleton.make(args)
		if singleton.get_meta(_annotate_key(&'replace'), false):
			GDDILogger.debug("Replacing lazy factory for provider '%s'." % key)
			Engine.unregister_singleton(annotated_key)
			singleton.free()
			if instance is Node:
				provide_node(key, instance)
			elif instance is RefCounted:
				provide_ref(key, instance)
			elif instance is Object:
				provide(key, instance)
		if instance == null:
			GDDILogger.warn("Provider '%s' factory returned null." % key)
		else:
			GDDILogger.info("Resolved factory provider '%s'." % key)
		return instance
	elif singleton is _SolidRef:
		GDDILogger.info("Resolved reference provider '%s'." % key)
		return singleton.target
	else:
		GDDILogger.info("Resolved provider '%s'." % key)
		return singleton

## Registers [param obj] under [param key]. Use [method provide_ref] for [RefCounted] instances that GDDI should keep alive.
## Returns [code]false[/code] for an empty or duplicate key.
func provide(key: StringName, obj: Object) -> bool:
	GDDILogger.debug("Registering provider '%s'." % key)
	if key.is_empty():
		GDDILogger.warn("Cannot register a provider with an empty key.")
		return false
	if has(key):
		GDDILogger.warn("Provider '%s' is already registered; existing provider was kept." % key)
		return false
	Engine.register_singleton(_annotate_key(key), obj)
	GDDILogger.info("Registered provider '%s' (%s)." % [key, obj.get_class()])
	return true

## Registers [param ref] while keeping it alive until its provider is removed.
func provide_ref(key: StringName, ref: RefCounted) -> bool:
	GDDILogger.debug("Registering reference provider '%s'." % key)
	return provide(key, _SolidRef.new(ref))


## Registers [param node] and parents it to GDDI or the optional [code]parent[/code] in [param options].
## Options may also include [code]name[/code] to set the node name. Returns [code]false[/code] if [param key] is unavailable.
func provide_node(key: StringName, node: Node, options: Dictionary = {}) -> bool:
	GDDILogger.debug("Registering node provider '%s'." % key)
	if not provide(key, node):
		return false
	var old_parent: Node = node.get_parent()
	var parent: Node = options.get('parent')
	var node_name: String = options.get('name', node.name)
	if node_name.is_empty():
		if node.get_script() is Script:
			node_name = node.get_script().get_global_name()
		else:
			node_name = node.get_class()
	node.name = node_name
	if parent != null:
		if old_parent != null and parent != old_parent:
			GDDILogger.debug("Moving node '%s' to requested parent." % node.name)
			old_parent.remove_child(node)
			parent.add_child(node)
		elif old_parent == null:
			GDDILogger.debug("Adding node '%s' to requested parent." % node.name)
			parent.add_child(node)
	elif old_parent == null:
		GDDILogger.debug("Adding node '%s' to GDDI." % node.name)
		add_child(node)
	GDDILogger.info("Registered node provider '%s' as node '%s'." % [key, node.name])
	return true

## Registers [param factory] to create a new provider value on each injection.
func provide_factory(key: StringName, factory: Callable) -> bool:
	GDDILogger.debug("Registering factory provider '%s'." % key)
	return provide(key, _Factory.new(factory))

## Registers [param factory] and replaces it with its first successfully created object.
func provide_lazy(key: StringName, factory: Callable) -> bool:
	GDDILogger.debug("Registering lazy provider '%s'." % key)
	var f := _Factory.new(factory)
	f.set_meta(_annotate_key(&'replace'), true)
	return provide(key, f)

## Unregisters [param key] and frees its registered object when [param free] is [code]true[/code].
## Nodes are queued for deletion. When [param free] is [code]false[/code], only the registration is removed.
## Returns [code]false[/code] if the provider is absent.
func remove(key: StringName, free: bool = true) -> bool:
	GDDILogger.debug("Removing provider '%s' (free=%s)." % [key, free])
	if not has(key):
		GDDILogger.warn("Provider '%s' is not registered; nothing was removed." % key)
		return false
	var annotated_key := _annotate_key(key)
	var singleton: Variant = Engine.get_singleton(annotated_key)
	Engine.unregister_singleton(annotated_key)

	if not free:
		GDDILogger.info("Unregistered provider '%s' without freeing its object." % key)
		return true

	if singleton is Node:
		singleton.queue_free()
	else:
		singleton.free()
	GDDILogger.info("Removed provider '%s' and freed its object." % key)
	return true

## Unregisters and frees all registered providers.
func clear() -> void:
	GDDILogger.debug("Clearing all registered providers.")
	var providers: PackedStringArray = get_provider_list()
	for key in providers:
		remove(key)
	GDDILogger.info("Cleared %d provider(s)." % providers.size())

## Formats the raw `StringName` key with a unique prefix to prevent collisions with built-in Godot Engine singletons.
static func _annotate_key(key: StringName) -> StringName:
	return _META_PREFIX + key
