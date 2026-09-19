## Abstract initialization hook for registering dependencies at startup.
@abstract
class_name GDDInit
extends RefCounted


@abstract func _registering_dependencies(di: DI) -> void