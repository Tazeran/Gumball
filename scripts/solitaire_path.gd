@tool
extends Node3D

var pending_rebuild := false
var rebuild_timer := 0.0
const REBUILD_DELAY := 0.5  # seconds to wait after last edit

@export var path: Path3D
@export var decal_scene: PackedScene
var decal_count: int = 13

var decals: Array[Node3D] = []
var curve_connected: bool = false

func _ready():
	_rebuild_decals()
	if Engine.is_editor_hint():
		_connect_curve()

func _enter_tree():
	_connect_curve()
	
func _exit_tree():
	_disconnect_curve()

func _process(delta):
	if not Engine.is_editor_hint():
		return

	if pending_rebuild:
		rebuild_timer += delta
		if rebuild_timer >= REBUILD_DELAY:
			#print("Rebuilding decals now!")
			_rebuild_decals()
			pending_rebuild = false

func _connect_curve():
	_disconnect_curve()
	if path and path.curve:
		path.curve.changed.connect(_on_curve_changed)
		curve_connected = true

func _disconnect_curve():
	if curve_connected and path and path.curve:
		path.curve.changed.disconnect(_on_curve_changed)
	curve_connected = false
	
func _on_curve_changed():
	if not Engine.is_editor_hint():
		return

	#print("Curve changed! Scheduling decal rebuild...")
	pending_rebuild = true
	rebuild_timer = 0.0  # reset timer

func _notification(what):
	if not Engine.is_editor_hint():
		return

	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_on_transform_changed()

func _on_transform_changed():
	print("Parent Node moved! Scheduling decal rebuild...")
	pending_rebuild = true
	rebuild_timer = 0.0  # reset delay timer

func _rebuild_decals():
	if not path or not decal_scene or not path.curve:
		return

	path.curve.bake_interval = 0.1

	var curve = path.curve
	var path_length = curve.get_baked_length()

	# Only spawn more decals if needed
	while decals.size() < decal_count:
		var decal_instance = decal_scene.instantiate()
		add_child(decal_instance)
		decals.append(decal_instance)

	# If there are too many decals, hide extras
	for i in range(decals.size()):
		var decal_instance = decals[i]
		if i >= decal_count:
			decal_instance.visible = false
			continue

		decal_instance.visible = true

		var t = i / float(decal_count - 1)
		var distance_along_path = t * path_length

		var local_transform = curve.sample_baked_with_rotation(distance_along_path)
		var global_transform = path.global_transform * local_transform
		var position = global_transform.origin
		var direction = global_transform.basis.x.normalized()

		var basis = Basis()
		basis.y = -Vector3.UP
		basis.x = direction
		basis.z = basis.x.cross(basis.y).normalized()
		basis.x = basis.y.cross(basis.z).normalized()

		decal_instance.global_transform = Transform3D(basis, position)
