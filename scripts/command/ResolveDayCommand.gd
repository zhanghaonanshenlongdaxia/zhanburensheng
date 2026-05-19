class_name ResolveDayCommand
extends BaseCommand

func execute(_payload: Dictionary = {}) -> Variant:
	var day_rule_system: DailyRuleSystem = app.architecture.get_system(&"daily_rule")
	var npc_event_system: NpcEventSystem = app.architecture.get_system(&"npc_event")
	var night_action_system: NightActionSystem = app.architecture.get_system(&"night_action")
	var ending_system: EndingSystem = app.architecture.get_system(&"ending")
	var day_model: DayCycleModel = app.architecture.get_model(&"day_cycle")
	var rule_results: Array = day_rule_system.apply_daily_rules()
	var night_action: Dictionary = night_action_system.resolve_night_action()
	var npc_event: Dictionary = npc_event_system.trigger_random_event()
	var ending: Dictionary = ending_system.check_ending()
	app.architecture.event_bus.publish(&"day_resolved", {
		"rules": rule_results,
		"night_action": night_action,
		"npc_event": npc_event,
		"ending": ending,
		"day": day_model.current_day,
		"phase": day_model.current_phase
	})
	if not ending.is_empty():
		app.architecture.event_bus.publish(&"game_ended", ending)
		return {
			"rules": rule_results,
			"night_action": night_action,
			"npc_event": npc_event,
			"ending": ending
		}
	return {
		"rules": rule_results,
		"night_action": night_action,
		"npc_event": npc_event,
		"ending": {},
		"waiting_for_next_day": true,
		"day": day_model.current_day,
		"phase": day_model.current_phase
	}
