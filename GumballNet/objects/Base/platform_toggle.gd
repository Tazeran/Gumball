extends Node3D

@export var platform_root_path: NodePath = ^"platform-medium2#StaticBody3D"
@export var mesh_path: NodePath = ^"platform-medium2"
@export var shape_path: NodePath = ^"platform-medium2#StaticBody3D/platform-medium2_StaticBody3D#CollisionShape3D"

@onready var platform: StaticBody3D = get_node(platform_root_path)
@onready var mesh: MeshInstance3D = get_node(mesh_path)
@onready var col: CollisionShape3D = get_node(shape_path)

@export var my_state: bool = true

#func _ready() -> void:
	#set_enabled()

func set_enabled(enabled: bool) -> void:
	# disable or enable collisions
	col.set_deferred("disabled", not enabled)
	my_state = enabled
	# manually toggle collision layers and mask (no ternary operator)
	if enabled:
		platform.collision_layer = 1
		platform.collision_mask = 1
	else:
		platform.collision_layer = 0
		platform.collision_mask = 0

	# toggle visibility
	mesh.visible = enabled

func _on_switch_toggled(new_state: bool) -> void:
	set_enabled(not my_state)
