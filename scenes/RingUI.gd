@tool
extends Control



@export_range(0.0, 1.0)
var stamina: float = 0.6:
	set(value):
		stamina = value
		queue_redraw()
		
@export
var radius: float = 30.0:
	set(value):
		radius = value
		queue_redraw()



func _ready():
	queue_redraw()

func _get_minimum_size() -> Vector2:
	return Vector2(200, 200)

func _draw():
	# Draw background circle for reference
	draw_arc(size / 2, radius, 0, TAU, 100, Color.DARK_GRAY, 10)

	# Draw stamina arc
	var center = size / 2
	var start_angle = deg_to_rad(0)
	var angle_length = deg_to_rad(360.0 * stamina)

	draw_arc(center, radius, start_angle, angle_length, 100, Color.GREEN, 10)

	# Draw bounding rect (debug)
	#draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0, 0, 0.1), true)
