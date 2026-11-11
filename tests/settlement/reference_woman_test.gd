extends "res://tests/settlement/reference_man_test.gd"

func _initialize() -> void:
	Character = preload("res://data/settlement/reference_woman.tscn")
	call_deferred("run")
