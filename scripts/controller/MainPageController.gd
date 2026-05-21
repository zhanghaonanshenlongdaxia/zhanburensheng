class_name MainPageController
extends Control

const ExplorationBoardScript := preload("res://scripts/ui/ExplorationBoard.gd")
const TownBoardScript := preload("res://scripts/ui/TownBoard.gd")
const OptionCardBackdropScript := preload("res://scripts/ui/OptionCardBackdrop.gd")
const ClueBoardScript := preload("res://scripts/ui/ClueBoard.gd")
const FortuneChoiceEffectLayerScript := preload("res://scripts/ui/FortuneChoiceEffectLayer.gd")
const FortuneSlipTokenButtonScript := preload("res://scripts/ui/FortuneSlipTokenButton.gd")

@onready var day_label: Label = $MainMargin/RootColumn/TopLayout/Sidebar/SidebarStack/HeaderPanel/MarginContainer/HeaderVBox/TopRow/DayLabel
@onready var weather_label: Label = $MainMargin/RootColumn/TopLayout/Sidebar/SidebarStack/HeaderPanel/MarginContainer/HeaderVBox/TopRow/WeatherLabel
@onready var player_state_label: Label = $MainMargin/RootColumn/TopLayout/Sidebar/SidebarStack/StatsPanel/MarginContainer/StatsVBox/PlayerStateLabel
@onready var inventory_label: Label = $MainMargin/RootColumn/TopLayout/Sidebar/SidebarStack/StatsPanel/MarginContainer/StatsVBox/InventoryLabel
@onready var scene_illustration: SceneIllustration = $MainMargin/RootColumn/TopLayout/MainStage/StagePanel/MarginContainer/StageVBox/SceneIllustration
@onready var main_margin: Control = $MainMargin
@onready var root_column: VBoxContainer = $MainMargin/RootColumn
@onready var top_layout: HBoxContainer = $MainMargin/RootColumn/TopLayout
@onready var sidebar: VBoxContainer = $MainMargin/RootColumn/TopLayout/Sidebar
@onready var main_stage: VBoxContainer = $MainMargin/RootColumn/TopLayout/MainStage
@onready var choices_panel: PanelContainer = $MainMargin/RootColumn/TopLayout/MainStage/ChoicesPanel
@onready var result_panel: PanelContainer = $MainMargin/RootColumn/ResultPanel
@onready var option_buttons: Array[Button] = [
	$MainMargin/RootColumn/TopLayout/MainStage/ChoicesPanel/MarginContainer/ChoicesVBox/OptionButton1,
	$MainMargin/RootColumn/TopLayout/MainStage/ChoicesPanel/MarginContainer/ChoicesVBox/OptionButton2,
	$MainMargin/RootColumn/TopLayout/MainStage/ChoicesPanel/MarginContainer/ChoicesVBox/OptionButton3
]
@onready var option_rich_labels: Array[RichTextLabel] = [
	$MainMargin/RootColumn/TopLayout/MainStage/ChoicesPanel/MarginContainer/ChoicesVBox/OptionButton1/ContentRow/OptionText,
	$MainMargin/RootColumn/TopLayout/MainStage/ChoicesPanel/MarginContainer/ChoicesVBox/OptionButton2/ContentRow/OptionText,
	$MainMargin/RootColumn/TopLayout/MainStage/ChoicesPanel/MarginContainer/ChoicesVBox/OptionButton3/ContentRow/OptionText
]
@onready var option_illustrations: Array[OptionIllustration] = [
	$MainMargin/RootColumn/TopLayout/MainStage/ChoicesPanel/MarginContainer/ChoicesVBox/OptionButton1/ContentRow/OptionIllustration,
	$MainMargin/RootColumn/TopLayout/MainStage/ChoicesPanel/MarginContainer/ChoicesVBox/OptionButton2/ContentRow/OptionIllustration,
	$MainMargin/RootColumn/TopLayout/MainStage/ChoicesPanel/MarginContainer/ChoicesVBox/OptionButton3/ContentRow/OptionIllustration
]
@onready var selection_label: Label = $MainMargin/RootColumn/ResultPanel/MarginContainer/ResultVBox/SelectionLabel
@onready var next_day_button: Button = $MainMargin/RootColumn/ResultPanel/MarginContainer/ResultVBox/NextDayButton

var _app: App
var _ui_config: Dictionary = {}
var _content_scroll: ScrollContainer
var _compact_option_markup: bool = false
var _interaction_mode: String = "fortune"
var _current_weather: Dictionary = {}
var _last_action_summary: String = ""
var _exploration_board: Control
var _town_board: Control
var _inventory_overlay: PanelContainer
var _inventory_content: RichTextLabel
var _inventory_resource_list: VBoxContainer
var _inventory_loot_grid: GridContainer
var _inventory_empty_label: Label
var _inventory_button: Button
var _clue_button: Button
var _town_button: Button
var _clue_overlay: PanelContainer
var _clue_board: Control
var _feedback_layer: Control
var _feedback_bubble_index: int = 0
var _player_state_rich: RichTextLabel
var _inventory_rich: RichTextLabel
var _selection_rich: RichTextLabel
var _status_scroll: ScrollContainer
var _status_scroll_content: VBoxContainer
var _result_scroll: ScrollContainer
var _result_scroll_content: VBoxContainer
var _situation_echo_row: HBoxContainer
var _item_icon_textures: Dictionary = {}
var _option_backdrops: Array = []
var _option_confirm_boxes: Array[Control] = []
var _option_confirm_buttons: Array[Button] = []
var _option_cancel_buttons: Array[Button] = []
var _pending_option_index: int = -1
var _confirmed_option: Dictionary = {}
var _fortune_effect_layer: Control
var _omen_token_button: Button
var _omen_token_tween: Tween
var _omen_detail_overlay: PanelContainer
var _omen_detail_text: RichTextLabel

func _ready() -> void:
	_ensure_scroll_viewport()
	_ensure_exploration_board()
	_ensure_town_board()
	_ensure_inventory_overlay()
	_ensure_clue_overlay()
	_ensure_sidebar_buttons()
	_ensure_feedback_layer()
	_ensure_fortune_choice_ui()
	_ensure_option_backdrops()
	_ensure_sidebar_result_layout()
	_ensure_rich_text_replacements()
	_apply_visual_polish()
	_app = get_tree().get_first_node_in_group("app") as App
	if _app == null and get_parent() != null and get_parent().get_parent() != null:
		var root: Node = get_parent().get_parent()
		if root.has_node("App"):
			_app = root.get_node("App") as App
	for i in option_buttons.size():
		option_buttons[i].pressed.connect(_on_option_pressed.bind(i))
		option_rich_labels[i].gui_input.connect(_on_option_text_gui_input.bind(i))
	next_day_button.pressed.connect(_on_next_day_pressed)
	resized.connect(_apply_responsive_layout)
	next_day_button.visible = false
	next_day_button.disabled = true
	for button in option_buttons:
		button.disabled = true
	_set_selection_text("今日尚未选择行动")
	_apply_responsive_layout()
	if _app != null:
		var config_service: ConfigService = _app.architecture.get_service(&"config")
		_ui_config = config_service.get_cached("res://configs/ui/main_page_config.json")
		_app.architecture.event_bus.subscribe(&"day_started", Callable(self, "_on_day_started"))
		_app.architecture.event_bus.subscribe(&"fortune_selected", Callable(self, "_on_fortune_selected"))
		_app.architecture.event_bus.subscribe(&"action_resolved", Callable(self, "_on_action_resolved"))
		_app.architecture.event_bus.subscribe(&"day_resolved", Callable(self, "_on_day_resolved"))
		_app.architecture.event_bus.subscribe(&"game_ended", Callable(self, "_on_game_ended"))
		_try_render_existing_day()
		_refresh_status()
	_sync_quick_action_buttons()

func _ensure_scroll_viewport() -> void:
	if _content_scroll != null:
		return
	_content_scroll = ScrollContainer.new()
	_content_scroll.name = "ContentScroll"
	_content_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_content_scroll.follow_focus = true
	_content_scroll.clip_contents = true
	remove_child(main_margin)
	add_child(_content_scroll)
	move_child(_content_scroll, 2)
	_content_scroll.add_child(main_margin)
	main_margin.layout_mode = 2
	main_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _ensure_sidebar_result_layout() -> void:
	var sidebar_stack := _get_main_node("RootColumn/TopLayout/Sidebar/SidebarStack") as VBoxContainer
	var stats_panel := _get_main_node("RootColumn/TopLayout/Sidebar/SidebarStack/StatsPanel") as PanelContainer
	if sidebar_stack == null or stats_panel == null or result_panel == null:
		return
	_situation_echo_row = sidebar_stack.get_node_or_null("SituationEchoRow") as HBoxContainer
	if _situation_echo_row == null:
		_situation_echo_row = HBoxContainer.new()
		_situation_echo_row.name = "SituationEchoRow"
		_situation_echo_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_situation_echo_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_situation_echo_row.add_theme_constant_override("separation", 10)
		sidebar_stack.add_child(_situation_echo_row)
		var header_panel := _get_main_node("RootColumn/TopLayout/Sidebar/SidebarStack/HeaderPanel") as PanelContainer
		var insert_index := header_panel.get_index() + 1 if header_panel != null and header_panel.get_parent() == sidebar_stack else 1
		sidebar_stack.move_child(_situation_echo_row, mini(insert_index, sidebar_stack.get_child_count() - 1))
	for panel in [stats_panel, result_panel]:
		if panel.get_parent() != _situation_echo_row:
			if panel.get_parent() != null:
				panel.get_parent().remove_child(panel)
			_situation_echo_row.add_child(panel)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var result_header := result_panel.get_node_or_null("MarginContainer/ResultVBox/ResultHeader") as HBoxContainer
	if result_header != null and next_day_button != null and next_day_button.get_parent() != result_header:
		if next_day_button.get_parent() != null:
			next_day_button.get_parent().remove_child(next_day_button)
		result_header.add_child(next_day_button)
		next_day_button.custom_minimum_size = Vector2(78.0, 30.0)
		next_day_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		next_day_button.add_theme_font_size_override("font_size", 13)
	var result_subtitle := result_panel.get_node_or_null("MarginContainer/ResultVBox/ResultHeader/ResultSubTitle") as Label
	if result_subtitle != null:
		result_subtitle.visible = false
	var sidebar_flavor := _get_main_node("RootColumn/TopLayout/Sidebar/SidebarStack/SidebarFlavor") as Label
	if sidebar_flavor != null and sidebar_flavor.get_parent() == sidebar_stack:
		sidebar_stack.move_child(sidebar_flavor, sidebar_stack.get_child_count() - 1)

func _ensure_exploration_board() -> void:
	if _exploration_board != null:
		return
	_exploration_board = ExplorationBoardScript.new()
	_exploration_board.name = "ExplorationBoard"
	_exploration_board.visible = false
	_exploration_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_exploration_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_exploration_board.custom_minimum_size = Vector2(0.0, 330.0)
	main_stage.add_child(_exploration_board)
	_exploration_board.log_changed.connect(_on_exploration_log_changed)
	_exploration_board.loot_found.connect(_on_exploration_loot_found)
	_exploration_board.danger_resolved.connect(_on_exploration_danger_resolved)
	_exploration_board.extracted.connect(_on_exploration_extracted)

func _ensure_town_board() -> void:
	if _town_board != null:
		return
	_town_board = TownBoardScript.new()
	_town_board.name = "TownBoard"
	_town_board.visible = false
	_town_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_town_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_town_board.custom_minimum_size = Vector2(0.0, 330.0)
	main_stage.add_child(_town_board)
	_town_board.log_changed.connect(_on_town_log_changed)
	_town_board.buy_requested.connect(_on_town_buy_requested)
	_town_board.sell_requested.connect(_on_town_sell_requested)
	_town_board.contact_unlocked.connect(_on_town_contact_unlocked)
	_town_board.task_started.connect(_on_town_task_started)
	_town_board.task_completed.connect(_on_town_task_completed)
	_town_board.extracted.connect(_on_town_extracted)

func _ensure_inventory_overlay() -> void:
	if _inventory_overlay != null:
		return
	_inventory_overlay = PanelContainer.new()
	_inventory_overlay.name = "InventoryOverlay"
	_inventory_overlay.visible = false
	_inventory_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inventory_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_inventory_overlay.z_index = 40
	_inventory_overlay.add_theme_stylebox_override("panel", _make_panel_style(
		Color(0.030, 0.027, 0.024, 1.0),
		Color(0.76, 0.56, 0.28, 0.92),
		0,
		0
	))
	add_child(_inventory_overlay)
	move_child(_inventory_overlay, get_child_count() - 1)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inventory_overlay.add_child(center)

	var bag_panel := PanelContainer.new()
	bag_panel.name = "BagPanel"
	bag_panel.custom_minimum_size = Vector2(840.0, 560.0)
	bag_panel.add_theme_stylebox_override("panel", _make_inventory_bag_style())
	center.add_child(bag_panel)

	var bag_margin := MarginContainer.new()
	bag_margin.add_theme_constant_override("margin_left", 30)
	bag_margin.add_theme_constant_override("margin_top", 22)
	bag_margin.add_theme_constant_override("margin_right", 30)
	bag_margin.add_theme_constant_override("margin_bottom", 26)
	bag_panel.add_child(bag_margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	bag_margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	header.add_child(title_box)

	var title := Label.new()
	title.text = "旧布包"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.96, 0.86, 0.62, 1.0))
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "麻绳扎口，贴身藏物。值钱货不要在村口露出来。"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.70, 0.62, 0.48, 1.0))
	title_box.add_child(subtitle)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(96, 36)
	_apply_solid_button_style(close_button)
	close_button.pressed.connect(func() -> void:
		_inventory_overlay.visible = false
	)
	header.add_child(close_button)

	var stitch := HSeparator.new()
	stitch.add_theme_color_override("separator", Color(0.76, 0.56, 0.28, 0.55))
	root.add_child(stitch)

	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root.add_child(body)

	var resource_panel := PanelContainer.new()
	resource_panel.custom_minimum_size = Vector2(220.0, 0.0)
	resource_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	resource_panel.add_theme_stylebox_override("panel", _make_inventory_inner_style(Color(0.082, 0.058, 0.036, 1.0)))
	body.add_child(resource_panel)

	var resource_margin := MarginContainer.new()
	resource_margin.add_theme_constant_override("margin_left", 14)
	resource_margin.add_theme_constant_override("margin_top", 14)
	resource_margin.add_theme_constant_override("margin_right", 14)
	resource_margin.add_theme_constant_override("margin_bottom", 14)
	resource_panel.add_child(resource_margin)

	var resource_root := VBoxContainer.new()
	resource_root.add_theme_constant_override("separation", 10)
	resource_margin.add_child(resource_root)

	var resource_title := Label.new()
	resource_title.text = "贴身小袋"
	resource_title.add_theme_font_size_override("font_size", 18)
	resource_title.add_theme_color_override("font_color", Color(0.96, 0.86, 0.62, 1.0))
	resource_root.add_child(resource_title)

	_inventory_resource_list = VBoxContainer.new()
	_inventory_resource_list.add_theme_constant_override("separation", 8)
	resource_root.add_child(_inventory_resource_list)

	var loot_panel := PanelContainer.new()
	loot_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loot_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loot_panel.add_theme_stylebox_override("panel", _make_inventory_inner_style(Color(0.060, 0.049, 0.037, 1.0)))
	body.add_child(loot_panel)

	var loot_margin := MarginContainer.new()
	loot_margin.add_theme_constant_override("margin_left", 14)
	loot_margin.add_theme_constant_override("margin_top", 14)
	loot_margin.add_theme_constant_override("margin_right", 14)
	loot_margin.add_theme_constant_override("margin_bottom", 14)
	loot_panel.add_child(loot_margin)

	var loot_root := VBoxContainer.new()
	loot_root.add_theme_constant_override("separation", 10)
	loot_margin.add_child(loot_root)

	var loot_title := Label.new()
	loot_title.text = "包内夹层"
	loot_title.add_theme_font_size_override("font_size", 18)
	loot_title.add_theme_color_override("font_color", Color(0.96, 0.86, 0.62, 1.0))
	loot_root.add_child(loot_title)

	var loot_scroll := ScrollContainer.new()
	loot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	loot_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	loot_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loot_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loot_root.add_child(loot_scroll)

	_inventory_loot_grid = GridContainer.new()
	_inventory_loot_grid.columns = 3
	_inventory_loot_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_loot_grid.add_theme_constant_override("h_separation", 10)
	_inventory_loot_grid.add_theme_constant_override("v_separation", 10)
	loot_scroll.add_child(_inventory_loot_grid)

	_inventory_empty_label = Label.new()
	_inventory_empty_label.text = "夹层还是空的。去村外探索，或到城镇补给后再出发。"
	_inventory_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inventory_empty_label.add_theme_color_override("font_color", Color(0.66, 0.61, 0.50, 1.0))
	_inventory_empty_label.add_theme_font_size_override("font_size", 14)
	loot_root.add_child(_inventory_empty_label)

	_inventory_content = RichTextLabel.new()
	_inventory_content.bbcode_enabled = true
	_inventory_content.fit_content = true
	_inventory_content.scroll_active = false
	_inventory_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_content.add_theme_font_size_override("normal_font_size", 14)
	_inventory_content.add_theme_color_override("default_color", Color(0.78, 0.72, 0.58, 1.0))
	root.add_child(_inventory_content)

