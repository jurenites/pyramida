extends Node3D
## Serialized visual reference for the 3D editor; gameplay builds its own world.
## Deliberately not @tool: this node remains visible in the editor.
func _enter_tree() -> void:
	# Removal is deferred; hide immediately so editor assets never flash in play.
	visible = false
	queue_free()
