extends RefCounted
## One authored stake for every field edge and construction corner.
const SCENE = preload("res://data/settlement/stick.tscn")
const Illustration = preload("res://scripts/settlement/illustration_style.gd")
static var shape: Mesh
static var material: Material
static var pose := Transform3D.IDENTITY

static func prepare() -> void:
	if shape != null: return
	var source := SCENE.instantiate()
	var stem: MeshInstance3D = source.get_node("Stem")
	shape = stem.mesh
	material = stem.get_active_material(0)
	pose = stem.transform
	source.free()

static func apply(node: MeshInstance3D) -> void:
	prepare()
	node.mesh = shape
	node.material_override = Illustration.flat(material)
	node.scale = Vector3.ONE
