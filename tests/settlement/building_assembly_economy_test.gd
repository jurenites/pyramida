extends "res://tests/settlement/reviewed_balance_test.gd"
## Exercise real catalogue costs, production jobs, extraction, relocation and saves
## independently of the unrelated procedural starting-island fixture.
func _initialize() -> void:
	test_water(); test_costs_and_models(); test_ground_and_courier(); test_production(); test_free_quarry_move()
	for message in failures: push_error(message)
	print("%s: %d assembled workplace economy checks, %d failures" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	quit(int(not failures.is_empty()))