func _ensure_clue_overlay() -> void:
	if _clue_overlay != null:
		return
	_clue_overlay = PanelContainer.new()
	_clue_overlay.name = "ClueOverlay"
	_clue_overlay.visible = false
	_clue_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clue_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_clue_overlay.z_index = 42
	_clue_overlay.add_theme_stylebox_override("panel", _make_panel_style(
		Color(0.030, 0.027, 0.024, 1.0),
		Color(0.76, 0.56, 0.28, 0.90),
		0,
		0
	))
	add_child(_clue_overlay)
	move_child(_clue_overlay, get_child_count() - 1)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clue_overlay.add_child(center)

	var board_panel := PanelContainer.new()
	board_panel.name = "CluePanel"
	board_panel.custom_minimum_size = Vector2(940.0, 620.0)
	board_panel.add_theme_stylebox_override("panel", _make_inventory_bag_style())
	center.add_child(board_panel)

	var board_margin := MarginContainer.new()
	board_margin.add_theme_constant_override("margin_left", 22)
	board_margin.add_theme_constant_override("margin_top", 18)
	board_margin.add_theme_constant_override("margin_right", 22)
	board_margin.add_theme_constant_override("margin_bottom", 22)
	board_panel.add_child(board_margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	board_margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	var title := Label.new()
	title.text = "线索簿"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.96, 0.86, 0.62, 1.0))
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "把见过的人、旧物、暗路和传闻摆在一起，缺口也会说话。"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.70, 0.62, 0.48, 1.0))
	title_box.add_child(subtitle)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(96, 36)
	_apply_solid_button_style(close_button)
	close_button.pressed.connect(func() -> void:
		_clue_overlay.visible = false
	)
	header.add_child(close_button)

	var stitch := HSeparator.new()
	stitch.add_theme_color_override("separator", Color(0.76, 0.56, 0.28, 0.55))
	root.add_child(stitch)

	_clue_board = ClueBoardScript.new()
	_clue_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clue_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_clue_board.deduction_requested.connect(_on_clue_deduction_requested)
	root.add_child(_clue_board)

func _ensure_sidebar_buttons() -> void:
	var existing := get_node_or_null("QuickActionBar") as HBoxContainer
	if existing != null:
		return
	var header_vbox := _get_main_node("RootColumn/TopLayout/Sidebar/SidebarStack/HeaderPanel/MarginContainer/HeaderVBox") as VBoxContainer
	if header_vbox != null:
		var old_row := header_vbox.get_node_or_null("ActionButtons")
		if old_row != null:
			old_row.queue_free()
	var row := HBoxContainer.new()
	row.name = "QuickActionBar"
	row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	row.offset_left = -374.0
	row.offset_top = 18.0
	row.offset_right = -18.0
	row.offset_bottom = 54.0
	row.z_index = 20
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_constant_override("separation", 8)
	add_child(row)

	_inventory_button = _make_sidebar_button("背包")
	_inventory_button.pressed.connect(_on_inventory_button_pressed)
	row.add_child(_inventory_button)

	_clue_button = _make_sidebar_button("线索")
	_clue_button.pressed.connect(_on_clue_button_pressed)
	row.add_child(_clue_button)

	_town_button = _make_sidebar_button("去城镇")
	_town_button.pressed.connect(_on_town_button_pressed)
	row.add_child(_town_button)

func _ensure_feedback_layer() -> void:
	if _feedback_layer != null:
		return
	_feedback_layer = Control.new()
	_feedback_layer.name = "FeedbackLayer"
	_feedback_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_feedback_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_layer.z_index = 80
	add_child(_feedback_layer)
	move_child(_feedback_layer, get_child_count() - 1)

func _ensure_fortune_choice_ui() -> void:
	_ensure_option_confirm_controls()
	if _fortune_effect_layer == null:
		_fortune_effect_layer = FortuneChoiceEffectLayerScript.new()
		_fortune_effect_layer.name = "FortuneChoiceEffectLayer"
		_fortune_effect_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fortune_effect_layer.z_index = 75
		add_child(_fortune_effect_layer)
		move_child(_fortune_effect_layer, get_child_count() - 1)
	if _omen_token_button == null:
		_omen_token_button = FortuneSlipTokenButtonScript.new()
		_omen_token_button.name = "SelectedOmenToken"
		_omen_token_button.visible = false
		_omen_token_button.text = "已定卦"
		_omen_token_button.custom_minimum_size = Vector2(176.0, 38.0)
		_omen_token_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_omen_token_button.offset_left = -594.0
		_omen_token_button.offset_top = 18.0
		_omen_token_button.offset_right = -404.0
		_omen_token_button.offset_bottom = 58.0
		_omen_token_button.z_index = 30
		_omen_token_button.focus_mode = Control.FOCUS_NONE
		_omen_token_button.tooltip_text = "查看已定卦象"
		_apply_omen_token_style()
		_omen_token_button.pressed.connect(_on_omen_token_pressed)
		add_child(_omen_token_button)
	if _omen_detail_overlay == null:
		_omen_detail_overlay = _make_omen_detail_overlay()
		add_child(_omen_detail_overlay)
		move_child(_omen_detail_overlay, get_child_count() - 1)

func _ensure_option_confirm_controls() -> void:
	if not _option_confirm_boxes.is_empty():
		return
	for index in option_buttons.size():
		var button := option_buttons[index]
		var content_row := button.get_node_or_null("ContentRow") as HBoxContainer
		if content_row == null:
			continue
		var box := VBoxContainer.new()
		box.name = "ConfirmBox"
		box.visible = false
		box.custom_minimum_size = Vector2(94.0, 0.0)
		box.size_flags_horizontal = Control.SIZE_SHRINK_END
		box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		box.add_theme_constant_override("separation", 6)
		content_row.add_child(box)
		var confirm_button := Button.new()
		confirm_button.text = "确认"
		confirm_button.custom_minimum_size = Vector2(86.0, 30.0)
		confirm_button.focus_mode = Control.FOCUS_NONE
		confirm_button.mouse_filter = Control.MOUSE_FILTER_STOP
		_apply_solid_button_style(confirm_button)
		confirm_button.pressed.connect(_on_option_confirm_pressed.bind(index))
		box.add_child(confirm_button)
		var cancel_button := Button.new()
		cancel_button.text = "取消"
		cancel_button.custom_minimum_size = Vector2(86.0, 30.0)
		cancel_button.focus_mode = Control.FOCUS_NONE
		cancel_button.mouse_filter = Control.MOUSE_FILTER_STOP
		_apply_solid_button_style(cancel_button)
		cancel_button.pressed.connect(_on_option_cancel_pressed.bind(index))
		box.add_child(cancel_button)
		_option_confirm_boxes.append(box)
		_option_confirm_buttons.append(confirm_button)
		_option_cancel_buttons.append(cancel_button)

func _apply_omen_token_style() -> void:
	if _omen_token_button == null:
		return
	var normal := StyleBoxEmpty.new()
	var hover := StyleBoxEmpty.new()
	_omen_token_button.add_theme_stylebox_override("normal", normal)
	_omen_token_button.add_theme_stylebox_override("hover", hover)
	_omen_token_button.add_theme_stylebox_override("pressed", hover)
	_omen_token_button.add_theme_color_override("font_color", Color(0.20, 0.10, 0.035, 1.0))
	_omen_token_button.add_theme_color_override("font_hover_color", Color(0.08, 0.035, 0.010, 1.0))
	_omen_token_button.add_theme_color_override("font_pressed_color", Color(0.36, 0.13, 0.04, 1.0))
	_omen_token_button.add_theme_color_override("font_outline_color", Color(0.96, 0.78, 0.42, 0.78))
	_omen_token_button.add_theme_constant_override("outline_size", 2)
	_omen_token_button.add_theme_font_size_override("font_size", 14)

func _make_omen_detail_overlay() -> PanelContainer:
	var overlay := PanelContainer.new()
	overlay.name = "OmenDetailOverlay"
	overlay.visible = false
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 65
	overlay.add_theme_stylebox_override("panel", _make_panel_style(Color(0.0, 0.0, 0.0, 0.58), Color(0.0, 0.0, 0.0, 0.0), 0, 0))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520.0, 300.0)
	panel.add_theme_stylebox_override("panel", _make_inventory_bag_style())
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "已定卦象"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.96, 0.84, 0.56, 1.0))
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(86.0, 34.0)
	_apply_solid_button_style(close_button)
	close_button.pressed.connect(func() -> void:
		_omen_detail_overlay.visible = false
	)
	header.add_child(close_button)
	_omen_detail_text = RichTextLabel.new()
	_omen_detail_text.bbcode_enabled = true
	_omen_detail_text.fit_content = false
	_omen_detail_text.scroll_active = true
	_omen_detail_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_omen_detail_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_omen_detail_text.add_theme_font_size_override("normal_font_size", 15)
	_omen_detail_text.add_theme_color_override("default_color", Color(0.84, 0.78, 0.64, 1.0))
	root.add_child(_omen_detail_text)
	return overlay

func _ensure_option_backdrops() -> void:
	_option_backdrops.clear()
	for index in option_buttons.size():
		var button := option_buttons[index]
		var backdrop = button.get_node_or_null("OptionCardBackdrop")
		if backdrop == null:
			backdrop = OptionCardBackdropScript.new()
			backdrop.name = "OptionCardBackdrop"
			backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
			backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(backdrop)
			button.move_child(backdrop, 0)
		_option_backdrops.append(backdrop)

func _make_sidebar_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(116, 36)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 15)
	_apply_solid_button_style(button)
	return button

func _sync_quick_action_buttons() -> void:
	if _inventory_button != null:
		_inventory_button.disabled = _app == null
	if _clue_button != null:
		_clue_button.disabled = _app == null
	if _town_button != null:
		_town_button.disabled = _app == null or _interaction_mode != "fortune"

func _ensure_rich_text_replacements() -> void:
	_player_state_rich = _create_rich_replacement(player_state_label)
	_inventory_rich = _create_rich_replacement(inventory_label)
	_selection_rich = _create_rich_replacement(selection_label)
	_ensure_status_scroll_area()
	_ensure_result_scroll_area()

func _create_rich_replacement(source: Label) -> RichTextLabel:
	var existing := source.get_parent().get_node_or_null("%sRich" % source.name) as RichTextLabel
	if existing != null:
		source.visible = false
		return existing
	var rich := RichTextLabel.new()
	rich.name = "%sRich" % source.name
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich.size_flags_horizontal = source.size_flags_horizontal
	rich.size_flags_vertical = source.size_flags_vertical
	rich.custom_minimum_size = source.custom_minimum_size
	rich.add_theme_color_override("default_color", Color(0.82, 0.79, 0.70, 1.0))
	rich.add_theme_font_size_override("normal_font_size", 15)
	var parent := source.get_parent()
	var index := source.get_index()
	source.visible = false
	parent.add_child(rich)
	parent.move_child(rich, index + 1)
	return rich

func _ensure_status_scroll_area() -> void:
	var stats_vbox := _get_main_node("RootColumn/TopLayout/Sidebar/SidebarStack/StatsPanel/MarginContainer/StatsVBox") as VBoxContainer
	if stats_vbox == null:
		return
	_status_scroll = stats_vbox.get_node_or_null("StatusScroll") as ScrollContainer
	if _status_scroll == null:
		_status_scroll = ScrollContainer.new()
		_status_scroll.name = "StatusScroll"
		_status_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_status_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_status_scroll.follow_focus = true
		_status_scroll.clip_contents = true
		_status_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_status_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stats_vbox.add_child(_status_scroll)
		stats_vbox.move_child(_status_scroll, mini(1, stats_vbox.get_child_count() - 1))
	_status_scroll_content = _status_scroll.get_node_or_null("StatusScrollContent") as VBoxContainer
	if _status_scroll_content == null:
		_status_scroll_content = VBoxContainer.new()
		_status_scroll_content.name = "StatusScrollContent"
		_status_scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_status_scroll_content.add_theme_constant_override("separation", 10)
		_status_scroll.add_child(_status_scroll_content)
	for node in [player_state_label, _player_state_rich, inventory_label, _inventory_rich]:
		if node == null or node.get_parent() == _status_scroll_content:
			continue
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		_status_scroll_content.add_child(node)
	for rich in [_player_state_rich, _inventory_rich]:
		if rich == null:
			continue
		rich.fit_content = true
		rich.scroll_active = false
		rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rich.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

func _ensure_result_scroll_area() -> void:
	var result_vbox := result_panel.get_node_or_null("MarginContainer/ResultVBox") as VBoxContainer if result_panel != null else null
	if result_vbox == null:
		return
	_result_scroll = result_vbox.get_node_or_null("ResultScroll") as ScrollContainer
	if _result_scroll == null:
		_result_scroll = ScrollContainer.new()
		_result_scroll.name = "ResultScroll"
		_result_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_result_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_result_scroll.follow_focus = true
		_result_scroll.clip_contents = true
		_result_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_result_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		result_vbox.add_child(_result_scroll)
		result_vbox.move_child(_result_scroll, mini(1, result_vbox.get_child_count() - 1))
	_result_scroll_content = _result_scroll.get_node_or_null("ResultScrollContent") as VBoxContainer
	if _result_scroll_content == null:
		_result_scroll_content = VBoxContainer.new()
		_result_scroll_content.name = "ResultScrollContent"
		_result_scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_result_scroll.add_child(_result_scroll_content)
	for node in [selection_label, _selection_rich]:
		if node == null or node.get_parent() == _result_scroll_content:
			continue
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		_result_scroll_content.add_child(node)
	if _selection_rich != null:
		_selection_rich.fit_content = true
		_selection_rich.scroll_active = false
		_selection_rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_selection_rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_selection_rich.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

func _apply_visual_polish() -> void:
	var background: ColorRect = get_node_or_null("Background") as ColorRect
	if background != null:
		background.color = Color(0.030, 0.027, 0.024, 1.0)
	var glow: ColorRect = get_node_or_null("BackdropGlow") as ColorRect
	if glow != null:
		glow.color = Color(0.58, 0.34, 0.14, 0.07)

	var page_style: StyleBoxFlat = _make_panel_style(
		Color(0.083, 0.074, 0.061, 0.96),
		Color(0.76, 0.56, 0.28, 0.58),
		12,
		18
	)
	var card_style: StyleBoxFlat = _make_panel_style(
		Color(0.057, 0.052, 0.045, 0.96),
		Color(0.56, 0.39, 0.20, 0.48),
		12,
		14
	)
	var option_normal: StyleBoxFlat = _make_option_style(Color(0.103, 0.086, 0.063, 0.98), Color(0.70, 0.46, 0.20, 0.72))
	var option_hover: StyleBoxFlat = _make_option_style(Color(0.150, 0.112, 0.074, 0.99), Color(0.96, 0.66, 0.30, 0.96))
	var option_pressed: StyleBoxFlat = _make_option_style(Color(0.184, 0.124, 0.076, 0.99), Color(1.00, 0.76, 0.38, 1.0))
	_set_panel_style("MainMargin/RootColumn/TopLayout/Sidebar/SidebarStack/HeaderPanel", page_style)
	_set_panel_style("MainMargin/RootColumn/TopLayout/Sidebar/SidebarStack/StatsPanel", card_style)
	var stats_panel_for_style := _get_main_node("RootColumn/TopLayout/Sidebar/SidebarStack/StatsPanel") as PanelContainer
	if stats_panel_for_style == null and _situation_echo_row != null:
		stats_panel_for_style = _situation_echo_row.get_node_or_null("StatsPanel") as PanelContainer
	if stats_panel_for_style != null:
		stats_panel_for_style.add_theme_stylebox_override("panel", card_style)
	_set_panel_style("MainMargin/RootColumn/TopLayout/MainStage/StagePanel", page_style)
	_set_panel_style("MainMargin/RootColumn/TopLayout/MainStage/ChoicesPanel", card_style)
	if result_panel != null:
		result_panel.add_theme_stylebox_override("panel", card_style)

	for button in option_buttons:
		button.add_theme_stylebox_override("normal", option_normal)
		button.add_theme_stylebox_override("hover", option_hover)
		button.add_theme_stylebox_override("pressed", option_pressed)
		button.add_theme_stylebox_override("disabled", option_normal)
		button.add_theme_color_override("font_color", Color(0.86, 0.79, 0.64, 1.0))
		button.add_theme_color_override("font_hover_color", Color(0.95, 0.88, 0.70, 1.0))
		button.focus_mode = Control.FOCUS_NONE

	_set_label("MainMargin/RootColumn/TopLayout/Sidebar/SidebarStack/HeaderPanel/MarginContainer/HeaderVBox/TitleLabel", Color(0.96, 0.88, 0.68, 1.0), 31)
	_set_label("MainMargin/RootColumn/TopLayout/Sidebar/SidebarStack/HeaderPanel/MarginContainer/HeaderVBox/SubtitleLabel", Color(0.69, 0.62, 0.50, 1.0), 14)
	_set_label("MainMargin/RootColumn/TopLayout/MainStage/StagePanel/MarginContainer/StageVBox/StageHeader/ActionHint", Color(0.94, 0.83, 0.60, 1.0), 21)
	_set_label("MainMargin/RootColumn/TopLayout/MainStage/ChoicesPanel/MarginContainer/ChoicesVBox/ChoicesTitle", Color(0.94, 0.83, 0.60, 1.0), 19)
	var result_title := result_panel.get_node_or_null("MarginContainer/ResultVBox/ResultHeader/ResultTitle") as Label if result_panel != null else null
	if result_title != null:
		result_title.add_theme_color_override("font_color", Color(0.94, 0.83, 0.60, 1.0))
		result_title.add_theme_font_size_override("font_size", 17)
	_set_static_label_text("RootColumn/TopLayout/MainStage/StagePanel/MarginContainer/StageVBox/StageHeader/ActionHint", "晨占所见")
	_set_static_label_text("RootColumn/TopLayout/MainStage/StagePanel/MarginContainer/StageVBox/StageHeader/StageSubHint", "三道机缘，择一入局")
	_set_static_label_text("RootColumn/TopLayout/MainStage/ChoicesPanel/MarginContainer/ChoicesVBox/ChoicesTitle", "今日卦象")
	_set_body_label(player_state_label)
	_set_body_label(inventory_label)
	_set_body_label(selection_label)
	var sidebar_flavor: Label = _get_main_node("RootColumn/TopLayout/Sidebar/SidebarStack/SidebarFlavor") as Label
	if sidebar_flavor != null:
		sidebar_flavor.visible = true
		sidebar_flavor.text = "情报\n村口雾气未散，债主的眼线已经在路上。先活过今天，再谈明天。"
		sidebar_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sidebar_flavor.add_theme_color_override("font_color", Color(0.70, 0.63, 0.49, 0.86))
		sidebar_flavor.add_theme_font_size_override("font_size", 13)

	for option_label in option_rich_labels:
		option_label.add_theme_color_override("default_color", Color(0.83, 0.80, 0.70, 1.0))
		option_label.fit_content = false
		option_label.scroll_active = true
		option_label.mouse_filter = Control.MOUSE_FILTER_PASS
		option_label.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _make_panel_style(bg: Color, border: Color, radius: int, shadow_size: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0.0, 8.0)
	return style

