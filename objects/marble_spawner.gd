extends Node3D

@export var marble_scene: PackedScene
@export_range(0.1, 10.0) var spawn_interval: float = 2.0
@export var max_marbles: int = 10
@export var y_gizmo_radius: float = 0.25

var _timer := 0.0
var _marble_count := 0

func _process(delta):
	if marble_scene == null:
		return

	_timer += delta
	if _timer >= spawn_interval:
		_timer = 0.0
		if _marble_count < max_marbles:
			spawn_marble()

func spawn_marble():
	var marble = marble_scene.instantiate()
	marble.spawner = self
	get_tree().current_scene.add_child(marble)
	marble.global_transform.origin = global_transform.origin
	_marble_count += 1
	print("MCC: ", _marble_count)


func _on_marble_deleted():
	_marble_count -= 1
	print("MCD: ", _marble_count)

#func _notification(what):
	#if Engine.is_editor_hint():
		#if what == NOTIFICATION_TRANSFORM_CHANGED or what == NOTIFICATION_READY:
			#update_gizmo()
#
#func update_gizmo():
	#if !is_inside_tree():
		#return
	#var debug_draw := get_viewport().get_debug_draw()
	#if debug_draw:
		#debug_draw.draw_sphere(global_transform.origin, y_gizmo_radius, Color.GREEN)
