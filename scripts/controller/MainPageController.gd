class_name MainPageController
extends Control

const ExplorationBoardScript := preload("res://scripts/ui/ExplorationBoard.gd")
const TownBoardScript := preload("res://scripts/ui/TownBoard.gd")

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
var _town_button: Button
var _feedback_layer: Control
var _feedback_bubble_index: int = 0
var _player_state_rich: RichTextLabel
var _inventory_rich: RichTextLabel
var _selection_rich: RichTextLabel

func _ready() -> void:
	_ensure_scroll_viewport()
	_ensure_exploration_board()
	_ensure_town_board()
	_ensure_inventory_overlay()
	_ensure_sidebar_buttons()
	_ensure_feedback_layer()
	_ensure_rich_text_replacements()
	_apply_visual_polish()
	_app = get_tree().get_first_node_in_group("app") as App
	if _app == null and get_parent() != null and get_parent().get_parent() != null:
		var root: Node = get_parent().get_parent()
		if root.has_node("App"):
			_app = root.get_node("App") as App
	for i in option_buttons.size():
		option_buttons[i].pressed.connect(_on_option_pressed.bind(i))
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
	row.offset_left = -250.0
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
	if _town_button != null:
		_town_button.disabled = _app == null or _interaction_mode != "fortune"

func _ensure_rich_text_replacements() -> void:
	_player_state_rich = _create_rich_replacement(player_state_label)
	_inventory_rich = _create_rich_replacement(inventory_label)
	_selection_rich = _create_rich_replacement(selection_label)

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
	_set_panel_style("MainMargin/RootColumn/TopLayout/MainStage/StagePanel", page_style)
	_set_panel_style("MainMargin/RootColumn/TopLayout/MainStage/ChoicesPanel", card_style)
	_set_panel_style("MainMargin/RootColumn/ResultPanel", card_style)

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
	_set_label("MainMargin/RootColumn/ResultPanel/MarginContainer/ResultVBox/ResultHeader/ResultTitle", Color(0.94, 0.83, 0.60, 1.0), 19)
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
		option_label.scroll_active = false

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
			if not target_id.begins_with("cold_"):
				return {}
			return {
				"text": "状态 %s" % _flag_display_name(target_id),
				"color": Color(0.72, 0.52, 0.92, 1.0),
				"fly_to_bag": false,
				"shake": true,
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
	return {}

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
		if index < options.size():
			var option: Dictionary = options[index]
			button.visible = true
			button.disabled = false
			button.text = ""
			option_label.bbcode_enabled = true
			option_label.text = _build_option_markup(option, weather)
			option_illustration.set_context(
				str(option.get("location_id", "field")),
				str(option.get("risk_desc", "")),
				str(option.get("reward_desc", ""))
			)
		else:
			button.visible = false
			option_label.text = ""
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
	_interaction_mode = "selecting"
	for button in option_buttons:
		button.disabled = true
	_sync_quick_action_buttons()
	_set_selection_text("卦象已定，正在辨认今日机缘……")
	_app.architecture.command_dispatcher.dispatch(preload("res://scripts/command/SelectFortuneCommand.gd"), {"index": index})

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

	var seal := Label.new()
	seal.text = name.substr(0, 1)
	seal.custom_minimum_size = Vector2(34.0, 34.0)
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal.add_theme_font_size_override("font_size", 20)
	seal.add_theme_color_override("font_color", _resource_color(item_id))
	row.add_child(seal)

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

	var icon := Label.new()
	icon.text = _inventory_icon(str(entry.get("group", "")))
	icon.custom_minimum_size = Vector2(34.0, 30.0)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 22)
	icon.add_theme_color_override("font_color", rarity_color)
	top.add_child(icon)

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
	return panel