func _make_option_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = _make_panel_style(bg, border, 8, 6)
	style.border_width_left = 5
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 18.0
	style.content_margin_top = 12.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 12.0
	return style

func _make_inventory_bag_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = _make_panel_style(
		Color(0.110, 0.070, 0.040, 1.0),
		Color(0.82, 0.56, 0.24, 1.0),
		8,
		18
	)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.content_margin_left = 8.0
	style.content_margin_top = 8.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 8.0
	return style

func _make_inventory_inner_style(bg: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = _make_panel_style(bg, Color(0.46, 0.31, 0.15, 1.0), 8, 4)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	return style

func _make_inventory_slot_style(border: Color, bg: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = _make_panel_style(bg, border, 6, 2)
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	return style

func _apply_solid_button_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.110, 0.090, 0.060, 1.0), Color(0.70, 0.48, 0.22, 1.0)))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.160, 0.120, 0.075, 1.0), Color(0.96, 0.66, 0.30, 1.0)))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.205, 0.140, 0.080, 1.0), Color(1.00, 0.76, 0.38, 1.0)))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.070, 0.064, 0.056, 1.0), Color(0.34, 0.28, 0.20, 1.0)))
	button.add_theme_color_override("font_color", Color(0.96, 0.88, 0.68, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.00, 0.94, 0.76, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.00, 0.86, 0.50, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.50, 0.42, 1.0))

func _make_button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 14.0
	style.content_margin_top = 7.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 7.0
	return style

func _set_panel_margins(path: NodePath, margin: int) -> void:
	var node: MarginContainer = _get_main_node(path) as MarginContainer
	if node == null:
		return
	node.add_theme_constant_override("margin_left", margin)
	node.add_theme_constant_override("margin_top", margin)
	node.add_theme_constant_override("margin_right", margin)
	node.add_theme_constant_override("margin_bottom", margin)

func _set_content_row_margins(button: Button, horizontal: float, vertical: float) -> void:
	var row: Control = button.get_node_or_null("ContentRow") as Control
	if row == null:
		return
	row.offset_left = horizontal
	row.offset_top = vertical
	row.offset_right = -horizontal
	row.offset_bottom = -vertical

func _on_option_text_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if index >= 0 and index < option_buttons.size() and option_buttons[index].visible and not option_buttons[index].disabled:
			_on_option_pressed(index)
			accept_event()

func _set_panel_style(path: NodePath, style: StyleBoxFlat) -> void:
	var panel: PanelContainer = _get_main_node(str(path).trim_prefix("MainMargin/")) as PanelContainer
	if panel != null:
		panel.add_theme_stylebox_override("panel", style)

func _set_label(path: NodePath, color: Color, size: int) -> void:
	var label: Label = _get_main_node(str(path).trim_prefix("MainMargin/")) as Label
	if label == null:
		return
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)

func _set_static_label_text(path: NodePath, text: String) -> void:
	var label: Label = _get_main_node(path) as Label
	if label != null:
		label.text = text

func _set_body_label(label: Label) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", Color(0.82, 0.79, 0.70, 1.0))
	label.add_theme_font_size_override("font_size", 15)

func _set_selection_text(text: String) -> void:
	_set_rich_text(_selection_rich, selection_label, text)

func _set_rich_text(rich: RichTextLabel, fallback: Label, text: String) -> void:
	if fallback != null:
		fallback.text = text
	if rich != null:
		rich.text = _enhance_text(text)

func _enhance_text(text: String) -> String:
	var result: String = text
	result = _colorize_rarity_prefixes(result)
	result = _colorize_keywords(result)
	result = result.replace("警示：", "[shake rate=18.0 level=4 connected=1][color=#D46E58][b]警示：[/b][/color][/shake]")
	result = result.replace("危险", "[shake rate=22.0 level=5 connected=1][color=#E25A4F][b]危险[/b][/color][/shake]")
	result = result.replace("结局触发", "[shake rate=18.0 level=5 connected=1][color=#E25A4F][b]结局触发[/b][/color][/shake]")
	result = result.replace("鉴定：", "[pulse freq=1.6 color=#F0C15A ease=-2.0][b]鉴定：[/b][/pulse]")
	result = result.replace("探索结果：", "[wave amp=18.0 freq=2.0 connected=1][color=#F0C15A][b]探索结果：[/b][/color][/wave]")
	result = result.replace("战利品：", "[color=#F0C15A][b]战利品：[/b][/color]")
	result = result.replace("今日卦象", "[wave amp=12.0 freq=2.0 connected=1][color=#E9D79A]今日卦象[/color][/wave]")
	return result

func _colorize_keywords(text: String) -> String:
	var result: String = text
	var keyword_colors: Dictionary = {
		"体力": "#AFC9D2",
		"健康": "#8DDB8A",
		"怀疑": "#C386BA",
		"村民关注": "#E0A05A",
		"粮食": "#DDBD72",
		"铜钱": "#E2B15A",
		"药草": "#98C96A",
		"肉": "#D28B6C",
		"欠债": "#E58B5A",
		"还债进度": "#E2B15A",
		"催债日": "#D46E58",
		"阶段": "#9EC8D5",
		"当前路线": "#CBB37A",
		"低风险": "#8DBB6C",
		"中风险": "#DCA347",
		"高风险": "#D46E58",
		"搜索": "#E9D79A",
		"撤离": "#8DBB6C",
		"敌人": "#D46E58",
		"山君": "#E25A4F",
		"黑熊": "#D46E58",
		"野狼": "#DCA347",
		"大野猪": "#DCA347"
	}
	for keyword_variant in keyword_colors.keys():
		var keyword: String = str(keyword_variant)
		result = result.replace(keyword, "[color=%s][b]%s[/b][/color]" % [str(keyword_colors[keyword]), keyword])
	return result

func _colorize_rarity_prefixes(text: String) -> String:
	var result: String = text
	var rarity_colors: Dictionary = {
		"【普通】": "#E8E1D2",
		"【优质】": "#7BCB79",
		"【稀有】": "#6FADEB",
		"【珍贵】": "#B783E6",
		"【传说】": "#F0C15A",
		"【神话】": "#E25A4F"
	}
	for prefix_variant in rarity_colors.keys():
		var prefix: String = str(prefix_variant)
		result = _colorize_rarity_token(result, prefix, str(rarity_colors[prefix]))
	return result

func _colorize_rarity_token(text: String, prefix: String, color_hex: String) -> String:
	var result: String = text
	var search_from: int = 0
	while true:
		var prefix_index: int = result.find(prefix, search_from)
		if prefix_index == -1:
			break
		var token_end: int = prefix_index + prefix.length()
		while token_end < result.length():
			var character: String = result.substr(token_end, 1)
			if character in [" ", "\n", "，", "。", "；", "：", "、", "）", ")", "]"]:
				break
			token_end += 1
		var token: String = result.substr(prefix_index, token_end - prefix_index)
		var colored_token: String = "[color=%s][b]%s[/b][/color]" % [color_hex, token]
		result = result.substr(0, prefix_index) + colored_token + result.substr(token_end)
		search_from = prefix_index + colored_token.length()
	return result

func _play_effect_feedback(applied_effects: Array) -> void:
	if _app == null or applied_effects.is_empty() or _feedback_layer == null:
		return
	_feedback_bubble_index = (_feedback_bubble_index + 1) % 100000
	var base_index := _feedback_bubble_index
	var shown := 0
	for effect_variant in applied_effects:
		var effect: Dictionary = effect_variant
		var feedback := _feedback_from_effect(effect)
		if feedback.is_empty():
			continue
		_spawn_feedback_card(
			str(feedback.get("text", "")),
			feedback.get("color", Color(0.92, 0.84, 0.62, 1.0)),
			bool(feedback.get("fly_to_bag", false)),
			bool(feedback.get("shake", false)),
			base_index + shown
		)
		if bool(feedback.get("scar", false)):
			_play_scar_flash()
		shown += 1
		if shown >= 4:
			break
	if shown > 0:
		_pulse_target(_inventory_button if _inventory_button != null else _inventory_rich)

func _play_manual_item_feedback(changes: Array) -> void:
	var effects: Array = []
	for change_variant in changes:
		var change: Dictionary = change_variant
		effects.append({
			"type": "item_delta",
			"target_id": str(change.get("id", "")),
			"value": int(change.get("value", 0))
		})
	_play_effect_feedback(effects)

func _feedback_from_effect(effect: Dictionary) -> Dictionary:
	var effect_type := str(effect.get("type", ""))
	var target_id := str(effect.get("target_id", ""))
	var value := int(effect.get("value", 0))
	match effect_type:
		"item_delta":
			if value == 0:
				return {}
			var item_name := _item_display_name(target_id)
			var item_color := _item_feedback_color(target_id)
			return {
				"text": "%s %s x%d" % ["获得" if value > 0 else "失去", item_name, abs(value)],
				"color": item_color if value > 0 else Color(0.86, 0.34, 0.28, 1.0),
				"fly_to_bag": value > 0,
				"shake": value < 0
			}
		"stat_delta":
			if value == 0:
				return {}
			var stat_name := _stat_display_name(target_id)
			var positive := value > 0
			return {
				"text": "%s %s %s%d" % [stat_name, "提升" if positive else "下降", "+" if positive else "", value],
				"color": _stat_feedback_color(target_id, positive),
				"fly_to_bag": false,
				"shake": not positive,
				"scar": target_id == "health" and value < 0
			}
		"set_flag":
			if not target_id.begins_with("cold_") and not _is_route_flag(target_id):
				return {}
			return {
				"text": "线索 %s" % _flag_display_name(target_id) if _is_route_flag(target_id) else "状态 %s" % _flag_display_name(target_id),
				"color": Color(0.90, 0.70, 0.35, 1.0) if _is_route_flag(target_id) else Color(0.72, 0.52, 0.92, 1.0),
				"fly_to_bag": false,
				"shake": not _is_route_flag(target_id),
				"scar": target_id == "cold_severe"
			}
		"clear_flag":
			if not target_id.begins_with("cold_"):
				return {}
			return {
				"text": "解除 %s" % _flag_display_name(target_id),
				"color": Color(0.50, 0.82, 0.50, 1.0),
				"fly_to_bag": false,
				"shake": false
			}
		"debt_delta":
			if value == 0:
				return {}
			return {
				"text": "欠债 %s%d" % ["+" if value > 0 else "", value],
				"color": Color(0.86, 0.34, 0.28, 1.0) if value > 0 else Color(0.90, 0.70, 0.35, 1.0),
				"fly_to_bag": false,
				"shake": value > 0
			}
		"relation_delta":
			if value == 0:
				return {}
			return {
				"text": "%s %s%d" % [_relation_display_name(target_id), "+" if value > 0 else "", value],
				"color": Color(0.68, 0.84, 0.52, 1.0) if value > 0 else Color(0.82, 0.42, 0.36, 1.0),
				"fly_to_bag": false,
				"shake": value < 0
			}
	return {}

func _relation_display_name(npc_id: String) -> String:
	match npc_id:
		"grocer":
			return "粮铺掌柜"
		"doctor":
			return "周郎中"
		"peddler":
			return "游货郎"
		"tea_oldman":
			return "茶棚老人"
		"porter":
			return "码头脚夫"
		_:
			return npc_id

func _spawn_feedback_card(text: String, color: Color, fly_to_bag: bool, shake: bool, index: int) -> void:
	if text.is_empty() or _feedback_layer == null:
		return
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.z_index = 90 + index
	card.modulate = Color(1.0, 1.0, 1.0, 0.0)
	card.scale = Vector2(0.86, 0.86)
	card.add_theme_stylebox_override("panel", _make_feedback_style(color, shake))
	_feedback_layer.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.99, 0.94, 0.80, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.015, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	margin.add_child(label)

	card.reset_size()
	var start := _feedback_bubble_start(index, card.size)
	card.position = start
	card.pivot_offset = card.size * 0.5

	if shake:
		_play_loss_shake(card, index)
	elif fly_to_bag:
		_play_fly_to_bag(card, color, index)
	else:
		_play_float_fade(card, index)

func _play_fly_to_bag(card: Control, color: Color, index: int) -> void:
	var bubble_delay := _feedback_delay(index)
	var hover := card.position + Vector2(0.0, -54.0)
	var target := _feedback_bag_center() - card.size * 0.35
	var tween := create_tween()
	tween.tween_interval(bubble_delay)
	tween.set_parallel(true)
	tween.tween_property(card, "modulate:a", 1.0, 0.12)
	tween.tween_property(card, "scale", Vector2(1.06, 1.06), 0.16)
	tween.tween_property(card, "position", hover, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(0.38)
	tween.set_parallel(true)
	tween.tween_property(card, "position", target, 0.54).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card, "scale", Vector2(0.42, 0.42), 0.50).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card, "modulate:a", 0.0, 0.16).set_delay(0.42)
	tween.finished.connect(func() -> void:
		if is_instance_valid(card):
			card.queue_free()
	)
	_spawn_bag_glow(color, bubble_delay + 1.08)

func _play_loss_shake(card: Control, index: int) -> void:
	var start := card.position
	var delay := _feedback_delay(index)
	var tween := create_tween()
	tween.tween_property(card, "modulate:a", 1.0, 0.08).set_delay(delay)
	tween.tween_property(card, "scale", Vector2(1.08, 1.08), 0.10)
	for offset in [Vector2(-10, 0), Vector2(12, 0), Vector2(-7, 0), Vector2(6, 0), Vector2.ZERO]:
		tween.tween_property(card, "position", start + offset, 0.045)
	tween.tween_interval(0.42)
	tween.tween_property(card, "modulate:a", 0.0, 0.18)
	tween.finished.connect(func() -> void:
		if is_instance_valid(card):
			card.queue_free()
	)
	_pulse_target(_player_state_rich)

func _play_float_fade(card: Control, index: int) -> void:
	var start := card.position
	var delay := _feedback_delay(index)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "modulate:a", 1.0, 0.12).set_delay(delay)
	tween.tween_property(card, "position", start + Vector2(0.0, -76.0), 1.18).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2(1.04, 1.04), 0.22).set_delay(delay)
	tween.tween_property(card, "modulate:a", 0.0, 0.24).set_delay(delay + 0.94)
	tween.finished.connect(func() -> void:
		if is_instance_valid(card):
			card.queue_free()
	)

