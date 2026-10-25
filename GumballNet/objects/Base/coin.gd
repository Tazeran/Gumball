extends Area3D

var time := 0.0
var grabbed := false

func _ready():
	add_to_group("network_pickups")

# Collecting coins

func _on_body_entered(body):
	var session = get_node_or_null("/root/NetworkSession")
	if session and not bool(session.get("IsDedicatedServer")) and not Array(session.get("LocalPlayerSlots")).is_empty():
		return
	if body.has_method("collect_coin") and !grabbed:
		
		body.collect_coin()
		
		Audio.play("res://sounds/coin.ogg") # Play sound
		
		$Mesh.queue_free() # Make invisible
		$Particles.emitting = false # Stop emitting stars
		
		grabbed = true

func is_network_active() -> bool:
	return not grabbed

func set_network_active(active: bool) -> void:
	grabbed = not active
	$Mesh.visible = active
	monitoring = active

# Rotating, animating up and down

func _process(delta):
	
	rotate_y(2 * delta) # Rotation
	position.y += (cos(time * 5) * 1) * delta # Sine movement
	
	time += delta
