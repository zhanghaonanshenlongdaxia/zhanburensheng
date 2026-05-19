# QGF Quick Start

QGF is a thin Godot framework for fast solo iteration. It keeps the parts that are useful across projects and leaves gameplay in the project.

## Core flow

```text
View input -> Controller -> Command -> System -> Model -> EventBus -> UI refresh
```

## Minimal app setup

```gdscript
extends Node

var architecture: QGFArchitecture

func _ready() -> void:
	add_to_group("app")
	architecture = QGFArchitecture.new(self)
	architecture.register_service(&"config", QGFConfigService.new())
	architecture.command_dispatcher.dispatch(preload("res://scripts/command/StartGameCommand.gd"))
```

## Recommended services

- `QGFConfigService`: JSON config cache.
- `QGFAsyncLoadService`: threaded resource loading wrapper.
- `QGFSceneService`: scene switching and loaded scene handoff.
- `QGFUIManager`: layer-based panel opening.
- `QGFSaveService`: JSON save slots under `user://saves`.
- `QGFAudioService`: simple SFX and music playback.
- `QGFPoolService`: reusable Node pools.
- `QGFThreadService`: background data jobs.

Project-specific scripts can keep short aliases such as `ConfigService extends QGFConfigService` if you want stable local names.