func _play_scar_flash() -> void:
	if _feedback_layer == null:
		return
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	overlay.z_index = 120
	_feedback_layer.add_child(overlay)

	var wash := ColorRect.new()
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(0.58, 0.02, 0.0, 0.34)
	overlay.add_child(wash)

	var center := size * 0.5
	for idx in range(3):
		var slash := ColorRect.new()
		slash.color = Color(0.86, 0.05, 0.035, 0.72)
		slash.size = Vector2(260.0 - float(idx) * 42.0, 8.0)
		slash.position = center + Vector2(-126.0 + float(idx) * 44.0, -80.0 + float(idx) * 54.0)
		slash.rotation = -0.42
		overlay.add_child(slash)

	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.08)
	tween.tween_property(overlay, "modulate:a", 0.0, 0.46).set_delay(0.16)
	tween.finished.connect(func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free()
	)

func _spawn_bag_glow(color: Color, delay: float) -> void:
	if _inventory_button == null or _feedback_layer == null:
		return
	var button_rect := _inventory_button.get_global_rect()
	var layer_origin := _feedback_layer.get_global_rect().position
	var glow := PanelContainer.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.position = button_rect.position - layer_origin - Vector2(8.0, 8.0)
	glow.size = button_rect.size + Vector2(16.0, 16.0)
	glow.modulate = Color(1.0, 1.0, 1.0, 0.0)
	glow.add_theme_stylebox_override("panel", _make_feedback_style(color, false))
	_feedback_layer.add_child(glow)
	var tween := create_tween()
	tween.tween_property(glow, "modulate:a", 0.86, 0.10).set_delay(delay)
	tween.tween_property(glow, "scale", Vector2(1.12, 1.16), 0.18)
	tween.tween_property(glow, "modulate:a", 0.0, 0.24)
	tween.finished.connect(func() -> void:
		if is_instance_valid(glow):
			glow.queue_free()
	)

func _pulse_target(target: Control) -> void:
	if target == null:
		return
	var original := target.modulate
	var tween := create_tween()
	tween.tween_property(target, "modulate", Color(1.0, 0.88, 0.45, 1.0), 0.08)
	tween.tween_property(target, "modulate", original, 0.28)

func _make_feedback_style(color: Color, danger: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.046, 0.032, 0.94) if not danger else Color(0.16, 0.035, 0.025, 0.96)
	style.border_color = color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(color.r, color.g, color.b, 0.42)
	style.shadow_size = 12
	return style

func _feedback_scene_center() -> Vector2:
	var layer_origin := _feedback_layer.get_global_rect().position if _feedback_layer != null else Vector2.ZERO
	if main_stage != null:
		var rect := main_stage.get_global_rect()
		return rect.get_center() - layer_origin
	return size * 0.5

func _feedback_bubble_start(index: int, card_size: Vector2) -> Vector2:
	var layer_origin := _feedback_layer.get_global_rect().position if _feedback_layer != null else Vector2.ZERO
	var base_rect := result_panel.get_global_rect() if result_panel != null else Rect2(Vector2(size.x * 0.48, size.y * 0.62), Vector2(size.x * 0.42, 120.0))
	var slot := index % 7
	var column := int(index / 7) % 2
	var x := base_rect.position.x + base_rect.size.x - card_size.x - 34.0 - float(column) * 170.0
	var y := base_rect.position.y + 42.0 - float(slot) * 34.0
	x = clampf(x, 28.0, maxf(size.x - card_size.x - 28.0, 28.0))
	y = clampf(y, 94.0, maxf(size.y - card_size.y - 64.0, 94.0))
	return Vector2(x, y) - layer_origin

func _feedback_delay(index: int) -> float:
	return float(index % 10) * 0.14

func _feedback_bag_center() -> Vector2:
	var layer_origin := _feedback_layer.get_global_rect().position if _feedback_layer != null else Vector2.ZERO
	if _inventory_button != null:
		return _inventory_button.get_global_rect().get_center() - layer_origin
	if _inventory_rich != null:
		return _inventory_rich.get_global_rect().get_center() - layer_origin
	return Vector2(size.x - 88.0, 40.0)

func _item_display_name(item_id: String) -> String:
	if _app == null:
		return item_id
	var inventory_model: InventoryModel = _app.architecture.get_model(&"inventory")
	var definition: Dictionary = inventory_model.item_defs.get(item_id, {})
	return str(definition.get("name", item_id))

func _stat_display_name(stat_id: String) -> String:
	if _app == null:
		return stat_id
	var player_model: PlayerModel = _app.architecture.get_model(&"player")
	var definition: Dictionary = player_model.stat_defs.get(stat_id, {})
	return str(definition.get("name", stat_id))

func _flag_display_name(flag_id: String) -> String:
	if _app == null:
		return flag_id
	var flag_model: FlagModel = _app.architecture.get_model(&"flag")
	var definition: Dictionary = flag_model.flag_defs.get(flag_id, {})
	return str(definition.get("name", flag_id))

func _item_feedback_color(item_id: String) -> Color:
	if _app == null:
		return Color(0.90, 0.80, 0.58, 1.0)
	var inventory_model: InventoryModel = _app.architecture.get_model(&"inventory")
	var definition: Dictionary = inventory_model.item_defs.get(item_id, {})
	var rarity := str(definition.get("rarity", "common"))
	if str(definition.get("group", "resource")) == "resource":
		return _resource_color(item_id)
	return _rarity_color(rarity)

func _stat_feedback_color(stat_id: String, positive: bool) -> Color:
	if not positive:
		return Color(0.86, 0.34, 0.28, 1.0)
	match stat_id:
		"health":
			return Color(0.54, 0.86, 0.52, 1.0)
		"stamina":
			return Color(0.55, 0.76, 0.86, 1.0)
		"suspicion", "village_attention":
			return Color(0.72, 0.52, 0.92, 1.0)
		_:
			return Color(0.90, 0.80, 0.58, 1.0)

func _get_main_node(path: NodePath) -> Node:
	if main_margin != null:
		var node: Node = main_margin.get_node_or_null(path)
		if node != null:
			return node
	return get_node_or_null(path)

func _exit_tree() -> void:
	if _app == null:
		return
	_app.architecture.event_bus.unsubscribe(&"day_started", Callable(self, "_on_day_started"))
	_app.architecture.event_bus.unsubscribe(&"fortune_selected", Callable(self, "_on_fortune_selected"))
	_app.architecture.event_bus.unsubscribe(&"action_resolved", Callable(self, "_on_action_resolved"))
	_app.architecture.event_bus.unsubscribe(&"day_resolved", Callable(self, "_on_day_resolved"))
	_app.architecture.event_bus.unsubscribe(&"game_ended", Callable(self, "_on_game_ended"))

func _on_day_started(payload: Dictionary) -> void:
	var day_model: DayCycleModel = _app.architecture.get_model(&"day_cycle")
	var debt_model: DebtModel = _app.architecture.get_model(&"debt")
	day_label.text = "第%d/%d天" % [
		int(payload.get("day", 1)),
		day_model.max_day
	]
	var weather: Dictionary = payload.get("weather", {})
	_current_weather = weather
	_interaction_mode = "fortune"
	_last_action_summary = ""
	_reset_fortune_choice_state(true)
	choices_panel.visible = true
	if _exploration_board != null:
		_exploration_board.visible = false
	if _town_board != null:
		_town_board.visible = false
	weather_label.text = "天气：%s  阶段：%s" % [
		str(weather.get("name", "未知")),
		str(payload.get("phase", "morning"))
	]
	var options: Array = payload.get("options", [])
	scene_illustration.set_context(
		str(weather.get("id", "clear")),
		str(payload.get("phase", "morning")),
		_pick_focus_location(options)
	)
	for index in option_buttons.size():
		var button: Button = option_buttons[index]
		var option_label: RichTextLabel = option_rich_labels[index]
		var option_illustration: OptionIllustration = option_illustrations[index]
		var option_backdrop = _option_backdrops[index] if index < _option_backdrops.size() else null
		if index < options.size():
			var option: Dictionary = options[index]
			button.visible = true
			button.disabled = false
			button.modulate = Color.WHITE
			button.text = ""
			option_label.bbcode_enabled = true
			option_label.text = _build_option_markup(option, weather)
			option_label.scroll_to_line(0)
			option_illustration.set_context(
				str(option.get("location_id", "field")),
				str(option.get("risk_desc", "")),
				str(option.get("reward_desc", ""))
			)
			if option_backdrop != null:
				option_backdrop.visible = true
				option_backdrop.set_context(
					str(option.get("location_id", "field")),
					str(option.get("risk_desc", ""))
				)
		else:
			button.visible = false
			button.modulate = Color.WHITE
			option_label.text = ""
			if option_backdrop != null:
				option_backdrop.visible = false
	next_day_button.visible = false
	next_day_button.disabled = true
	_set_selection_text("目标：活到还清债务为止\n%s\n请选择今日行动（当前欠债：%d）" % [
		_get_route_hint(),
		debt_model.get_value("current")
	])
	_refresh_status()
	_sync_quick_action_buttons()

func _on_option_pressed(index: int) -> void:
	if _app == null:
		return
	if _interaction_mode != "fortune":
		return
	_set_pending_option(index)

func _set_pending_option(index: int) -> void:
	_pending_option_index = index
	for i in option_buttons.size():
		var button := option_buttons[i]
		button.disabled = false
		button.modulate = Color(1.0, 0.96, 0.78, 1.0) if i == index else Color(0.66, 0.62, 0.54, 0.78)
		if i < _option_confirm_boxes.size():
			_option_confirm_boxes[i].visible = i == index
	var fortune_model: FortuneSelectionModel = _app.architecture.get_model(&"fortune")
	var options := fortune_model.options
	var option: Dictionary = options[index] if index >= 0 and index < options.size() else {}
	var title := str(option.get("omen_title", option.get("title", "此卦")))
	_set_selection_text("你抽出了「%s」。确认后才会定卦；若还想换，点右侧取消或改选另一签。" % title)

func _on_option_cancel_pressed(index: int) -> void:
	if _interaction_mode != "fortune":
		return
	if _pending_option_index != index:
		return
	_pending_option_index = -1
	for i in option_buttons.size():
		option_buttons[i].disabled = false
		option_buttons[i].modulate = Color.WHITE
		if i < _option_confirm_boxes.size():
			_option_confirm_boxes[i].visible = false
	_set_selection_text("已放回卦签。请选择今日行动。")

func _on_option_confirm_pressed(index: int) -> void:
	if _app == null or _interaction_mode != "fortune":
		return
	if _pending_option_index != index:
		_set_pending_option(index)
		return
	_interaction_mode = "selecting"
	for button in option_buttons:
		button.disabled = true
	for box in _option_confirm_boxes:
		box.visible = false
	_sync_quick_action_buttons()
	var fortune_model: FortuneSelectionModel = _app.architecture.get_model(&"fortune")
	var options := fortune_model.options
	_confirmed_option = options[index].duplicate(true) if index >= 0 and index < options.size() else {}
	_set_selection_text("卦签已定，正在收束今日机缘……")
	await _play_fortune_confirm_effect(index)
	_app.architecture.command_dispatcher.dispatch(preload("res://scripts/command/SelectFortuneCommand.gd"), {"index": index})

func _play_fortune_confirm_effect(index: int) -> void:
	if index < 0 or index >= option_buttons.size():
		return
	var selected_button := option_buttons[index]
	if _fortune_effect_layer != null:
		_fortune_effect_layer.emit_confirm_sparks(selected_button.get_global_rect())
	for i in option_buttons.size():
		if i == index or not option_buttons[i].visible:
			continue
		if _fortune_effect_layer != null:
			_fortune_effect_layer.emit_dissolve(option_buttons[i].get_global_rect(), Color(0.68, 0.58, 0.42, 1.0))
		var fade_tween := create_tween()
		fade_tween.tween_property(option_buttons[i], "modulate", Color(0.72, 0.68, 0.60, 0.0), 0.44)
	_spawn_flying_omen_token(selected_button)
	await get_tree().create_timer(0.62).timeout

func _spawn_flying_omen_token(source: Control) -> void:
	if source == null or _omen_token_button == null:
		return
	var source_rect := source.get_global_rect()
	var local_start := get_global_transform().affine_inverse() * source_rect.position
	var target_rect := _omen_token_button.get_global_rect()
	var local_target := get_global_transform().affine_inverse() * target_rect.position
	var slip: Button = FortuneSlipTokenButtonScript.new()
	slip.name = "FlyingOmenSlip"
	slip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slip.position = local_start
	slip.size = Vector2(minf(source_rect.size.x, 300.0), 56.0)
	slip.pivot_offset = slip.size * 0.5
	slip.z_index = 85
	slip.modulate = Color(1.0, 0.96, 0.78, 1.0)
	slip.text = "定卦 · %s" % str(_confirmed_option.get("omen_title", _confirmed_option.get("title", "未知卦象")))
	slip.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	slip.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	slip.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	slip.add_theme_color_override("font_color", Color(0.20, 0.10, 0.035, 1.0))
	slip.add_theme_color_override("font_outline_color", Color(0.96, 0.78, 0.42, 0.78))
	slip.add_theme_constant_override("outline_size", 2)
	slip.add_theme_font_size_override("font_size", 17)
	add_child(slip)
	move_child(slip, get_child_count() - 1)
	_omen_token_button.visible = false
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(slip, "position", local_target, 0.58).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(slip, "scale", Vector2(0.58, 0.68), 0.58).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(slip, "modulate:a", 0.0, 0.18).set_delay(0.46)
	tween.finished.connect(func() -> void:
		if is_instance_valid(slip):
			slip.queue_free()
		_show_omen_token()
	)

func _show_omen_token() -> void:
	if _omen_token_button == null:
		return
	var title := str(_confirmed_option.get("omen_title", _confirmed_option.get("title", "已定卦")))
	_omen_token_button.text = "定卦 · %s" % title
	_omen_token_button.visible = true
	_omen_token_button.modulate = Color(1.0, 0.96, 0.72, 1.0)
	if _omen_token_tween != null:
		_omen_token_tween.kill()
	_omen_token_tween = create_tween()
	_omen_token_tween.set_loops()
	_omen_token_tween.tween_property(_omen_token_button, "modulate", Color(1.0, 0.82, 0.34, 1.0), 0.62)
	_omen_token_tween.tween_property(_omen_token_button, "modulate", Color(1.0, 1.0, 0.82, 1.0), 0.62)

func _on_omen_token_pressed() -> void:
	if _confirmed_option.is_empty() or _omen_detail_overlay == null or _omen_detail_text == null:
		return
	var verdict := _fortune_verdict(_confirmed_option, _current_weather)
	_omen_detail_text.text = "[font_size=21][color=#F0C15A][b]%s[/b][/color][/font_size]\n[color=%s][b]%s[/b][/color]  [color=#D8CFAE]%s[/color]\n\n[color=#A97B3E]所指[/color] [color=#E8DDC2]%s[/color]\n[color=#A97B3E]可得[/color] [color=#D7CFBB]%s[/color]\n[color=#7E8190]忌[/color] [color=#CDBFA0]%s[/color]\n\n[color=#B9AD8D]%s[/color]" % [
		str(_confirmed_option.get("omen_title", _confirmed_option.get("title", "未知卦象"))),
		str(verdict.get("color", "#D8CFAE")),
		str(verdict.get("grade", "平")),
		str(verdict.get("text", "")),
		str(_confirmed_option.get("omen_place", _location_name(str(_confirmed_option.get("location_id", "field"))))),
		_style_reward_text(str(_confirmed_option.get("omen_gain", _confirmed_option.get("reward_desc", "-")))),
		str(_confirmed_option.get("omen_warning", _confirmed_option.get("risk_desc", "-"))),
		str(_confirmed_option.get("omen_text", "命象不明，只见雾中一线。"))
	]
	_omen_detail_overlay.visible = true

func _reset_fortune_choice_state(hide_token: bool = false) -> void:
	_pending_option_index = -1
	for i in option_buttons.size():
		option_buttons[i].modulate = Color.WHITE
		if i < _option_confirm_boxes.size():
			_option_confirm_boxes[i].visible = false
	if hide_token:
		_confirmed_option.clear()
		if _omen_token_tween != null:
			_omen_token_tween.kill()
			_omen_token_tween = null
		if _omen_token_button != null:
			_omen_token_button.visible = false
		if _omen_detail_overlay != null:
			_omen_detail_overlay.visible = false

