# GDDI

A lightweight stupidly simple dependency injection and service locator plugin for Godot, built around a simple API for registering and retrieving game services.

## Table of Contents

- [About the Project](#about-the-project)
- [Key Features](#key-features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage / Examples](#usage--examples)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)
- [Contact & Support](#contact--support)

## About the Project

GDDI helps Godot projects register shared objects and retrieve them by key instead of passing dependencies through many scenes and scripts. It runs as an autoload and stores registrations through Godot's Engine singleton system. The API supports ordinary `Object` instances, `RefCounted` instances, scene-tree nodes, factories, and lazily created services. Optional initializer scripts can register services at startup.

## Why GDDI?

GDDI builds on Godot's global access pattern with a registry for shared services.

### Autoload vs GDDI

| Capability              | Godot autoloads                                                   | GDDI                                                             |
| ----------------------- | ----------------------------------------------------------------- | ---------------------------------------------------------------- |
| Register services       | Configure each autoload in project settings                       | Register multiple providers by key, at runtime or with `GDDInit` |
| Supported values        | `Node` only                                                       | `Object`, `RefCounted`, and `Node` instances                     |
| Create on demand        | Not built in                                                      | Factories create new instances; lazy factories cache one         |
| Remove on demand        | Cannot unregister services and it not advised to try to free them | Remove a provider or clear all providers at runtime              |
| Flexible node placement | Default behaviour cannot be altered                               | Assign your registered nodes wherever you want                   |

## Key Features

- Register and retrieve dependencies with `provide()` and `inject()`.
- Register `Node` services and optionally set their name and scene-tree parent.
- Keep `RefCounted` services alive while registered with `provide_ref()`.
- Create a fresh object on every injection with a factory, or cache the first result with a lazy factory.
- List and remove registered providers, or clear the container.
- Register startup services with `GDDInit` initializer scripts.
- Configure timestamped GDDI logs by severity, with caller details for debugging.

## Prerequisites

- Godot Engine 4.7 or later.
- A Godot project where you can install and enable editor plugins.

## Installation

Follow these steps to set up the project locally:

1. Copy the `addons/gddi` directory into your Godot project's `addons` directory.
2. Open the project in Godot and go to **Project > Project Settings > Plugins**.
3. Enable the **GDDI** plugin. It adds the `GDDI` autoload and the initializer setting.
4. Use `GDDI` from your scripts.

> [!WARNING]  
> GDDI is an autoload, so startup order matters. Avoid using GDDI from other autoloads, or configure GDDI to load before any autoload that depends on it.

## Usage / Examples

Register an ordinary object and retrieve it by key:

```gdscript
# Define your provider(s)
var settings := GameSettings.new()
GDDI.provide(&"settings", settings)

# Then access it any where inside your project
var shared_settings: GameSettings = GDDI.inject(&"settings")
```

Use `provide_ref()` for a `RefCounted` service so the container keeps a strong reference to it until it is removed:

```gdscript
var profile := PlayerProfile.new()
GDDI.provide_ref(&"profile", profile)

var shared_profile: PlayerProfile = GDDI.inject(&"profile")
```

`provide()` accepts `Object` instances directly. Use it for objects whose lifetime is managed elsewhere; use `provide_ref()` when GDDI should keep a `RefCounted` instance alive.

Register a node as a service. By default, an unparented node is added under the `GDDI` autoload. You can choose a parent and name with the options dictionary:

```gdscript
var audio_service := AudioService.new()
GDDI.provide_node(&"audio", audio_service, {
    "parent": get_tree().root,
    "name": "AudioService",
})

var audio: AudioService = GDDI.inject(&"audio")
```

Use a factory when each injection should create a new instance, or a lazy factory when the first instance should be reused:

```gdscript
GDDI.provide_factory(&"enemy", func() -> Enemy:
    return Enemy.new()
)

GDDI.provide_lazy(&"profile", func() -> PlayerProfile:
    return PlayerProfile.load_or_create()
)

var new_enemy: Enemy = GDDI.inject(&"enemy")
var profile: PlayerProfile = GDDI.inject(&"profile")
```

A factory can inject another provider while it runs. For example, register shared settings first, then inject them when creating each game session:

```gdscript
GDDI.provide(&"settings", GameSettings.new())

GDDI.provide_factory(&"game_session", func() -> GameSession:
    var settings: GameSettings = GDDI.inject(&"settings")
    return GameSession.new(settings)
)

var session: GameSession = GDDI.inject(&"game_session")
```

> [!CAUTION]
> **Avoid self-recursion:** A factory or lazy factory can inject other providers while it runs, but it must not inject itself using its own key. Doing so calls the same factory again recursively.

Factory arguments are passed to the callable through `inject()` or `injectv()`:

```gdscript
GDDI.provide_factory(&"weapon", func(weapon_id: String) -> Weapon:
    return Weapon.create(weapon_id)
)

var sword: Weapon = GDDI.inject(&"weapon", "sword")
```

An initializer script can register providers during autoload startup. Add its `res://` path under **Project Settings > Application > GDDI > Initializers**:

```gdscript
extends GDDInit

func _registering_dependencies(di: DI) -> void:
    di.provide_factory(&"settings", func():
        return GameSettings.new()
    )
```

### Logging

GDDI logs provider registration, resolution, removal, initializer loading, and related warnings or errors. Each message includes a timestamp, severity, the `GDDI` tag, and (when available) the calling script, line, and function. Messages use Godot's rich text console output with a severity color.

Enable **Verbose** under **Project Settings > Application > GDDI** to turn on logging. In debug builds this starts at `DEBUG`; in non-debug builds it starts at `WARNING`. When Verbose is disabled, logging is off. You can change the threshold while the game is running:

```gdscript
GDDI.set_log_level(GDDILogger.LogLevel.INFO)
```

Available levels are `DEBUG`, `INFO`, `WARNING`, `ERROR`, and `NONE`. The threshold includes messages at that severity and above; for example, `INFO` emits info, warning, and error messages. `NONE` disables all messages. Logging can also be changed when Verbose is disabled; the setting only determines the initial level during GDDI startup.

### Managing providers

Check for a provider with `has()`, list registered keys with `get_provider_list()`, and unregister a provider with `remove()`. Removal frees the registered object by default; pass `false` to unregister without freeing it. Nodes are queued for deletion when freed. `clear()` removes and frees every registered provider.

```gdscript
if GDDI.has(&"audio"):
	GDDI.remove(&"audio", false) # Unregister but keep the object alive.

var provider_keys: PackedStringArray = GDDI.get_provider_list()
```

## Contributing

Contributions are welcome. Open an issue to discuss a bug or proposed change, or submit a pull request with a clear description of the change.

## License

Distributed under the **[MIT](https://github.com/coyotea-dev/godot-gddi?tab=MIT-1-ov-file) License**.

## Contact & Support

For questions, bug reports, or feature requests, open an issue in this repository.
