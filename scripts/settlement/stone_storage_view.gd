extends RefCounted
const Stone = preload("res://scripts/settlement/stone_view.gd")
const Palette = preload("res://scripts/game_palette.gd")
const PAD_HEIGHT := 0.16

static func slot_position(index: int, height := PAD_HEIGHT) -> Vector3:
	@warning_ignore("integer_division")
	return Vector3((index % 3 - 1) * 0.9, height, (index / 3 % 3 - 1) * 0.9)

static func pad_mesh() -> ArrayMesh:
	var box := BoxMesh.new(); box.size = Vector3(3, PAD_HEIGHT, 3)
	var arrays := box.surface_get_arrays(0)
	var colours := PackedColorArray()
	for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
		colours.append(Palette.SAND_SURFACE if normal.y > 0.5 else Palette.PEACH_SHADOW)
	arrays[Mesh.ARRAY_COLOR] = colours
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func sync(node: Node3D, tier: int) -> void:
	if node.has_meta("depot_grid"): return
	node.get_node("Beams").visible = tier >= 2
	node.get_node("Enclosure").visible = tier == 3

static var stock_cache: Dictionary={}
static func stock_layout(inventory,cell: Vector3i,world_seed: int) -> Array[Dictionary]:
	var key: String=str([cell,world_seed,inventory.slots])
	if stock_cache.has(key): return stock_cache[key]
	var result: Array[Dictionary]=[]
	var heights: Array[float]=[]; heights.resize(9); heights.fill(PAD_HEIGHT)
	for index in inventory.slots.size():
		var resource: String=inventory.slots[index]
		if resource.is_empty(): continue
		var seed_value:=Stone.Random.world_coordinate_seed(cell.x,cell.z,world_seed,610+index)
		var mesh: Mesh=Stone.block_mesh(seed_value) if resource=="block" else Stone.raw_mesh(seed_value)
		var bounds:=mesh.get_aabb(); var column: int=index%9
		var at:=slot_position(index,heights[column]); at.y-=bounds.position.y*0.75
		heights[column]=at.y+bounds.end.y*0.75
		result.append({"index":index,"resource":resource,"mesh":mesh,"pose":Transform3D(Basis.from_scale(Vector3.ONE*0.75),at)})
	if stock_cache.size()>128: stock_cache.clear()
	stock_cache[key]=result
	return result
static func sync_stock(node: Node3D,inventory,cell: Vector3i,world_seed: int) -> void:
	var stock:=node.get_node_or_null("EconomyStock") as Node3D
	if stock==null:
		stock=Node3D.new(); stock.name="EconomyStock"; node.add_child(stock)
	var kept: Dictionary={}
	for item in stock_layout(inventory,cell,world_seed):
		var label: String="Slot%d"%item.index; kept[label]=true
		var cargo:=stock.get_node_or_null(label) as MeshInstance3D
		if cargo==null:
			cargo=MeshInstance3D.new(); cargo.name=label; stock.add_child(cargo)
		cargo.set_meta("resource",item.resource); cargo.set_meta("storage_slot",item.index)
		cargo.mesh=item.mesh; cargo.material_override=Stone.material(); cargo.transform=item.pose
	for child in stock.get_children():
		if not kept.has(str(child.name)): child.free()