func _refresh_inventory_overlay() -> void:
	if _app == null or _inventory_content == null or _inventory_resource_list == null or _inventory_loot_grid == null:
		return
	var inventory_model: InventoryModel = _app.architecture.get_model(&"inventory")
	var resource_order: Array[String] = ["food", "money", "herb", "meat"]
	_clear_children(_inventory_resource_list)
	_clear_children(_inventory_loot_grid)
	for item_id in resource_order:
		var definition: Dictionary = inventory_model.item_defs.get(item_id, {})
		var name: String = str(definition.get("name", item_id))
		_inventory_resource_list.add_child(_make_inventory_resource_row(name, inventory_model.get_amount(item_id), item_id))

	var loot_entries: Array[Dictionary] = []
	for item_id_variant in inventory_model.items.keys():
		var item_id: String = str(item_id_variant)
		if item_id in resource_order:
			continue
		var amount: int = inventory_model.get_amount(item_id)
		if amount <= 0:
			continue
		var definition: Dictionary = inventory_model.item_defs.get(item_id, {})
		var entry: Dictionary = definition.duplicate(true)
		entry["id"] = item_id
		entry["amount"] = amount
		loot_entries.append(entry)
	loot_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var rarity_a: int = _rarity_rank(str(a.get("rarity", "common")))
		var rarity_b: int = _rarity_rank(str(b.get("rarity", "common")))
		if rarity_a == rarity_b:
			return int(a.get("sell_value", 0)) > int(b.get("sell_value", 0))
		return rarity_a > rarity_b
	)

	_inventory_empty_label.visible = loot_entries.is_empty()
	for entry in loot_entries:
		_inventory_loot_grid.add_child(_make_inventory_slot(entry))
	_inventory_content.text = _enhance_text("[color=#8F8774]包袱空间有限，值钱物最好去镇上货郎摊出手；粮食和药草放在贴身小袋，外出前先看余量。[/color]")

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _make_inventory_icon_node(item_id: String, tint: Color, icon_size: float = 42.0, fallback_group: String = "") -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(icon_size, icon_size)
	frame.add_theme_stylebox_override("panel", _make_inventory_slot_style(tint, Color(0.026, 0.023, 0.020, 1.0)))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 3)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_right", 3)
	margin.add_theme_constant_override("margin_bottom", 3)
	frame.add_child(margin)

	var texture := _item_icon_texture(item_id)
	if texture != null:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(icon_size - 6.0, icon_size - 6.0)
		icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		margin.add_child(icon)
		icon.texture = texture
		return frame

	var fallback := Label.new()
	fallback.text = _inventory_icon(fallback_group)
	if fallback.text.is_empty():
		fallback.text = item_id.substr(0, 1)
	fallback.custom_minimum_size = Vector2(icon_size - 6.0, icon_size - 6.0)
	fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback.add_theme_font_size_override("font_size", int(icon_size * 0.52))
	fallback.add_theme_color_override("font_color", tint)
	margin.add_child(fallback)
	return frame

func _item_icon_texture(item_id: String) -> Texture2D:
	if item_id.is_empty():
		return null
	if _item_icon_textures.has(item_id):
		return _item_icon_textures[item_id] as Texture2D
	var texture := _load_texture_from_file("res://assets/generated/ui/items/%s.jpg" % item_id)
	_item_icon_textures[item_id] = texture
	return texture

func _load_texture_from_file(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var imported_texture: Texture2D = ResourceLoader.load(path) as Texture2D
		if imported_texture != null:
			return imported_texture
	var image_path: String = path
	if not FileAccess.file_exists(image_path):
		image_path = ProjectSettings.globalize_path(path)
	var image: Image = Image.load_from_file(image_path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)

func _make_inventory_resource_row(name: String, amount: int, item_id: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 58.0)
	panel.add_theme_stylebox_override("panel", _make_inventory_slot_style(_resource_color(item_id), Color(0.055, 0.043, 0.032, 1.0)))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	row.add_child(_make_inventory_icon_node(item_id, _resource_color(item_id), 38.0))

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)

	var name_label := Label.new()
	name_label.text = name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.92, 0.84, 0.66, 1.0))
	text_box.add_child(name_label)

	var amount_label := Label.new()
	amount_label.text = "余量：%d" % amount
	amount_label.add_theme_font_size_override("font_size", 18)
	amount_label.add_theme_color_override("font_color", _resource_color(item_id))
	text_box.add_child(amount_label)
	return panel

func _make_inventory_slot(entry: Dictionary) -> Control:
	var rarity: String = str(entry.get("rarity", "common"))
	var rarity_color: Color = _rarity_color(rarity)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(178.0, 126.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_inventory_slot_style(rarity_color, Color(0.050, 0.042, 0.033, 1.0)))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 5)
	margin.add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)

	top.add_child(_make_inventory_icon_node(str(entry.get("id", "")), rarity_color, 42.0, str(entry.get("group", ""))))

	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("normal_font_size", 15)
	title.text = "[color=%s][b]%s%s[/b][/color] x%d" % [
		_rarity_color_hex(rarity),
		_rarity_prefix(rarity),
		str(entry.get("name", entry.get("id", "未知物品"))),
		int(entry.get("amount", 0))
	]
	top.add_child(title)

	var value := Label.new()
	value.text = "估值：%d铜钱" % int(entry.get("sell_value", 0))
	value.add_theme_font_size_override("font_size", 13)
	value.add_theme_color_override("font_color", Color(0.88, 0.68, 0.36, 1.0))
	root.add_child(value)

	var desc := Label.new()
	desc.text = str(entry.get("description", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.66, 0.61, 0.50, 1.0))
	root.add_child(desc)

	var passive_text := str(entry.get("passive", ""))
	if not passive_text.is_empty():
		var passive := Label.new()
		passive.text = "被动：%s" % passive_text
		passive.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		passive.add_theme_font_size_override("font_size", 12)
		passive.add_theme_color_override("font_color", Color(0.72, 0.82, 0.56, 1.0))
		root.add_child(passive)

	var equip_slot := _equipment_slot(str(entry.get("id", "")))
	if not equip_slot.is_empty():
		var equip_button := Button.new()
		equip_button.text = "卸下" if _is_item_equipped(str(entry.get("id", ""))) else "装备"
		equip_button.custom_minimum_size = Vector2(0.0, 30.0)
		equip_button.focus_mode = Control.FOCUS_NONE
		_apply_solid_button_style(equip_button)
		equip_button.pressed.connect(_on_inventory_toggle_equip.bind(str(entry.get("id", ""))))
		root.add_child(equip_button)

	var use_config: Dictionary = entry.get("use", {})
	if not use_config.is_empty():
		var use_button := Button.new()
		use_button.text = str(use_config.get("label", "使用"))
		use_button.custom_minimum_size = Vector2(0.0, 30.0)
		use_button.focus_mode = Control.FOCUS_NONE
		_apply_solid_button_style(use_button)
		use_button.pressed.connect(_on_inventory_use_item.bind(str(entry.get("id", ""))))
		root.add_child(use_button)
	return panel

func _on_inventory_use_item(item_id: String) -> void:
	if _app == null or item_id.is_empty():
		return
	var inventory_model: InventoryModel = _app.architecture.get_model(&"inventory")
	if inventory_model.get_amount(item_id) <= 0:
		_set_selection_text("包里已经没有这件东西。\n%s" % _get_progress_summary())
		_refresh_inventory_overlay()
		return
	var definition: Dictionary = inventory_model.item_defs.get(item_id, {})
	var use_config: Dictionary = definition.get("use", {})
	if use_config.is_empty():
		return
	var effect_ids: Array = use_config.get("effects", [])
	var effect_system: EffectSystem = _app.architecture.get_system(&"effect")
	var applied_effects: Array = effect_system.apply_effects(effect_ids)
	_play_effect_feedback(applied_effects)
	_set_selection_text("%s\n%s" % [str(use_config.get("text", "你使用了%s。" % str(definition.get("name", item_id)))), _get_progress_summary()])
	_refresh_inventory_overlay()
	_refresh_status()

func _on_inventory_toggle_equip(item_id: String) -> void:
	if _app == null or item_id.is_empty():
		return
	var inventory_model: InventoryModel = _app.architecture.get_model(&"inventory")
	if inventory_model.get_amount(item_id) <= 0:
		_set_selection_text("包里已经没有这件装备。\n%s" % _get_progress_summary())
		_refresh_inventory_overlay()
		return
	var flag_model: FlagModel = _app.architecture.get_model(&"flag")
	var slot := _equipment_slot(item_id)
	if slot.is_empty():
		return
	if _is_item_equipped(item_id):
		flag_model.set_flag(_equipment_flag(item_id), false)
		_set_selection_text("你卸下%s。\n%s" % [_item_display_name(item_id), _get_progress_summary()])
	else:
		for other_id in _equipment_items_for_slot(slot):
			flag_model.set_flag(_equipment_flag(other_id), false)
		flag_model.set_flag(_equipment_flag(item_id), true)
		_set_selection_text("你装备%s。\n%s" % [_item_display_name(item_id), _get_progress_summary()])
	_sync_active_board_context()
	_refresh_inventory_overlay()
	_refresh_status()

func _sync_active_board_context() -> void:
	if _app == null:
		return
	var inventory_model: InventoryModel = _app.architecture.get_model(&"inventory")
	var flag_model: FlagModel = _app.architecture.get_model(&"flag")
	if _exploration_board != null and _exploration_board.visible:
		_exploration_board.update_context(inventory_model.items, flag_model.flags)

func _clear_equipment_if_missing(item_id: String) -> void:
	if _app == null or _equipment_slot(item_id).is_empty():
		return
	var inventory_model: InventoryModel = _app.architecture.get_model(&"inventory")
	if inventory_model.get_amount(item_id) > 0:
		return
	var flag_model: FlagModel = _app.architecture.get_model(&"flag")
	flag_model.set_flag(_equipment_flag(item_id), false)
	_sync_active_board_context()

func _is_item_equipped(item_id: String) -> bool:
	if _app == null:
		return false
	var flag_model: FlagModel = _app.architecture.get_model(&"flag")
	return flag_model.get_flag(_equipment_flag(item_id))

func _equipment_flag(item_id: String) -> String:
	return "equip_%s" % item_id

func _equipment_slot(item_id: String) -> String:
	match item_id:
		"old_hunter_knife", "black_iron_shortblade":
			return "weapon"
		"wolf_pelt_complete":
			return "cloak"
		"tiger_bone", "ancient_bone_token":
			return "charm"
		_:
			return ""

func _equipment_items_for_slot(slot: String) -> Array[String]:
	match slot:
		"weapon":
			return ["old_hunter_knife", "black_iron_shortblade"]
		"cloak":
			return ["wolf_pelt_complete"]
		"charm":
			return ["tiger_bone", "ancient_bone_token"]
		_:
			return []

func _on_inventory_button_pressed() -> void:
	if _app == null:
		return
	_refresh_inventory_overlay()
	move_child(_inventory_overlay, get_child_count() - 1)
	_inventory_overlay.visible = true

func _on_clue_button_pressed() -> void:
	if _app == null:
		return
	_refresh_clue_overlay()
	move_child(_clue_overlay, get_child_count() - 1)
	_clue_overlay.visible = true

func _refresh_clue_overlay() -> void:
	if _app == null or _clue_board == null:
		return
	var flag_model: FlagModel = _app.architecture.get_model(&"flag")
	_clue_board.set_flags(flag_model.flags)

func _on_clue_deduction_requested(effect_ids: Array, summary: String) -> void:
	_apply_exploration_effects(effect_ids)
	_refresh_clue_overlay()
	_refresh_status()
	_set_selection_text("%s\n%s" % [summary, _get_progress_summary()])

func _on_town_button_pressed() -> void:
	if _app == null:
		return
	if _interaction_mode != "fortune":
		_set_selection_text("今日行动已经开始，不能再改去城镇。\n%s" % _get_progress_summary())
		return
	var town_option := {
		"id": "direct_town_trip",
		"title": "去镇集低调买卖",
		"omen_title": "乡镇外出",
		"omen_text": "这不是卦象，而是你主动去镇上买卖和打探消息。",
		"omen_place": "乡镇集市",
		"omen_gain": "买粮、卖货、打听消息",
		"omen_warning": "不可露富，买卖太急会惹人记住",
		"location_id": "town",
		"reward_desc": "可买粮食药草，也能卖出战利品",
		"risk_desc": "中风险，人多眼杂"
	}
	for button in option_buttons:
		button.disabled = true
	_show_town_board(town_option)
	_refresh_status()
	_sync_quick_action_buttons()

func _on_next_day_pressed() -> void:
	if _app == null:
		return
	next_day_button.disabled = true
	next_day_button.visible = false
	if _town_button != null:
		_town_button.disabled = true
	var day_model: DayCycleModel = _app.architecture.get_model(&"day_cycle")
	day_model.next_day()
	_app.architecture.command_dispatcher.dispatch(preload("res://scripts/command/StartNewDayCommand.gd"))

func _on_fortune_selected(payload: Dictionary) -> void:
	var selected: Dictionary = payload.get("selected", {})
	if str(selected.get("location_id", "")) == "town":
		_show_town_board(selected)
	else:
		_show_exploration_board(selected)
	_refresh_status()

func _show_exploration_board(selected: Dictionary) -> void:
	_interaction_mode = "explore"
	_sync_quick_action_buttons()
	choices_panel.visible = false
	if _exploration_board == null:
		_ensure_exploration_board()
	_exploration_board.visible = true
	if _town_board != null:
		_town_board.visible = false
	var inventory_model: InventoryModel = _app.architecture.get_model(&"inventory")
	var flag_model: FlagModel = _app.architecture.get_model(&"flag")
	_exploration_board.configure(selected, _current_weather, inventory_model.items, flag_model.flags)
	scene_illustration.set_context(
		str(_current_weather.get("id", "clear")),
		"daytime",
		str(selected.get("location_id", "field"))
	)
	var verdict := _fortune_verdict(selected, _current_weather)
	_set_selection_text("已定卦：%s  【%s】%s\n卦象只给方向。你需要从入口出发，在格子地图中搜索、应对危险，并找到出口撤离。\n%s" % [
		str(selected.get("omen_title", selected.get("title", "未知卦象"))),
		str(verdict.get("grade", "平")),
		str(verdict.get("text", "")),
		_get_route_hint()
	])

func _show_town_board(selected: Dictionary) -> void:
	_interaction_mode = "town"
	_sync_quick_action_buttons()
	choices_panel.visible = false
	if _town_board == null:
		_ensure_town_board()
	if _exploration_board != null:
		_exploration_board.visible = false
	_town_board.visible = true
	var inventory_model: InventoryModel = _app.architecture.get_model(&"inventory")
	var relation_model: RefCounted = _app.architecture.get_model(&"relation")
	var flag_model: FlagModel = _app.architecture.get_model(&"flag")
	_town_board.configure(selected, inventory_model.item_defs, inventory_model.items, relation_model, flag_model.flags)
	scene_illustration.set_context(
		str(_current_weather.get("id", "clear")),
		"daytime",
		"field"
	)
	_set_selection_text("今日外出：%s\n这次不是卦象选择，而是主动去乡镇。你需要在镇图里移动到商铺、摊位或茶棚，买卖和对话后从镇口返村。\n%s" % [
		str(selected.get("omen_title", selected.get("title", "未知卦象"))),
		_get_route_hint()
	])

func _on_exploration_log_changed(text: String) -> void:
	_set_selection_text("%s\n%s" % [text, _get_progress_summary()])

func _on_exploration_loot_found(effect_ids: Array, summary: String) -> void:
	_apply_exploration_effects(effect_ids)
	_set_selection_text("%s\n%s" % [summary, _get_progress_summary()])
	_refresh_status()

func _on_exploration_danger_resolved(effect_ids: Array, summary: String) -> void:
	_apply_exploration_effects(effect_ids)
	_set_selection_text("%s\n%s" % [summary, _get_progress_summary()])
	_refresh_status()

func _on_exploration_extracted(summary: String) -> void:
	_interaction_mode = "resolved"
	_sync_quick_action_buttons()
	_last_action_summary = summary
	if _exploration_board != null:
		_exploration_board.visible = false
	_set_selection_text("%s\n正在回村结算。" % summary)
	_refresh_status()
	_app.architecture.command_dispatcher.dispatch(preload("res://scripts/command/ResolveDayCommand.gd"))

func _apply_exploration_effects(effect_ids: Array) -> void:
	if _app == null or effect_ids.is_empty():
		return
	var effect_system: EffectSystem = _app.architecture.get_system(&"effect")
	var applied_effects: Array = effect_system.apply_effects(effect_ids)
	_play_effect_feedback(applied_effects)

func _on_town_log_changed(text: String) -> void:
	_set_selection_text("%s\n%s" % [text, _get_progress_summary()])

func _on_town_buy_requested(item_id: String, cost: int, summary: String) -> void:
	var inventory_model: InventoryModel = _app.architecture.get_model(&"inventory")
	if inventory_model.get_amount("money") < cost:
		_set_selection_text("铜钱不够，买不起。\n%s" % _get_progress_summary())
		return
	inventory_model.add_item("money", -cost)
	inventory_model.add_item(item_id, 1)
	_town_board.update_inventory(inventory_model.item_defs, inventory_model.items)
	_set_selection_text("%s\n%s" % [summary, _get_progress_summary()])
	_play_manual_item_feedback([
		{"id": "money", "value": -cost},
		{"id": item_id, "value": 1}
	])
	_refresh_status()

