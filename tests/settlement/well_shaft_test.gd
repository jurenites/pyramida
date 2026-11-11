extends SceneTree
const Fixture = preload("res://tests/settlement/reviewed_balance_test.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Shaft = preload("res://scripts/settlement/well_shaft.gd")
const Well = preload("res://scripts/settlement/well_view.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var helper = Fixture.new(); var model = helper.fixture()
	model.Hydrology.populate(model, {Vector3i.ZERO: "puddle"})
	var view := Node3D.new(); root.add_child(view)
	var well := Assets.create("well"); view.add_child(well)
	for tier in [1, 2, 3]:
		helper.finish(model, "well", Vector3i.ZERO)
		Well.sync(well, tier, 3, tier * 3)
		check(well.get_node("Canopy").visible == (tier == 3), "Roof only at third stage")
		check(well.get_node("WellPost").visible == (tier == 3), "Posts only at third stage")
		var top := 0.0
		for part: MeshInstance3D in well.find_children("WellStone*", "MeshInstance3D", true, false):
			if part.visible: top = maxf(top, (part.transform * part.mesh.get_aabb()).end.y)
		check(top < 0.09 if tier == 1 else top > 0.45 and top < 0.56, "Low first rim; half-metre stone walls")
		Shaft.sync(view, model, {"kind": "well", "cell": Vector3i.ZERO, "entity_key": "well:0"})
		var shaft := view.get_node("HoveredWellShaft")
		check(shaft.visible and is_equal_approx(shaft.get_meta("depth_m"), tier * 2.0 / 3.0), "Correct hover depth")
		check(is_equal_approx(shaft.get_meta("water_height"), (tier * 2.0 / 3.0 - 0.12) / tier), "Actual preserved water fraction")
		var original: Mesh = shaft.get_node("Shaft").mesh
		Shaft.sync(view, model, {"kind": "well", "cell": Vector3i.ZERO})
		check(original == shaft.get_node("Shaft").mesh, "No per-frame geometry rebuild")
		Shaft.sync(view, model, {})
		check(not shaft.visible, "Cutaway hidden when not hovering")
		Shaft.sync(view, model, {"kind": "well", "cell": Vector3i.ZERO, "entity_key": "plan:1"})
		check(not shaft.visible, "Plans do not expose completed shaft")
	check(not model.request_build("well", Vector3i.ZERO), "No fourth stage")
	model.wells[Vector3i.ZERO].amounts.water = 0
	Shaft.sync(view, model, {"kind": "well", "cell": Vector3i.ZERO})
	check(not view.get_node("HoveredWellShaft").has_node("WaterLevel"), "Empty well has no water surface")
	check(view.get_node("HoveredWellShaft").find_children("*", "CollisionObject3D", true, false).is_empty(), "Xray never intercepts pointer")
	helper.save_roundtrip(model); failures.append_array(helper.failures); helper.free(); view.free()
	if failures.is_empty(): print("PASS: Well one-third-depth stages, merging, preserved water, hover lifecycle, save/load")
	else:
		for failure in failures: push_error(failure)
	quit(int(not failures.is_empty()))