func _on_inventory_button_pressed() -> void:
	if _app == null:
		return
	_refresh_inventory_overlay()
	move_child(_inventory_overlay, get_child_count() - 1)
	_inventory_overlay.visible = true

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
	_exploration_board.configure(selected, _current_weather)
	scene_illustration.set_context(
		str(_current_weather.get("id", "clear")),
		"daytime",
		str(selected.get("location_id", "field"))
	)
	_set_selection_text("已定卦：%s\n卦象只给方向。你需要从入口出发，在格子地图中搜索、应对危险，并找到出口撤离。\n%s" % [
		str(selected.get("omen_title", selected.get("title", "未知卦象"))),
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
	_town_board.configure(selected, inventory_model.item_defs, inventory_model.items)
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
	_town_board.update_inventory(inventory_model.item_defs, inventory_model.items)
	_set_selection_text("%s\n%s" % [summary, _get_progress_summary()])
	_play_manual_item_feedback([
		{"id": item_id, "value": -1},
		{"id": "money", "value": value}
	])
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
		next_day_button.text = "进入第%d天" % [current_day + 1]
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
	_set_rich_text(_player_state_rich, player_state_label, player_display_text)
	var special_inventory_text: String = _get_special_inventory_summary(inventory_model)
	var inventory_display_text: String = "%s\n阶段：%s    欠债：%d/%d    催债日：%d\n%s" % [
		_format_display_entries(inventory_model.get_display_value_map(inventory_order)),
		day_model.current_phase,
		debt_model.get_value("current"),
		debt_model.get_value("initial"),
		debt_model.get_value("due_day"),
		_get_progress_summary()
	]
	if not special_inventory_text.is_empty():
		inventory_display_text += "\n战利品：%s" % special_inventory_text
	_set_rich_text(_inventory_rich, inventory_label, inventory_display_text)

func _get_route_hint() -> String:
	if _app == null:
		return "路线未定"
	var flag_model: FlagModel = _app.architecture.get_model(&"flag")
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
	return "还债进度：%d/%d    %s" % [repaid, initial_debt, _get_route_hint()]

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
		warnings.append("临近催债")
	return " / ".join(warnings)

func _get_end_of_day_outlook() -> String:
	if _app == null:
		return ""
	var debt_model: DebtModel = _app.architecture.get_model(&"debt")
	var day_model: DayCycleModel = _app.architecture.get_model(&"day_cycle")
	if debt_model.get_value("current") <= 0:
		return "今夜总结：债已经清了，只等一个收束结局。"
	if day_model.current_day >= debt_model.get_value("due_day") - 1:
		return "今夜总结：离催债只差临门一脚，接下来要优先保住还债能力。"
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
	if _compact_option_markup:
		var compact_lines: Array[String] = [
			title_markup,
			"[font_size=13][color=#B9AD8D]%s[/color][/font_size]" % omen_text,
			"[font_size=12][color=#A97B3E]所指[/color]  [color=#D7CFBB]%s[/color]    [pulse freq=1.2 color=#F0C15A ease=-2.0][color=#A97B3E]可得[/color][/pulse]  [color=#D7CFBB]%s[/color][/font_size]" % [omen_place, omen_gain],
			"[font_size=12][shake rate=12.0 level=2 connected=1][color=#7E8190]忌[/color]  [color=#CDBFA0]%s[/color][/shake][/font_size]" % omen_warning
		]
		return String.chr(10).join(compact_lines)
	var lines: Array[String] = [
		title_markup,
		"[font_size=14][color=#B9AD8D]%s[/color][/font_size]" % omen_text,
		"[font_size=14][color=#A97B3E]所指[/color]  [color=#D7CFBB]%s[/color]    [pulse freq=1.2 color=#F0C15A ease=-2.0][color=#A97B3E]可得[/color][/pulse]  [color=#D7CFBB]%s[/color][/font_size]" % [omen_place, omen_gain],
		"[font_size=13][shake rate=12.0 level=2 connected=1][color=#7E8190]忌[/color]  [color=#CDBFA0]%s[/color][/shake]    %s[/font_size]" % [omen_warning, risk_desc]
	]
	return String.chr(10).join(lines)

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
	sidebar.custom_minimum_size.x = 178.0 if tiny else (228.0 if cramped else (292.0 if compact else 360.0))
	sidebar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var sidebar_stack: VBoxContainer = _get_main_node("RootColumn/TopLayout/Sidebar/SidebarStack") as VBoxContainer
	if sidebar_stack != null:
		sidebar_stack.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		sidebar_stack.add_theme_constant_override("separation", 8 if cramped else 12)
	var stats_panel: PanelContainer = _get_main_node("RootColumn/TopLayout/Sidebar/SidebarStack/StatsPanel") as PanelContainer
	if stats_panel != null:
		stats_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	main_stage.add_theme_constant_override("separation", 8 if cramped else (12 if compact else 16))
	_set_panel_margins("RootColumn/TopLayout/Sidebar/SidebarStack/HeaderPanel/MarginContainer", 12 if cramped else 18)
	_set_panel_margins("RootColumn/TopLayout/Sidebar/SidebarStack/StatsPanel/MarginContainer", 12 if cramped else 18)
	_set_panel_margins("RootColumn/TopLayout/MainStage/StagePanel/MarginContainer", 12 if cramped else 20)
	_set_panel_margins("RootColumn/TopLayout/MainStage/ChoicesPanel/MarginContainer", 12 if cramped else 18)
	_set_panel_margins("RootColumn/ResultPanel/MarginContainer", 12 if very_short else (14 if short_window else 18))
	choices_panel.custom_minimum_size = Vector2(0.0, 0.0)
	if _exploration_board != null:
		_exploration_board.custom_minimum_size.y = 300.0 if very_short else (330.0 if cramped else 380.0)
	if _town_board != null:
		_town_board.custom_minimum_size.y = 300.0 if very_short else (330.0 if cramped else 380.0)
	result_panel.custom_minimum_size.y = 76.0 if very_short else (96.0 if short_window else 140.0)
	scene_illustration.clip_contents = true
	scene_illustration.custom_minimum_size.y = 104.0 if very_short else (122.0 if tiny else (136.0 if cramped else (172.0 if compact else 210.0)))
	for button in option_buttons:
		button.custom_minimum_size.y = 90.0 if very_short else (94.0 if tiny else (100.0 if cramped else (112.0 if compact else 126.0)))
		_set_content_row_margins(button, 10.0 if cramped else 14.0, 8.0 if cramped else 12.0)
	for option_label in option_rich_labels:
		option_label.fit_content = false
		option_label.scroll_active = false
		option_label.add_theme_font_size_override("normal_font_size", 13 if _compact_option_markup else 15)
	for option_illustration in option_illustrations:
		var icon_size: float = 50.0 if very_short else (56.0 if cramped else 82.0)
		option_illustration.custom_minimum_size = Vector2(icon_size, icon_size)
	main_margin.scale = Vector2.ONE
	main_margin.pivot_offset = Vector2.ZERO
