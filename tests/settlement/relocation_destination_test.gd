extends "res://tests/settlement/relocation_test.gd"
## Focused coverage for revising a queued move from its standing source.

func run() -> void:
	test_change_destination()
	await test_controls()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: %d move destination checks" % checks)
	quit(int(not failures.is_empty()))
