extends "res://tests/settlement/reference_man_test.gd"

func _initialize() -> void:
	Character = preload("res://data/settlement/reference_child.tscn")
	call_deferred("run")