func _on_town_sell_requested(item_id: String, value: int, summary: String) -> void:
	var inventory_model: InventoryModel = _app.architecture.get_model(&"inventory")
	if inventory_model.get_amount(item_id) <= 0:
		_set_selection_text("这件东西已经不在包里。\n%s" % _get_progress_summary())
		return
	inventory_model.add_item(item_id, -1)
	inventory_model.add_item("money", value)
	_clear_equipment_if_missing(item_id)
	_town_board.update_inventory(inventory_model.item_defs, inventory_model.items)
	_set_selection_text("%s\n%s" % [summary, _get_progress_summary()])
	_play_manual_item_feedback([
		{"id": item_id, "value": -1},
		{"id": "money", "value": value}
	])
	_refresh_status()

func _on_town_contact_unlocked(effect_ids: Array, summary: String) -> void:
	_apply_exploration_effects(effect_ids)
	_set_selection_text("%s\n%s" % [summary, _get_progress_summary()])
	_refresh_status()

func _on_town_task_started(_task_id: String, summary: String) -> void:
	_set_selection_text("%s\n%s" % [summary, _get_progress_summary()])
	_refresh_status()

func _on_town_task_completed(_task_id: String, effect_ids: Array, summary: String) -> void:
	_apply_exploration_effects(effect_ids)
	_set_selection_text("%s\n%s" % [summary, _get_progress_summary()])
	_refresh_status()

func _on_town_extracted(summary: String) -> void:
	_interaction_mode = "resolved"
	_sync_quick_action_buttons()
	_last_action_summary = summary
	if _town_board != null:
		_town_board.visible = false
	_set_selection_text("%s\n正在回村结算。" % summary)
	_refresh_status()
	_app.architecture.command_dispatcher.dispatch(preload("res://scripts/command/ResolveDayCommand.gd"))

func _on_action_resolved(payload: Dictionary) -> void:
	_interaction_mode = "resolved"
	_sync_quick_action_buttons()
	_last_action_summary = "%s：%s" % [
		str(payload.get("title", "未知行动")),
		str(payload.get("result_text", "今日无事发生"))
	]
	_set_selection_text("%s\n结果：%s\n%s" % [
		str(payload.get("title", "未知行动")),
		str(payload.get("result_text", "今日无事发生")),
		_get_progress_summary()
	])
	_refresh_status()

func _on_day_resolved(payload: Dictionary) -> void:
	_sync_quick_action_buttons()
	var lines: Array[String] = []
	if not _last_action_summary.is_empty():
		lines.append("探索结果：%s" % _last_action_summary)
	lines.append(_get_progress_summary())
	for rule_variant in payload.get("rules", []):
		var rule: Dictionary = rule_variant
		lines.append("日结算：%s" % str(rule.get("name", "未知规则")))
		_play_effect_feedback(rule.get("effects", []))
	var night_action: Dictionary = payload.get("night_action", {})
	if not night_action.is_empty():
		lines.append("夜间行动：%s" % str(night_action.get("result_text", "")))
		_play_effect_feedback(night_action.get("effects", []))
	var npc_event: Dictionary = payload.get("npc_event", {})
	if not npc_event.is_empty():
		lines.append("夜间事件：%s" % str(npc_event.get("result_text", "")))
		_play_effect_feedback(npc_event.get("effects", []))
	var ending: Dictionary = payload.get("ending", {})
	if not ending.is_empty():
		lines.append("结局触发：%s" % str(ending.get("title", "未知结局")))
		next_day_button.visible = false
		next_day_button.disabled = true
	else:
		lines.append(_get_end_of_day_outlook())
		var current_day: int = int(payload.get("day", 1))
		next_day_button.text = "第%d天" % [current_day + 1]
		next_day_button.visible = true
		next_day_button.disabled = false
	if not lines.is_empty():
		_set_selection_text("\n".join(lines))
	_refresh_status()

func _on_game_ended(payload: Dictionary) -> void:
	_interaction_mode = "ended"
	_sync_quick_action_buttons()
	_set_selection_text("游戏结束：%s\n%s" % [
		str(payload.get("title", "未知结局")),
		str(payload.get("description", ""))
	])
	next_day_button.visible = false
	next_day_button.disabled = true
	for button in option_buttons:
		button.disabled = true
	_refresh_status()

func _try_render_existing_day() -> void:
	if _app == null or _app.architecture == null:
		return
	var day_model: DayCycleModel = _app.architecture.get_model(&"day_cycle")
	var weather_model: WeatherModel = _app.architecture.get_model(&"weather")
	var fortune_model: FortuneSelectionModel = _app.architecture.get_model(&"fortune")
	if weather_model.current_weather.is_empty() and fortune_model.options.is_empty():
		return
	_on_day_started({
		"day": day_model.current_day,
		"phase": day_model.current_phase,
		"weather": weather_model.current_weather,
		"options": fortune_model.options
	})

func _refresh_status() -> void:
	if _app == null:
		return
	var player_model: PlayerModel = _app.architecture.get_model(&"player")
	var inventory_model: InventoryModel = _app.architecture.get_model(&"inventory")
	var flag_model: FlagModel = _app.architecture.get_model(&"flag")
	var debt_model: DebtModel = _app.architecture.get_model(&"debt")
	var day_model: DayCycleModel = _app.architecture.get_model(&"day_cycle")
	var relation_model: RefCounted = _app.architecture.get_model(&"relation")
	var stat_order: Array = _ui_config.get("player_stat_order", [])
	var inventory_order: Array = _ui_config.get("inventory_item_order", [])
	var player_text: String = _format_display_entries(player_model.get_display_value_map(stat_order))
	var flag_text: String = _format_display_entries(flag_model.get_display_entries())
	var warning_text: String = _get_warning_summary(player_model, inventory_model, debt_model, day_model)
	var player_display_text: String = player_text
	if not warning_text.is_empty():
		player_display_text += "\n警示：%s" % warning_text
	if not flag_text.is_empty():
		player_display_text += "\n标记：%s" % flag_text
	var relation_text := _format_display_entries(relation_model.get_display_entries())
	if not relation_text.is_empty():
		player_display_text += "\n人脉：%s" % relation_text
	_set_rich_text(_player_state_rich, player_state_label, player_display_text)
	var special_inventory_text: String = _get_special_inventory_summary(inventory_model)
	var equipment_text := _get_equipment_summary()
	var debt_pressure := _get_debt_pressure_label(debt_model, day_model)
	var inventory_display_text: String = "%s\n阶段：%s    欠债：%d/%d    催债日：%d    债压：%s\n%s" % [
		_format_display_entries(inventory_model.get_display_value_map(inventory_order)),
		day_model.current_phase,
		debt_model.get_value("current"),
		debt_model.get_value("initial"),
		debt_model.get_value("due_day"),
		debt_pressure,
		_get_progress_summary()
	]
	if not equipment_text.is_empty():
		inventory_display_text += "\n装备：%s" % equipment_text
	if not special_inventory_text.is_empty():
		inventory_display_text += "\n战利品：%s" % special_inventory_text
	_set_rich_text(_inventory_rich, inventory_label, inventory_display_text)

func _get_route_hint() -> String:
	if _app == null:
		return "路线未定"
	var flag_model: FlagModel = _app.architecture.get_model(&"flag")
	if flag_model.get_flag("deduced_old_goods_line"):
		return "当前路线：旧物暗价已推断清楚，搜旧物和卖战利品更稳"
	if flag_model.get_flag("deduced_old_well_route"):
		return "当前路线：旧井藏路已推断清楚，夜探旧井时更少走弯路"
	if flag_model.get_flag("deduced_support_network"):
		return "当前路线：互助补给网已推断清楚，粮药和城镇人情更便宜更稳"
	if flag_model.get_flag("deduced_debt_timing"):
		return "当前路线：催债节奏已推断清楚，茶棚和渡口消息更有价值"
	if flag_model.get_flag("deduced_grave_cache"):
		return "当前路线：荒坟旧藏已推断清楚，深挖旧藏更有把握"
	if flag_model.get_flag("deduced_hunter_route"):
		return "当前路线：猎户伏兽路已推断清楚，山林遇兽和设伏更稳"
	if flag_model.get_flag("soldier_relic_clue"):
		return "当前路线：私印暗记已经对上旧营地，可追军中遗物但风险很高"
	if flag_model.get_flag("jade_buyer_clue") and not flag_model.get_flag("met_jade_buyer"):
		return "当前路线：残玉有暗买家，后续可去茶摊碰线"
	if flag_model.get_flag("met_jade_buyer"):
		return "当前路线：已接上残玉买家，旧玉旧物可换更隐秘的收益"
	if flag_model.get_flag("black_market_fence_line"):
		return "当前路线：夜市暗线已接上，高值旧物能更快变现但很招眼"
	if flag_model.get_flag("peddler_old_goods_contact"):
		return "当前路线：货郎旧物暗线已打开，可把旧物换成更高收益"
	if flag_model.get_flag("support_network_built"):
		return "当前路线：村镇互助网已成形，低风险粮药和人情更稳定"
	if flag_model.get_flag("grocer_grain_contact"):
		return "当前路线：粮铺后门已熟，缺粮时可走暗粮线"
	if flag_model.get_flag("doctor_medicine_contact"):
		return "当前路线：周郎中药路已熟，治寒和换药更稳定"
	if flag_model.get_flag("tea_debt_contact"):
		return "当前路线：茶棚能探债主动向，适合规避催债风险"
	if flag_model.get_flag("porter_ferry_contact"):
		return "当前路线：渡口脚夫给了零活，稳定小钱但注意湿寒"
	if flag_model.get_flag("old_well_watchman_deal"):
		return "当前路线：旧井守夜人口风已压住，夜探收益更稳但仍会招眼"
	if flag_model.get_flag("old_well_line"):
		return "当前路线：旧井夜路已经接上，能摸高值旧物但非常招眼"
	if flag_model.get_flag("old_well_clue"):
		return "当前路线：村后废井有暗藏线索，可夜探但要准备退路"
	if flag_model.get_flag("hunter_trap_line"):
		return "当前路线：猎户设伏门路成形，密林肉食线更稳定"
	if flag_model.get_flag("villager_aid_line"):
		return "当前路线：村人互助线已接上，可换粮食与小工钱"
	if flag_model.get_flag("found_hidden_stash"):
		return "当前路线：坟地线索已兑现，适合尽快转化收益还债"
	if flag_model.get_flag("unlocked_errand_route"):
		return "当前路线：已打开跑腿门路，可走稳健赚钱线"
	if flag_model.get_flag("saw_graveyard_cache"):
		return "当前路线：坟地线索已发现，可继续冒险深挖"
	if flag_model.get_flag("earned_villager_trust"):
		return "当前路线：已取得部分信任，稳健路线正在成形"
	return "当前路线：可选冒险找线索，或先靠低风险行动稳住资源"

func _get_progress_summary() -> String:
	if _app == null:
		return ""
	var debt_model: DebtModel = _app.architecture.get_model(&"debt")
	var current_debt: int = debt_model.get_value("current")
	var initial_debt: int = maxi(debt_model.get_value("initial"), 1)
	var repaid: int = maxi(initial_debt - current_debt, 0)
	var echoes := _get_consequence_echoes()
	var debt_pressure := _get_debt_pressure_label(debt_model, _app.architecture.get_model(&"day_cycle"))
	if echoes.is_empty():
		return "还债进度：%d/%d    债压：%s    %s\n阶段目标：%s" % [repaid, initial_debt, debt_pressure, _get_route_hint(), _get_stage_goal()]
	return "还债进度：%d/%d    债压：%s    %s\n阶段目标：%s\n回响：%s" % [repaid, initial_debt, debt_pressure, _get_route_hint(), _get_stage_goal(), " / ".join(echoes)]

func _get_consequence_echoes() -> Array[String]:
	var echoes: Array[String] = []
	if _app == null:
		return echoes
	var flag_model: FlagModel = _app.architecture.get_model(&"flag")
	var player_model: PlayerModel = _app.architecture.get_model(&"player")
	var inventory_model: InventoryModel = _app.architecture.get_model(&"inventory")
	var relation_model: RefCounted = _app.architecture.get_model(&"relation")
	var debt_model: DebtModel = _app.architecture.get_model(&"debt")
	var day_model: DayCycleModel = _app.architecture.get_model(&"day_cycle")
	var debt_stage := _get_debt_pressure_stage(debt_model, day_model)
	match debt_stage:
		"overdue":
			echoes.append("债期已过，催债人会更常上门")
		"critical":
			echoes.append("债压失控，钱粮和人脉都会被催债拖累")
		"due":
			echoes.append("催债日贴脸，今明两天必须处理还钱或避债")
		"near":
			echoes.append("催债临近，最好提前变现或探风")
	if flag_model.get_flag("cold_severe"):
		echoes.append("重寒会持续伤身，必须尽快治")
	elif flag_model.get_flag("cold_worse"):
		echoes.append("寒症正在加重，药草或清露苔能救急")
	elif flag_model.get_flag("cold_mild"):
		echoes.append("染寒未清，拖到夜里可能恶化")
	if flag_model.get_flag("jade_buyer_clue") and inventory_model.get_amount("broken_jade_button") > 0:
		echoes.append("残玉扣可引出茶摊买家")
	if flag_model.get_flag("soldier_relic_clue") and inventory_model.get_amount("soldier_hidden_seal") > 0:
		echoes.append("逃兵私印指向旧营土垒")
	if flag_model.get_flag("studied_bow_manual"):
		echoes.append("弓谱会提高遭遇野兽时的脱身机会")
	if flag_model.get_flag("equip_old_hunter_knife"):
		echoes.append("旧猎刀已装备，遇兽更容易脱身")
	if flag_model.get_flag("equip_black_iron_shortblade"):
		echoes.append("黑铁短刃已装备，逼退威胁更强但更惹眼")
	if flag_model.get_flag("equip_wolf_pelt_complete"):
		echoes.append("完整狼皮已披，水边和寒地更稳")
	if flag_model.get_flag("equip_tiger_bone") or flag_model.get_flag("equip_ancient_bone_token"):
		echoes.append("护身旧物已佩，能压住一部分疑心和惊惧")
	if flag_model.get_flag("earned_villager_trust") or flag_model.get_flag("villager_aid_line"):
		echoes.append("村人信任能转成低风险粮钱")
	if flag_model.get_flag("support_network_built"):
		echoes.append("村镇互助网能稳定补粮药")
	if flag_model.get_flag("grocer_grain_contact"):
		echoes.append("粮铺后门能稳定补粮")
	if flag_model.get_flag("doctor_medicine_contact"):
		echoes.append("周郎中药路能压寒症")
	if flag_model.get_flag("peddler_old_goods_contact"):
		echoes.append("货郎暗线能提高旧物收益")
	if flag_model.get_flag("tea_debt_contact"):
		echoes.append("茶棚消息能避开催债人")
	if flag_model.get_flag("porter_ferry_contact"):
		echoes.append("渡口零活能换稳定工钱")
	if flag_model.get_flag("old_well_clue"):
		if flag_model.get_flag("old_well_watchman_deal"):
			echoes.append("旧井守夜人口风暂时压住")
		else:
			echoes.append("旧井暗号可去茶棚接守夜人口风")
	if flag_model.get_flag("black_market_fence_line"):
		echoes.append("夜市暗线可承接高值旧物")
	if flag_model.get_flag("market_heat_cooled"):
		echoes.append("夜市风声被压下过，热度高时可继续避风头")
	if flag_model.get_flag("deduced_old_goods_line"):
		echoes.append("旧物暗价已推断，卖战利品和搜旧货更稳")
	if flag_model.get_flag("deduced_old_well_route"):
		echoes.append("旧井藏路已推断，井边高危搜索更少出坏事")
	if flag_model.get_flag("deduced_support_network"):
		echoes.append("互助补给网已推断，粮药交易和城镇人情更顺")
	if flag_model.get_flag("deduced_debt_timing"):
		echoes.append("催债节奏已推断，茶棚与渡口线更能避险")
	if flag_model.get_flag("deduced_grave_cache"):
		echoes.append("荒坟旧藏已推断，坟地深挖更容易控住风险")
	if flag_model.get_flag("deduced_hunter_route"):
		echoes.append("猎户伏兽路已推断，山林遇兽有更多处理办法")
	var strong_contacts := _strong_contact_summary(relation_model)
	if not strong_contacts.is_empty():
		echoes.append("可信人脉：%s" % strong_contacts)
	if player_model.get_stat("suspicion") >= 45 and not strong_contacts.is_empty():
		echoes.append("怀疑过高会消耗熟人口风")
	if player_model.get_stat("village_attention") >= 35:
		echoes.append("村中关注偏高，卖贵重物更易惹眼")
	if player_model.get_stat("suspicion") >= 35:
		echoes.append("怀疑偏高，接下来应少走犯忌路线")
	return echoes

func _strong_contact_summary(relation_model: RefCounted) -> String:
	if relation_model == null:
		return ""
	var names: Array[String] = []
	for npc_id in ["grocer", "doctor", "peddler", "tea_oldman", "porter"]:
		if relation_model.get_score(npc_id) >= 3:
			names.append(_relation_display_name(npc_id))
	return "、".join(names)

