class_name QGFPanelBase
extends Control

signal close_requested(payload: Variant)

var panel_payload: Variant

func open(payload: Variant = null) -> void:
	panel_payload = payload
	visible = true

func close(payload: Variant = null) -> void:
	close_requested.emit(payload)
	visible = false
