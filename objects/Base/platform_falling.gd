extends Node3D

var falling := false
var gravity := 0.0
var respawn_timer := 0.0
var respawn_delay := 3.0  # How many seconds before respawning
var start_position := Vector3.ZERO
var start_scale := Vector3.ONE

func _ready():
	start_position = position
	start_scale = scale

func _process(delta):
	if falling:
		gravity += 0.25
		position.y -= gravity * delta
		
		scale = scale.lerp(Vector3(1, 1, 1), delta * 10) # Animate scale back toward normal
		
		if position.y < -10:
			start_respawn_timer()

	if respawn_timer > 0:
		respawn_timer -= delta
		if respawn_timer <= 0:
			respawn()

func start_respawn_timer():
	falling = false
	gravity = 0
	respawn_timer = respawn_delay

func respawn():
	position = start_position
	scale = start_scale
	gravity = 0
	falling = false

func _on_area_3d_body_entered(_body) -> void:
	if !falling:
		Audio.play("res://sounds/fall.ogg") # Play sound
		scale = Vector3(1.25, 1, 1.25) # Animate scale
		falling = true
