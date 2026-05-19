class_name App
extends Node

const ArchitectureScript := preload("res://scripts/core/architecture/Architecture.gd")
const ConfigServiceScript := preload("res://scripts/service/ConfigService.gd")
const AsyncLoadServiceScript := preload("res://scripts/service/AsyncLoadService.gd")
const ThreadServiceScript := preload("res://scripts/service/ThreadService.gd")
const PoolServiceScript := preload("res://scripts/service/PoolService.gd")
const SceneServiceScript := preload("res://scripts/service/SceneService.gd")
const SaveServiceScript := preload("res://scripts/service/SaveService.gd")
const UIServiceScript := preload("res://scripts/service/UIService.gd")
const AudioServiceScript := preload("res://scripts/service/AudioService.gd")

const CONFIG_PRELOAD_PATHS: Array[String] = [
	"res://configs/tables/stat_table.json",
	"res://configs/tables/item_table.json",
	"res://configs/tables/location_table.json",
	"res://configs/tables/weather_table.json",
	"res://configs/tables/effect_table.json",
	"res://configs/gameplay/debt_table.json",
	"res://configs/gameplay/daily_rules.json",
	"res://configs/gameplay/flag_table.json",
	"res://configs/gameplay/option_unlock_table.json",
	"res://configs/gameplay/fortune_pool.json",
	"res://configs/gameplay/ending_config.json",
	"res://configs/gameplay/phase_config.json",
	"res://configs/events/outdoor_event_pool.json",
	"res://configs/events/npc_event_pool.json",
	"res://configs/events/night_action_pool.json",
	"res://configs/ui/main_page_config.json"
]

var architecture

func _ready() -> void:
	add_to_group("app")
	randomize()
	architecture = ArchitectureScript.new(self)
	_register_services()
	_register_models()
	_register_systems()
	call_deferred("_start_game")

func _start_game() -> void:
	architecture.command_dispatcher.dispatch(preload("res://scripts/command/StartGameCommand.gd"))

func _register_services() -> void:
	var config_service = ConfigServiceScript.new()
	config_service.preload_configs(CONFIG_PRELOAD_PATHS)
	architecture.register_service(&"config", config_service)
	var async_load_service = AsyncLoadServiceScript.new()
	architecture.register_service(&"async_load", async_load_service)
	architecture.register_service(&"thread", ThreadServiceScript.new())
	architecture.register_service(&"pool", PoolServiceScript.new())
	architecture.register_service(&"scene", SceneServiceScript.new(get_tree(), async_load_service))
	architecture.register_service(&"save", SaveServiceScript.new())

	var ui_manager = UIServiceScript.new()
	var root: Node = get_parent()
	if root != null:
		if root.has_node("UILayer"):
			ui_manager.register_layer(&"ui", root.get_node("UILayer"))
		if root.has_node("PopupLayer"):
			ui_manager.register_layer(&"popup", root.get_node("PopupLayer"))
		if root.has_node("LoadingLayer"):
			ui_manager.register_layer(&"loading", root.get_node("LoadingLayer"))
	architecture.register_service(&"ui", ui_manager)

	var audio_service = AudioServiceScript.new()
	audio_service.setup(root if root != null else self)
	architecture.register_service(&"audio", audio_service)

func _register_models() -> void:
	var config_service = architecture.get_service(&"config")
	var player_model: PlayerModel = PlayerModel.new()
	player_model.setup_from_config(config_service.get_cached("res://configs/tables/stat_table.json"))
	architecture.register_model(&"player", player_model)
	var inventory_model: InventoryModel = InventoryModel.new()
	inventory_model.setup_from_config(config_service.get_cached("res://configs/tables/item_table.json"))
	architecture.register_model(&"inventory", inventory_model)
	var flag_model: FlagModel = FlagModel.new()
	flag_model.setup_from_config(config_service.get_cached("res://configs/gameplay/flag_table.json"))
	architecture.register_model(&"flag", flag_model)
	var option_unlock_model: OptionUnlockModel = OptionUnlockModel.new()
	option_unlock_model.setup_from_config(config_service.get_cached("res://configs/gameplay/option_unlock_table.json"))
	architecture.register_model(&"option_unlock", option_unlock_model)
	var debt_model: DebtModel = DebtModel.new()
	debt_model.setup_from_config(config_service.get_cached("res://configs/gameplay/debt_table.json"))
	architecture.register_model(&"debt", debt_model)
	var day_cycle_model: DayCycleModel = DayCycleModel.new()
	day_cycle_model.setup_from_config(config_service.get_cached("res://configs/gameplay/phase_config.json"))
	architecture.register_model(&"day_cycle", day_cycle_model)
	architecture.register_model(&"weather", WeatherModel.new())
	architecture.register_model(&"fortune", FortuneSelectionModel.new())

func _register_systems() -> void:
	architecture.register_system(&"weather", WeatherSystem.new(self))
	architecture.register_system(&"fortune", FortuneSystem.new(self))
	architecture.register_system(&"condition", ConditionSystem.new(self))
	architecture.register_system(&"effect", EffectSystem.new(self))
	architecture.register_system(&"action_resolve", ActionResolveSystem.new(self))
	architecture.register_system(&"daily_rule", DailyRuleSystem.new(self))
	architecture.register_system(&"npc_event", NpcEventSystem.new(self))
	architecture.register_system(&"night_action", NightActionSystem.new(self))
	architecture.register_system(&"ending", EndingSystem.new(self))
