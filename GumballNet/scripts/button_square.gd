extends Node3D

signal pressed(active: bool)  # <- SIGNAL: anyone can listen to button presses

@export var is_toggle_button: bool = true  # <- Toggle mode or Momentary mode
@export var is_active: bool = false  # <- Only meaningful for toggle mode

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var area: Area3D = $Area3D

func _ready():
	add_to_group("network_buttons")
	area.body_entered.connect(_on_body_entered)

	# Setup initial animation if in toggle mode
	if is_toggle_button:
		if is_active:
			animation_player.play("toggle-on")
		else:
			animation_player.play("toggle-off")

func _on_body_entered(body):
	var session = get_node_or_null("/root/NetworkSession")
	if session and not bool(session.get("IsDedicatedServer")) and not Array(session.get("LocalPlayerSlots")).is_empty():
		return
	if body.is_in_group("players") and body.is_ground_pounding:
		Audio.play("res://sounds/bookPlace2.ogg")
		press()

func press():
	if is_toggle_button:
		is_active = !is_active  # Flip active state
		if is_active:
			animation_player.play("toggle-on")
		else:
			animation_player.play("toggle-off")
	else:
		# Just play "toggle" animation every press, no state tracking
		animation_player.play("toggle")

	# Emit signal no matter what mode
	emit_signal("pressed", is_active)

func set_network_state(active: bool) -> void:
	if is_active == active:
		return
	is_active = active
	animation_player.play("toggle-on" if is_active else "toggle-off")
	emit_signal("pressed", is_active)