func _get_stage_goal() -> String:
	if _app == null:
		return "活过今天"
	var debt_model: DebtModel = _app.architecture.get_model(&"debt")
	var day_model: DayCycleModel = _app.architecture.get_model(&"day_cycle")
	var player_model: PlayerModel = _app.architecture.get_model(&"player")
	var inventory_model: InventoryModel = _app.architecture.get_model(&"inventory")
	var flag_model: FlagModel = _app.architecture.get_model(&"flag")
	var relation_model: RefCounted = _app.architecture.get_model(&"relation")
	if debt_model.get_value("current") <= 0:
		return "债务已清，等待最终收束"
	var active_task := _active_town_task_summary(relation_model)
	if not active_task.is_empty():
		return active_task
	var debt_stage := _get_debt_pressure_stage(debt_model, day_model)
	if debt_stage == "critical":
		if inventory_model.get_amount("money") >= 10:
			return "债压失控：今晚先还一笔大钱，立刻压住催逼"
		if flag_model.get_flag("deduced_debt_timing") or flag_model.get_flag("tea_debt_contact"):
			return "债压失控：先走茶棚债讯线避门，再尽快筹钱"
		return "债压失控：优先变现战利品，别再空手过夜"
	if debt_stage == "overdue":
		if inventory_model.get_amount("money") >= 5:
			return "债期已过：先还一笔，哪怕只压住今晚"
		if _has_sellable_loot(inventory_model):
			return "债期已过：去城镇卖战利品，先凑出还债钱"
		return "债期已过：走高收益路线筹钱，但要准备被催逼"
	if debt_stage == "due":
		if inventory_model.get_amount("money") >= 10:
			return "催债贴近：今晚可还一笔大钱，优先保住局面"
		if flag_model.get_flag("deduced_debt_timing"):
			return "催债贴近：按催债节奏探风，决定还钱或避让"
		return "催债贴近：先变现、探风或走稳定赚钱线"
	if player_model.get_stat("health") <= 14:
		return "先保命：买药、用药或避开高风险探索"
	if inventory_model.get_amount("food") <= 1:
		return "先补粮：去城镇买粮，或走低风险粮食线"
	if flag_model.get_flag("cold_worse") or flag_model.get_flag("cold_severe"):
		return "先治寒症：药草、清露苔、苦叶草都能压住恶化"
	if day_model.current_day >= debt_model.get_value("due_day") - 1:
		return "催债临近：优先把战利品变现还债"
	if flag_model.get_flag("black_market_fence_line") and (player_model.get_stat("village_attention") >= 40 or player_model.get_stat("suspicion") >= 40):
		return "先避风头：去灰巷清夜市痕迹，别让高收益线反噬"
	if flag_model.get_flag("deduced_old_goods_line") and _has_sellable_loot(inventory_model):
		return "变现旧物：旧物暗价已推断，去城镇找货郎出手更划算"
	if flag_model.get_flag("deduced_debt_timing") and day_model.current_day >= debt_model.get_value("due_day") - 2:
		return "按催债节奏行事：先去茶棚或渡口确认风声，再还钱或避让"
	if flag_model.get_flag("deduced_support_network") and (inventory_model.get_amount("food") <= 3 or flag_model.get_flag("cold_mild")):
		return "用互助网补给：去城镇低价买粮药，或接粮药委托"
	if flag_model.get_flag("deduced_grave_cache") and inventory_model.get_amount("money") < debt_model.get_value("current"):
		return "冲旧藏收益：荒坟路线已推断，可深挖但别让怀疑失控"
	if flag_model.get_flag("soldier_relic_clue"):
		return "可冲高收益：追旧营军中遗物，注意怀疑和关注"
	if flag_model.get_flag("jade_buyer_clue") and inventory_model.get_amount("broken_jade_button") > 0:
		return "去接残玉买家：把残玉扣变成更高收益"
	var equipment_goal := _equipment_stage_goal(inventory_model, flag_model)
	if not equipment_goal.is_empty():
		return equipment_goal
	if flag_model.get_flag("grocer_grain_contact") and inventory_model.get_amount("food") <= 3:
		return "走暗粮线：先把粮食库存补到安全线"
	if flag_model.get_flag("doctor_medicine_contact") and (flag_model.get_flag("cold_mild") or flag_model.get_flag("cold_worse")):
		return "走药路：用周郎中的方子处理寒症"
	if flag_model.get_flag("support_network_built"):
		return "走互助网：用干净人情稳住粮药和怀疑"
	if flag_model.get_flag("grocer_grain_contact") or flag_model.get_flag("doctor_medicine_contact") or flag_model.get_flag("villager_aid_line"):
		return "串互助网：把粮铺、药路和村口人情接成稳定补给"
	if flag_model.get_flag("black_market_fence_line"):
		return "走夜市暗线：把旧井和残玉货快速变现，注意关注值"
	if flag_model.get_flag("peddler_old_goods_contact"):
		return "走旧物暗线：把战利品变现，少在明处露财"
	if flag_model.get_flag("old_well_watchman_deal"):
		return "旧井已稳一层：可夜探旧井，或去夜市暗巷销货"
	if flag_model.get_flag("old_well_clue") and not flag_model.get_flag("old_well_watchman_deal"):
		return "去茶棚接旧井口风：先压住守夜人，再夜探旧井"
	if flag_model.get_flag("old_well_clue"):
		return "旧井夜探：收益高但会涨怀疑，最好带够体力并见好就收"
	if flag_model.get_flag("tea_debt_contact"):
		return "去茶棚探风：确认债主动向再决定还钱或避让"
	if flag_model.get_flag("porter_ferry_contact"):
		return "接渡口零活：稳拿小钱，同时防寒"
	if flag_model.get_flag("studied_bow_manual") or flag_model.get_flag("hunter_trap_line"):
		return "走猎户线：用设伏稳定拿肉食和皮货"
	if flag_model.get_flag("earned_villager_trust") or flag_model.get_flag("villager_aid_line"):
		return "走互助线：低风险换粮和小钱，稳住节奏"
	return "建立路线：先找一条可重复赚钱或补给的门路"

func _equipment_stage_goal(inventory_model: InventoryModel, flag_model: FlagModel) -> String:
	if inventory_model.get_amount("black_iron_shortblade") > 0 and not flag_model.get_flag("equip_black_iron_shortblade"):
		return "整理装备：黑铁短刃可装备，能提高正面应对威胁的把握"
	if inventory_model.get_amount("old_hunter_knife") > 0 and not flag_model.get_flag("equip_old_hunter_knife") and not flag_model.get_flag("equip_black_iron_shortblade"):
		return "整理装备：旧猎刀可装备，外出遇兽更稳"
	if inventory_model.get_amount("wolf_pelt_complete") > 0 and not flag_model.get_flag("equip_wolf_pelt_complete"):
		return "整理装备：完整狼皮可披，水边和寒地更稳"
	if inventory_model.get_amount("ancient_bone_token") > 0 and not flag_model.get_flag("equip_ancient_bone_token"):
		return "整理装备：古骨令可佩，翻找旧物时更压得住痕迹"
	if inventory_model.get_amount("tiger_bone") > 0 and not flag_model.get_flag("equip_tiger_bone") and not flag_model.get_flag("equip_ancient_bone_token"):
		return "整理装备：山君骨可佩，林中和洞穴行动更稳"
	return ""

func _has_sellable_loot(inventory_model: InventoryModel) -> bool:
	for item_id_variant in inventory_model.items.keys():
		var item_id := str(item_id_variant)
		if inventory_model.get_amount(item_id) <= 0:
			continue
		var definition: Dictionary = inventory_model.item_defs.get(item_id, {})
		if str(definition.get("group", "resource")) != "resource":
			return true
	return false

func _active_town_task_summary(relation_model: RefCounted) -> String:
	if relation_model == null:
		return ""
	for task_id in ["grocer_supply", "doctor_delivery", "peddler_appraisal", "tea_warning", "porter_ferry_note", "watchman_hush"]:
		if relation_model.is_task_active(task_id):
			return "城镇委托待交：%s" % _town_task_goal_name(task_id)
	return ""

func _town_task_goal_name(task_id: String) -> String:
	match task_id:
		"grocer_supply":
			return "去后巷暗仓搬粮并交付"
		"doctor_delivery":
			return "去病家门前送急药包"
		"peddler_appraisal":
			return "去后巷试旧物暗价"
		"tea_warning":
			return "去旧桥确认催债脚印"
		"porter_ferry_note":
			return "去河渡口送脚夫口信"
		"watchman_hush":
			return "去旧桥压住旧井守夜人口风"
		_:
			return "回城镇交委托"

func _get_warning_summary(player_model: PlayerModel, inventory_model: InventoryModel, debt_model: DebtModel, day_model: DayCycleModel) -> String:
	var warnings: Array[String] = []
	var flag_model: FlagModel = _app.architecture.get_model(&"flag")
	if player_model.get_stat("health") <= 10:
		warnings.append("健康危险")
	if player_model.get_stat("stamina") <= 12:
		warnings.append("体力见底")
	if inventory_model.get_amount("food") <= 1:
		warnings.append("缺粮")
	if flag_model.get_flag("cold_severe"):
		warnings.append("重寒伤身")
	elif flag_model.get_flag("cold_worse"):
		warnings.append("寒症需用药")
	elif flag_model.get_flag("cold_mild"):
		warnings.append("染寒未治")
	if debt_model.get_value("current") > 0 and day_model.current_day >= debt_model.get_value("due_day") - 2:
		warnings.append(_get_debt_warning_text(debt_model, day_model))
	if player_model.get_stat("village_attention") >= 45:
		warnings.append("村中关注过高")
	if player_model.get_stat("suspicion") >= 45:
		warnings.append("怀疑接近失控")
	return " / ".join(warnings)

func _get_debt_pressure_stage(debt_model: DebtModel, day_model: DayCycleModel) -> String:
	if debt_model.get_value("current") <= 0:
		return "clear"
	var days_left := debt_model.get_value("due_day") - day_model.current_day
	var current_debt := debt_model.get_value("current")
	var initial_debt := maxi(debt_model.get_value("initial"), 1)
	if days_left < -2 or current_debt >= initial_debt + 8:
		return "critical"
	if days_left < 0:
		return "overdue"
	if days_left <= 1:
		return "due"
	if days_left <= 3:
		return "near"
	return "grace"

func _get_debt_pressure_label(debt_model: DebtModel, day_model: DayCycleModel) -> String:
	match _get_debt_pressure_stage(debt_model, day_model):
		"clear":
			return "已清"
		"critical":
			return "失控"
		"overdue":
			return "逾期"
		"due":
			return "催逼"
		"near":
			return "临近"
		_:
			return "宽限"

func _get_debt_warning_text(debt_model: DebtModel, day_model: DayCycleModel) -> String:
	match _get_debt_pressure_stage(debt_model, day_model):
		"critical":
			return "债压失控"
		"overdue":
			return "债期已过"
		"due":
			return "催债贴近"
		"near":
			return "临近催债"
		_:
			return ""

func _is_route_flag(flag_id: String) -> bool:
	return flag_id in [
		"studied_bow_manual",
		"jade_buyer_clue",
		"soldier_relic_clue",
		"met_jade_buyer",
		"hunter_trap_line",
		"villager_aid_line",
		"grocer_grain_contact",
		"doctor_medicine_contact",
		"peddler_old_goods_contact",
		"tea_debt_contact",
		"porter_ferry_contact",
		"old_well_clue",
		"old_well_line",
		"old_well_watchman_deal",
		"black_market_fence_line",
		"market_heat_cooled",
		"support_network_built",
		"deduced_old_goods_line",
		"deduced_old_well_route",
		"deduced_support_network",
		"deduced_debt_timing",
		"deduced_grave_cache",
		"deduced_hunter_route",
		"earned_villager_trust",
		"unlocked_errand_route",
		"saw_graveyard_cache",
		"found_hidden_stash"
	]

func _get_end_of_day_outlook() -> String:
	if _app == null:
		return ""
	var debt_model: DebtModel = _app.architecture.get_model(&"debt")
	var day_model: DayCycleModel = _app.architecture.get_model(&"day_cycle")
	if debt_model.get_value("current") <= 0:
		return "今夜总结：债已经清了，只等一个收束结局。"
	if day_model.current_day >= debt_model.get_value("due_day") - 1:
		return "今夜总结：离催债只差临门一脚，接下来要优先保住还债能力。"
	if _get_route_hint().contains("夜市暗线"):
		return "今夜总结：夜市能快速换钱，但热度会反噬；关注高时要先清痕迹。"
	if _get_route_hint().contains("跑腿门路"):
		return "今夜总结：稳健路线已成型，接下来重心是持续攒钱。"
	if _get_route_hint().contains("坟地线索"):
		return "今夜总结：冒险路线还在推进，但怀疑与风险也在累积。"
	return "今夜总结：局面还能稳住，明天要继续平衡生存和还债。"

func _format_display_entries(entries: Array) -> String:
	var texts: Array[String] = []
	for entry_variant in entries:
		var entry: Dictionary = entry_variant
		texts.append("%s：%s" % [
			str(entry.get("name", "未知")),
			str(entry.get("value", 0))
		])
	return "    ".join(texts)

func _get_special_inventory_summary(inventory_model: InventoryModel) -> String:
	var entries: Array[String] = []
	for item_id_variant in inventory_model.items.keys():
		var item_id: String = str(item_id_variant)
		var amount: int = inventory_model.get_amount(item_id)
		if amount <= 0:
			continue
		var definition: Dictionary = inventory_model.item_defs.get(item_id, {})
		if str(definition.get("group", "resource")) == "resource":
			continue
		entries.append("%s%sx%d" % [
			_rarity_prefix(str(definition.get("rarity", "common"))),
			str(definition.get("name", item_id)),
			amount
		])
		if entries.size() >= 6:
			break
	return "，".join(entries)

func _get_equipment_summary() -> String:
	if _app == null:
		return ""
	var flag_model: FlagModel = _app.architecture.get_model(&"flag")
	var inventory_model: InventoryModel = _app.architecture.get_model(&"inventory")
	var entries: Array[String] = []
	for item_id in ["old_hunter_knife", "black_iron_shortblade", "wolf_pelt_complete", "tiger_bone", "ancient_bone_token"]:
		if flag_model.get_flag(_equipment_flag(item_id)) and inventory_model.get_amount(item_id) > 0:
			entries.append(_item_display_name(item_id))
	return "，".join(entries)

func _rarity_prefix(rarity_id: String) -> String:
	match rarity_id:
		"fine":
			return "【优质】"
		"rare":
			return "【稀有】"
		"precious":
			return "【珍贵】"
		"legendary":
			return "【传说】"
		"mythic":
			return "【神话】"
		_:
			return "【普通】"

func _rarity_rank(rarity_id: String) -> int:
	match rarity_id:
		"fine":
			return 2
		"rare":
			return 3
		"precious":
			return 4
		"legendary":
			return 5
		"mythic":
			return 6
		_:
			return 1

func _rarity_color(rarity_id: String) -> Color:
	match rarity_id:
		"fine":
			return Color(0.48, 0.80, 0.47, 1.0)
		"rare":
			return Color(0.44, 0.68, 0.92, 1.0)
		"precious":
			return Color(0.72, 0.51, 0.90, 1.0)
		"legendary":
			return Color(0.94, 0.76, 0.35, 1.0)
		"mythic":
			return Color(0.89, 0.35, 0.31, 1.0)
		_:
			return Color(0.88, 0.85, 0.78, 1.0)

func _rarity_color_hex(rarity_id: String) -> String:
	match rarity_id:
		"fine":
			return "#7BCB79"
		"rare":
			return "#6FADEB"
		"precious":
			return "#B783E6"
		"legendary":
			return "#F0C15A"
		"mythic":
			return "#E25A4F"
		_:
			return "#E8E1D2"

func _resource_color(item_id: String) -> Color:
	match item_id:
		"food":
			return Color(0.87, 0.74, 0.45, 1.0)
		"money":
			return Color(0.89, 0.69, 0.35, 1.0)
		"herb":
			return Color(0.60, 0.79, 0.42, 1.0)
		"meat":
			return Color(0.82, 0.55, 0.42, 1.0)
		_:
			return Color(0.84, 0.80, 0.70, 1.0)

func _inventory_icon(group: String) -> String:
	match group:
		"herb":
			return "草"
		"animal":
			return "皮"
		"old_object":
			return "旧"
		"tool":
			return "具"
		"manual":
			return "卷"
		"weapon":
			return "刃"
		"relic":
			return "令"
		"food":
			return "食"
		_:
			return "物"

