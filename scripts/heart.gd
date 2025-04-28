extends Area3D

var time := 0.0
var grabbed := false

# Collecting coins

func _on_body_entered(body):
	if body.has_method("collect_heart") and !grabbed:
		
		body.collect_heart()
		
		Audio.play("res://sounds/coin.ogg") # Play sound
		
		$heart.queue_free() # Make invisible
		$Particles.emitting = false # Stop emitting stars
		
		grabbed = true

# Rotating, animating up and down

func _process(delta):
	
	rotate_y(2 * delta) # Rotation
	position.y += (cos(time * 5) * 1) * delta # Sine movement
	
	time += delta
