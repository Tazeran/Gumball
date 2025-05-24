extends Control

@export var device: int = 0

func _process(_delta: float) -> void:
	queue_redraw()
	#for i in range(20):  # Check up to 20 buttons
		#if Input.is_joy_button_pressed(device, i):
			#print(device, " Button ", i, " pressed")
	#for a in range(6):  # Check axes
		#print("Axis", a, ":", Input.get_joy_axis(0, a))

func _draw() -> void:
	var size = Vector2(81, 69)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.15, 0.15, 0.15, 0.45))

	draw_trigger(Vector2(5, 5), Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT))
	draw_bumper(Vector2(5, 17), Input.is_joy_button_pressed(device, JOY_BUTTON_LEFT_SHOULDER))

	draw_trigger(Vector2(52, 5), Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT))
	draw_bumper(Vector2(52, 17), Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER))

	var dpad_pos = Vector2(18, 38)  # adjust for your overall layout
	draw_dpad_arrow(dpad_pos + Vector2(-11, 4.5), deg_to_rad(-90.0), Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT))  # Left
	draw_dpad_arrow(dpad_pos + Vector2(-4.5, -11), deg_to_rad(0.0), Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP))      # Up
	draw_dpad_arrow(dpad_pos + Vector2(11, -4.5), deg_to_rad(90.0), Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT))   # Right
	draw_dpad_arrow(dpad_pos + Vector2(4.5, 11), deg_to_rad(180.0), Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN))   # Down

	draw_joystick(Vector2(30, 56), Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y), Input.is_joy_button_pressed(device, JOY_BUTTON_LEFT_STICK))
	draw_joystick(Vector2(49, 56), Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y), Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_STICK))

	var face_pos = Vector2(49, 25)
	draw_face_button(face_pos + Vector2(1, 9), Input.is_joy_button_pressed(device, JOY_BUTTON_X))
	draw_face_button(face_pos + Vector2(9, 1), Input.is_joy_button_pressed(device, JOY_BUTTON_Y))
	draw_face_button(face_pos + Vector2(17, 9), Input.is_joy_button_pressed(device, JOY_BUTTON_B))
	draw_face_button(face_pos + Vector2(9, 17), Input.is_joy_button_pressed(device, JOY_BUTTON_A))

	draw_option_button(Vector2(33, 27), Input.is_joy_button_pressed(device, JOY_BUTTON_BACK))
	draw_option_button(Vector2(42, 27), Input.is_joy_button_pressed(device, JOY_BUTTON_START))

func draw_option_button(pos: Vector2, pressed: bool) -> void:
	var color := Color.WHITE
	if pressed:
		color = Color.RED
	draw_rect(Rect2(pos, Vector2(6, 5)), Color.BLACK)
	draw_rect(Rect2(pos + Vector2.ONE, Vector2(4, 3)), color)

func draw_dpad_arrow(pos: Vector2, angle: float, pressed: bool) -> void:
	var color := Color.RED if pressed else Color.WHITE
	var width := 9.0
	var height := 9.0

	# Define arrow pointing "down" around the origin
	var local_points = [
		Vector2(0, 0),
		Vector2(width, 0),
		Vector2(width, height / 2),
		Vector2(width / 2, height),
		Vector2(0, height / 2)
	]

	# Rotate and translate the points
	var rotated_points: Array = []
	for p in local_points:
		var rotated = p.rotated(angle)
		rotated_points.append(rotated + pos)

	# Close the shape
	rotated_points.append(rotated_points[0])

	draw_polygon(rotated_points, [color])
	draw_polyline(rotated_points, Color.BLACK)


func draw_face_button(pos: Vector2, pressed: bool) -> void:
	var r := 5
	var color := Color.WHITE
	if pressed:
		color = Color.RED
	draw_circle(pos + Vector2(r, r), r, Color.BLACK)
	draw_circle(pos + Vector2(r, r), r - 1, color)

func draw_bumper(pos: Vector2, pressed: bool) -> void:
	var size = Vector2(24, 6)
	var color := Color.WHITE
	if pressed:
		color = Color.RED
	draw_rect(Rect2(pos, size), Color.BLACK)
	draw_rect(Rect2(pos + Vector2.ONE, size - Vector2(2, 2)), color)

func draw_trigger(pos: Vector2, value: float) -> void:
	var size = Vector2(24, 10)
	draw_rect(Rect2(pos, size), Color.BLACK)
	draw_rect(Rect2(pos + Vector2.ONE, size - Vector2(2, 2)), Color.WHITE)
	draw_rect(Rect2(pos + Vector2.ONE, Vector2(size.x - 2, (size.y - 2) * value)), Color.RED)

func draw_joystick(pos: Vector2, ax: float, ay: float, pressed: bool) -> void:
	var radius := 8
	var dist := 4
	var color := Color.WHITE
	if pressed:
		color = Color.RED

	draw_circle(pos, radius, Color.BLACK)
	draw_circle(pos, radius - 1, Color.GRAY)

	var offset = Vector2(ax, ay) * dist
	draw_circle(pos + offset, radius - 2, Color.BLACK)
	draw_circle(pos + offset, radius - 3, color)

# Axis/button constants
const JOY_AXIS_LEFT_X := 0
const JOY_AXIS_LEFT_Y := 1
const JOY_AXIS_RIGHT_X := 2
const JOY_AXIS_RIGHT_Y := 3
const JOY_AXIS_TRIGGER_LEFT := 4
const JOY_AXIS_TRIGGER_RIGHT := 5

const JOY_BUTTON_A := 0
const JOY_BUTTON_B := 1
const JOY_BUTTON_X := 2
const JOY_BUTTON_Y := 3
const JOY_BUTTON_LEFT_SHOULDER := 9
const JOY_BUTTON_RIGHT_SHOULDER := 10
const JOY_BUTTON_BACK := 4
const JOY_BUTTON_START := 6
const JOY_BUTTON_LEFT_STICK := 7
const JOY_BUTTON_RIGHT_STICK := 8
const JOY_BUTTON_DPAD_UP := 11
const JOY_BUTTON_DPAD_DOWN := 12
const JOY_BUTTON_DPAD_LEFT := 13
const JOY_BUTTON_DPAD_RIGHT := 14
