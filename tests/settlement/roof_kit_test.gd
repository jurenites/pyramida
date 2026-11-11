extends SceneTree
const Kit = preload("res://scripts/settlement/structure_parts.gd")
const Roof = preload("res://scripts/settlement/roof_kit.gd")
const Barn = preload("res://scripts/settlement/hay_barn_view.gd")
const Fixture = preload("res://tests/settlement/reviewed_balance_test.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for kind: String in Roof.SIZES:
		check(kind in Kit.kinds(), kind + " available in Blueprints")
		var part := Kit.placement(kind, Vector3.ZERO, Vector3.ZERO, Vector3.UP)
		check(Kit.bounds(part).size.is_equal_approx(Roof.SIZES[kind]), kind + " exact dimensions")
		check(is_zero_approx(Kit.bounds(part).position.y), kind + " seats on floor")
		part.rotation.y = PI / 2
		var decoded := Kit.decode(JSON.parse_string(JSON.stringify(Kit.encode([part]))))
		check(not decoded.is_empty() and Kit.bounds(decoded.parts[0]).is_equal_approx(Kit.bounds(part)), kind + " rotated save roundtrip")
		# Closed solids must have correctly wound, outward-facing triangles.
		var arrays := Roof.mesh(kind).surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in range(0, points.size(), 3):
			check((points[i + 1] - points[i]).cross(points[i + 2] - points[i]).dot(normals[i]) < 0, kind + " outward clockwise face")
	var barn := Kit.Assets.create("hay_barn")
	check(barn.has_node("Canopy/PlankRoof") and barn.get_node("Canopy/PlankRoof").get_meta("source_component") == "Canopy/RoofCourse0", "Barn retains its corner profile using Shed roof boards")
	check(not barn.has_node("Canopy/RoofCourse0"), "Barn no longer has Shed roof")
	barn.free()
	var fixture := Fixture.new()
	for direction in 4:
		var world = fixture.fixture()
		fixture.finish(world, "house", Vector3i.ZERO)
		var expected := Vector3.RIGHT.rotated(Vector3.UP, -direction * PI / 2) * 1.5
		var snapped := Barn.attachment(world, Vector3i(roundi(expected.x), 0, roundi(expected.z)), expected, direction)
		check(not snapped.is_empty(), "Attachment on side %d" % direction)
		if snapped.is_empty(): continue
		check(world.request_build("hay_barn", snapped.cell, direction, snapped.offset), "Barn fits House wall: " + world.last_message)
		if world.plans.is_empty(): continue
		var plan: Dictionary = world.plans.values()[0]
		plan.used = plan.materials.duplicate(); plan.installed = plan.required
		world._complete_plan(plan)
		var house_rect := Model.Farming.footprint("house", Vector3i.ZERO)
		var barn_rect := Model.Farming.footprint("hay_barn", snapped.cell, snapped.offset, direction)
		check(not house_rect.intersects(barn_rect), "No House/Barn overlap")
		var size := house_rect.merge(barn_rect).size
		check(size.is_equal_approx(Vector2(3, 2) if direction % 2 == 0 else Vector2(2, 3)), "Combined 2 X 3 footprint")
		check(not world.request_build("hay_barn", snapped.cell, direction, snapped.offset), "Duplicate attachment rejected")
		var restored = Model.new()
		check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Attached Barn saves")
		check(restored.buildings.get(snapped.cell, {}).get("placement_offset", Vector3.ZERO).is_equal_approx(snapped.offset), "Half-grid anchor survives reload")
	check(fixture.failures.is_empty(), "House fixture constructed")
	fixture.free()
	print("PASS: roof dimensions, rotation, save/load and four flush Barn attachments" if failures.is_empty() else "FAIL: roof kit")
	quit(0 if failures.is_empty() else 1)