func _pick_focus_location(options: Array) -> String:
	if options.is_empty():
		return "field"
	var highest_priority: int = -1
	var picked_location: String = "field"
	for option_variant in options:
		var option: Dictionary = option_variant
		var risk_text: String = str(option.get("risk_desc", ""))
		var priority: int = 0
		if risk_text.contains("高风险"):
			priority = 3
		elif risk_text.contains("中风险"):
			priority = 2
		elif risk_text.contains("低风险"):
			priority = 1
		if priority > highest_priority:
			highest_priority = priority
			picked_location = str(option.get("location_id", "field"))
	return picked_location

func _build_option_markup(option: Dictionary, weather: Dictionary) -> String:
	var title: String = str(option.get("omen_title", option.get("title", "未知选项")))
	var omen_text: String = str(option.get("omen_text", "命象不明，只见雾中一线。"))
	var omen_place: String = str(option.get("omen_place", _location_name(str(option.get("location_id", "field")))))
	var omen_gain: String = _style_reward_text(str(option.get("omen_gain", option.get("reward_desc", "-"))))
	var omen_warning: String = str(option.get("omen_warning", option.get("risk_desc", "-")))
	var risk_desc: String = _style_risk_text(str(option.get("risk_desc", "-")))
	var title_markup: String = _style_title_text(title, str(option.get("location_id", "field")), str(option.get("risk_desc", "")), str(weather.get("id", "clear")))
	var fortune_mark: String = _build_fortune_mark(option, weather)
	var route_badge := _option_route_badge(option)
	if _compact_option_markup:
		var compact_lines: Array[String] = [
			title_markup,
			fortune_mark,
			route_badge,
			"[font_size=13][color=#B9AD8D]%s[/color][/font_size]" % omen_text,
			"[font_size=12][color=#A97B3E]所指[/color]  [color=#D7CFBB]%s[/color]    [pulse freq=1.2 color=#F0C15A ease=-2.0][color=#A97B3E]可得[/color][/pulse]  [color=#D7CFBB]%s[/color][/font_size]" % [omen_place, omen_gain],
			"[font_size=12][shake rate=12.0 level=2 connected=1][color=#7E8190]忌[/color]  [color=#CDBFA0]%s[/color][/shake][/font_size]" % omen_warning
		]
		compact_lines = compact_lines.filter(func(line: String) -> bool: return not line.is_empty())
		return String.chr(10).join(compact_lines)
	var lines: Array[String] = [
		title_markup,
		fortune_mark,
		route_badge,
		"[font_size=14][color=#B9AD8D]%s[/color][/font_size]" % omen_text,
		"[font_size=14][color=#A97B3E]所指[/color]  [color=#D7CFBB]%s[/color]    [pulse freq=1.2 color=#F0C15A ease=-2.0][color=#A97B3E]可得[/color][/pulse]  [color=#D7CFBB]%s[/color][/font_size]" % [omen_place, omen_gain],
		"[font_size=13][shake rate=12.0 level=2 connected=1][color=#7E8190]忌[/color]  [color=#CDBFA0]%s[/color][/shake]    %s[/font_size]" % [omen_warning, risk_desc]
	]
	lines = lines.filter(func(line: String) -> bool: return not line.is_empty())
	return String.chr(10).join(lines)

func _option_route_badge(option: Dictionary) -> String:
	var route_tag := str(option.get("route_tag", ""))
	if route_tag.is_empty():
		return ""
	var route_hint := str(option.get("route_hint", "线索已整理，路线收益更明确。"))
	return "[font_size=12][color=#C79A4C]线[/color] [pulse freq=1.0 color=#DDBD72 ease=-2.0][color=#E9D79A][b]%s[/b][/color][/pulse]  [color=#9FB58D]%s[/color][/font_size]" % [
		route_tag,
		route_hint
	]

func _build_fortune_mark(option: Dictionary, weather: Dictionary) -> String:
	var verdict: Dictionary = _fortune_verdict(option, weather)
	var grade := str(verdict.get("grade", "平"))
	var text := str(verdict.get("text", "吉凶相抵，取舍在人。"))
	var color := str(verdict.get("color", "#D8CFAE"))
	var effect_open := "[pulse freq=1.1 color=%s ease=-2.0]" % color if _fortune_score_grade_rank(grade) > 0 else ""
	var effect_close := "[/pulse]" if not effect_open.is_empty() else ""
	if grade.contains("凶"):
		effect_open = "[shake rate=10.0 level=2 connected=1]"
		effect_close = "[/shake]"
	return "[font_size=13]%s[color=%s][b]%s[/b][/color]%s  [color=#B9AD8D]%s[/color][/font_size]" % [
		effect_open,
		color,
		grade,
		effect_close,
		text
	]

func _fortune_verdict(option: Dictionary, weather: Dictionary) -> Dictionary:
	var configured_grade := str(option.get("fortune_grade", ""))
	if not configured_grade.is_empty():
		return {
			"grade": configured_grade,
			"text": str(option.get("fortune_text", _fortune_text_for_grade(configured_grade, option))),
			"color": _fortune_grade_color(configured_grade)
		}
	var score := _fortune_score(option, weather)
	var grade := _fortune_grade_from_score(score)
	return {
		"grade": grade,
		"text": _fortune_text_for_grade(grade, option),
		"color": _fortune_grade_color(grade)
	}

func _fortune_score(option: Dictionary, weather: Dictionary) -> int:
	var score := 0
	var risk := str(option.get("risk_desc", ""))
	var reward := str(option.get("reward_desc", "")) + str(option.get("omen_gain", ""))
	var warning := str(option.get("omen_warning", ""))
	if risk.contains("低风险") or risk.contains("无直接"):
		score += 2
	if risk.contains("中风险"):
		score -= 1
	if risk.contains("高风险"):
		score -= 3
	if reward.contains("稳定") or reward.contains("粮食") or reward.contains("健康") or reward.contains("体力") or reward.contains("信任"):
		score += 2
	if reward.contains("高收益") or reward.contains("更高") or reward.contains("买家") or reward.contains("线索"):
		score += 1
	if reward.contains("传说") or reward.contains("神话"):
		score += 2
	if warning.contains("受伤") or warning.contains("伤身") or warning.contains("招祸") or warning.contains("追查"):
		score -= 2
	if warning.contains("怀疑") or warning.contains("关注") or warning.contains("人眼"):
		score -= 1
	if str(option.get("id", "")).contains("rest") or str(option.get("id", "")).contains("use_herb"):
		score += 1
	if int(option.get("base_weight", 1)) >= 9:
		score += 1
	if str(weather.get("id", "")) == "rain" and str(option.get("location_id", "")) in ["river", "graveyard"]:
		score -= 1
	if str(weather.get("id", "")) == "clear" and str(option.get("location_id", "")) in ["mountain", "forest"]:
		score += 1
	return clampi(score, -6, 6)

func _fortune_grade_from_score(score: int) -> String:
	if score >= 5:
		return "大吉"
	if score >= 3:
		return "中吉"
	if score >= 1:
		return "小吉"
	if score == 0:
		return "平"
	if score >= -2:
		return "小凶"
	if score >= -4:
		return "中凶"
	return "大凶"

func _fortune_score_grade_rank(grade: String) -> int:
	match grade:
		"大吉":
			return 3
		"中吉":
			return 2
		"小吉":
			return 1
		"小凶":
			return -1
		"中凶":
			return -2
		"大凶":
			return -3
		_:
			return 0

func _fortune_grade_color(grade: String) -> String:
	match grade:
		"大吉":
			return "#F0C15A"
		"中吉":
			return "#DDBD72"
		"小吉":
			return "#9DCA72"
		"小凶":
			return "#DCA347"
		"中凶":
			return "#D46E58"
		"大凶":
			return "#E25A4F"
		_:
			return "#D8CFAE"

func _fortune_text_for_grade(grade: String, option: Dictionary) -> String:
	var place := str(option.get("omen_place", _location_name(str(option.get("location_id", "field")))))
	match grade:
		"大吉":
			return "%s有厚利，应果断取之。" % place
		"中吉":
			return "%s有利可图，守卦而行。" % place
		"小吉":
			return "小有所得，忌贪多。"
		"小凶":
			return "利中带损，须见好就收。"
		"中凶":
			return "有险伏在路上，备好退路。"
		"大凶":
			return "凶象压顶，非急需不宜入局。"
		_:
			return "吉凶相抵，取舍在人。"

func _location_name(location_id: String) -> String:
	match location_id:
		"graveyard":
			return "荒坟"
		"river":
			return "河边"
		"forest":
			return "林地"
		"mountain":
			return "小黑山"
		_:
			return "村外"

func _style_title_text(title: String, location_id: String, risk_desc: String, weather_id: String) -> String:
	var color_hex: String = "#E9D79A"
	match location_id:
		"graveyard":
			color_hex = "#D69B82"
		"river":
			color_hex = "#9EC8D5"
		"forest":
			color_hex = "#B7C58A"
		"mountain":
			color_hex = "#D6D0BC"
		_:
			color_hex = "#E9D79A"
	var title_size: int = 18 if _compact_option_markup else 21
	var decorated: String = "[wave amp=10.0 freq=2.0 connected=1][font_size=%d][color=%s][b]%s[/b][/color][/font_size][/wave]" % [title_size, color_hex, title]
	if _is_high_risk(risk_desc):
		decorated = "[shake rate=16.0 level=3 connected=1][color=#C46F5B]%s[/color][/shake]" % decorated
	elif weather_id == "rain":
		decorated = "[wave]%s[/wave]" % decorated
	return decorated

func _style_reward_text(text: String) -> String:
	var styled: String = text
	styled = styled.replace("铜钱", "[color=#E2B15A][b]铜钱[/b][/color]")
	styled = styled.replace("药草", "[color=#98C96A][b]药草[/b][/color]")
	styled = styled.replace("肉", "[color=#D28B6C][b]肉[/b][/color]")
	styled = styled.replace("粮食", "[color=#DDBD72][b]粮食[/b][/color]")
	styled = styled.replace("体力", "[color=#AFC9D2]体力[/color]")
	styled = styled.replace("信任", "[color=#CBB37A]信任[/color]")
	return styled

func _style_risk_text(text: String) -> String:
	var styled: String = text
	styled = styled.replace("高风险", "[color=#D46E58][b]高风险[/b][/color]")
	styled = styled.replace("中风险", "[color=#DCA347][b]中风险[/b][/color]")
	styled = styled.replace("低风险", "[color=#8DBB6C][b]低风险[/b][/color]")
	styled = styled.replace("怀疑", "[color=#C386BA]怀疑[/color]")
	styled = styled.replace("受寒", "[color=#8DB3C5]受寒[/color]")
	return styled

func _is_high_risk(text: String) -> bool:
	return text.contains("高风险")

func _apply_responsive_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var compact: bool = viewport_size.x < 1360.0
	var narrow: bool = viewport_size.x < 1120.0
	var tiny: bool = viewport_size.x < 920.0
	var short_window: bool = viewport_size.y < 760.0
	var very_short: bool = viewport_size.y < 680.0
	var cramped: bool = viewport_size.x < 1180.0 or viewport_size.y < 700.0
	_compact_option_markup = cramped or short_window
	var margin_x: float = 26.0
	var margin_y: float = 18.0
	if tiny:
		margin_x = 8.0
		margin_y = 8.0
	elif narrow:
		margin_x = 12.0
		margin_y = 10.0
	elif compact:
		margin_x = 14.0
		margin_y = 10.0

	if _content_scroll != null:
		_content_scroll.custom_minimum_size = Vector2.ZERO
		main_margin.custom_minimum_size.x = maxf(viewport_size.x - margin_x * 2.0, 320.0)
		main_margin.custom_minimum_size.y = maxf(viewport_size.y - margin_y * 2.0, 0.0)
	main_margin.add_theme_constant_override("margin_left", int(margin_x))
	main_margin.add_theme_constant_override("margin_top", int(margin_y))
	main_margin.add_theme_constant_override("margin_right", int(margin_x))
	main_margin.add_theme_constant_override("margin_bottom", int(margin_y))

	root_column.add_theme_constant_override("separation", 8 if very_short else (10 if short_window else 16))
	top_layout.add_theme_constant_override("separation", 8 if cramped else (14 if compact else 20))
	sidebar.custom_minimum_size.x = 292.0 if tiny else (360.0 if cramped else (430.0 if compact else 520.0))
	sidebar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var sidebar_stack: VBoxContainer = _get_main_node("RootColumn/TopLayout/Sidebar/SidebarStack") as VBoxContainer
	if sidebar_stack != null:
		sidebar_stack.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		sidebar_stack.add_theme_constant_override("separation", 8 if cramped else 12)
	if _situation_echo_row != null:
		_situation_echo_row.add_theme_constant_override("separation", 8 if cramped else 10)
		_situation_echo_row.custom_minimum_size.y = 250.0 if very_short else (276.0 if cramped else (300.0 if compact else 320.0))
	var stats_panel: PanelContainer = _get_main_node("RootColumn/TopLayout/Sidebar/SidebarStack/StatsPanel") as PanelContainer
	if stats_panel == null and _situation_echo_row != null:
		stats_panel = _situation_echo_row.get_node_or_null("StatsPanel") as PanelContainer
	if stats_panel != null:
		stats_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stats_panel.custom_minimum_size.y = 250.0 if very_short else (276.0 if cramped else (300.0 if compact else 320.0))
	if result_panel != null:
		result_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		result_panel.custom_minimum_size.y = 250.0 if very_short else (276.0 if cramped else (300.0 if compact else 320.0))
	if _status_scroll != null:
		_status_scroll.custom_minimum_size.y = 166.0 if very_short else (190.0 if cramped else (214.0 if compact else 232.0))
	main_stage.add_theme_constant_override("separation", 8 if cramped else (12 if compact else 16))
	_set_panel_margins("RootColumn/TopLayout/Sidebar/SidebarStack/HeaderPanel/MarginContainer", 12 if cramped else 18)
	_set_panel_margins("RootColumn/TopLayout/Sidebar/SidebarStack/StatsPanel/MarginContainer", 12 if cramped else 18)
	var stats_margin := stats_panel.get_node_or_null("MarginContainer") as MarginContainer if stats_panel != null else null
	if stats_margin != null:
		var status_margin := 10 if very_short else (12 if cramped else 14)
		stats_margin.add_theme_constant_override("margin_left", status_margin)
		stats_margin.add_theme_constant_override("margin_top", status_margin)
		stats_margin.add_theme_constant_override("margin_right", status_margin)
		stats_margin.add_theme_constant_override("margin_bottom", status_margin)
	_set_panel_margins("RootColumn/TopLayout/MainStage/StagePanel/MarginContainer", 12 if cramped else 20)
	_set_panel_margins("RootColumn/TopLayout/MainStage/ChoicesPanel/MarginContainer", 12 if cramped else 18)
	var result_margin := result_panel.get_node_or_null("MarginContainer") as MarginContainer if result_panel != null else null
	if result_margin != null:
		var margin := 10 if very_short else (12 if short_window else 14)
		result_margin.add_theme_constant_override("margin_left", margin)
		result_margin.add_theme_constant_override("margin_top", margin)
		result_margin.add_theme_constant_override("margin_right", margin)
		result_margin.add_theme_constant_override("margin_bottom", margin)
	choices_panel.custom_minimum_size = Vector2(0.0, 0.0)
	if _exploration_board != null:
		_exploration_board.custom_minimum_size.y = 300.0 if very_short else (330.0 if cramped else 380.0)
	if _town_board != null:
		_town_board.custom_minimum_size.y = 300.0 if very_short else (330.0 if cramped else 380.0)
	if _result_scroll != null:
		_result_scroll.custom_minimum_size.y = 170.0 if very_short else (196.0 if short_window else 226.0)
	if next_day_button != null:
		next_day_button.custom_minimum_size = Vector2(70.0 if cramped else 78.0, 28.0)
		next_day_button.add_theme_font_size_override("font_size", 12 if cramped else 13)
	scene_illustration.clip_contents = true
	scene_illustration.custom_minimum_size.y = 104.0 if very_short else (122.0 if tiny else (136.0 if cramped else (172.0 if compact else 210.0)))
	for button in option_buttons:
		button.custom_minimum_size.y = 90.0 if very_short else (94.0 if tiny else (100.0 if cramped else (112.0 if compact else 126.0)))
		_set_content_row_margins(button, 10.0 if cramped else 14.0, 8.0 if cramped else 12.0)
	for option_label in option_rich_labels:
		option_label.fit_content = false
		option_label.scroll_active = true
		option_label.mouse_filter = Control.MOUSE_FILTER_PASS
		option_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		option_label.add_theme_font_size_override("normal_font_size", 13 if _compact_option_markup else 15)
	for option_illustration in option_illustrations:
		var icon_size: float = 50.0 if very_short else (56.0 if cramped else 82.0)
		option_illustration.custom_minimum_size = Vector2(icon_size, icon_size)
	for option_backdrop in _option_backdrops:
		var backdrop_inset: float = 160.0 if tiny else (190.0 if cramped else 230.0)
		option_backdrop.set_layout_inset(backdrop_inset)
	main_margin.scale = Vector2.ONE
	main_margin.pivot_offset = Vector2.ZERO
