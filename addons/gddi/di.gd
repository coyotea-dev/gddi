@icon("res://addons/gddi/icon.svg")
## Abstract base class for the `GDDI` Dependency Injection container.
@abstract
extends Node
class_name DI

## Checks whether a dependency has been registered under the given `key`.
@abstract func has(key: StringName) -> bool

## Returns a list of keys of all available providers.
@abstract func get_provider_list() -> PackedStringArray

## Resolves and returns a registered dependency by `key`.
## If the dependency is a factory, it constructs and returns the instance, passing any optional arguments.
## If the factory was registered as lazy, it replaces the factory registration with the generated instance.
@abstract func inject(key: StringName, ...args: Array[Variant]) -> Variant

## Resolves and returns a registered dependency by `key`.
## If the dependency is a factory, it constructs and returns the instance, passing any optional arguments.
## If the factory was registered as lazy, it replaces the factory registration with the generated instance.
@abstract func injectv(key: StringName, args: Array[Variant] = []) -> Variant

## Registers an `Object` instance under [param key]. Use [method provide_ref] when the container should keep a [RefCounted] instance alive.
## Returns [code]true[/code] when registered, or [code]false[/code] if [param key] is empty or already registered.
@abstract func provide(key: StringName, obj: Object) -> bool

## Registers a [RefCounted] instance and keeps it alive until the provider is removed.
## Returns [code]true[/code] when registered, or [code]false[/code] if [param key] is empty or already registered.
@abstract func provide_ref(key: StringName, ref: RefCounted) -> bool

## Registers a `Node` instance into the container and optionally sets its scene tree hierarchy and name.
## Returns `true` when the dependency is registered. Returns `false` if [param key] is empty or already registered. [br]
## [param options] accepts: [br]
## - `"parent"` - `Node` (Optional target parent node to attach to). [br]
## - `"name"`: `String` (Optional override for the node's name in the `SceneTree`).
@abstract func provide_node(key: StringName, node: Node, options: Dictionary = {}) -> bool

## Registers a factory function that will create a new instance on every call to `inject()`. 
## [b]Warning:[/b] The key must be unique across all providers, including lazy factories. A key that is already registered cannot be reused.
## Returns `true` when the dependency is registered. Returns `false` if [param key] is empty or already registered.
@abstract func provide_factory(key: StringName, factory: Callable) -> bool

## Registers a lazy-evaluated factory function that constructs the dependency on first `inject()` call and caches the result. 
## [b]Warning:[/b] The key must be unique across all providers, including regular factories. A key that is already registered cannot be reused.
## Returns `true` when the dependency is registered. Returns `false` if [param key] is empty or already registered.
@abstract func provide_lazy(key: StringName, factory: Callable) -> bool

## Unregisters a provider and frees its object unless [param free] is [code]false[/code]. Nodes are queued for deletion.
## Returns [code]true[/code] when removed, or [code]false[/code] if no provider exists for [param key].
@abstract func remove(key: StringName, free: bool = true) -> bool

## Unregisters and frees every registered provider.
@abstract func clear() -> void
