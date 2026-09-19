extends GDDInit
class_name MyGDDInit

func _registering_dependencies(dependency_container: DI) -> void:
	dependency_container.provide_factory(&'initializer_test_value', func():
		return 'initialized'
	)
