class_name GameRoot
extends Node

@onready var app: App = $App
@onready var main_page_controller: MainPageController = $UILayer/MainPage
@onready var ui_layer: CanvasLayer = $UILayer
@onready var loading_layer: CanvasLayer = $LoadingLayer
@onready var startup_flow: StartupFlow = $LoadingLayer/StartupFlow

func _ready() -> void:
	ui_layer.visible = false
	loading_layer.visible = true
	startup_flow.finished.connect(_on_startup_finished)

func _on_startup_finished() -> void:
	ui_layer.visible = true
	loading_layer.visible = false
