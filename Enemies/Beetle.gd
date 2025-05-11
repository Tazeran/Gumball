extends RigidBody3D

#const COIN_SCENE := preload("res://Player/Coin/Coin.tscn")
#const PUFF_SCENE := preload("smoke_puff/smoke_puff.tscn")
const DISSOLVE_MATERIAL := preload("res://shared/shaders/monster_disolve.tres")
var _original_albedo: Texture2D
var _dissolve_mat: ShaderMaterial

const move_speed = 3;

@onready var _reaction_animation_player: AnimationPlayer = $ReactionLabel/AnimationPlayer
@onready var _detection_area: Area3D = $PlayerDetectionArea
@onready var _beetle_skin: Node3D = $BeetlebotSkin
@onready var _beetle_mesh: MeshInstance3D = $BeetlebotSkin/beetle_bot/Armature/Skeleton3D/Beetle
@onready var _navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var _death_collision_shape: CollisionShape3D = $DeathCollisionShape
@onready var _defeat_sound: AudioStreamPlayer3D = $DefeatSound

@onready var _target: Node3D = null
@onready var _alive: bool = true


func _ready() -> void:
	add_to_group("enemies")
	# Cache original texture for this beetle
	_original_albedo = _beetle_mesh.get_active_material(0).get("albedo_texture")

	# Duplicate shared shader material
	#_dissolve_mat = DISSOLVE_MATERIAL.duplicate()
	#_dissolve_mat.set_shader_parameter("albedo_texture", _original_albedo)
	#_beetle_mesh.set_surface_override_material(0, _dissolve_mat)

	_detection_area.body_entered.connect(_on_body_entered)
	_detection_area.body_exited.connect(_on_body_exited)
	_beetle_skin.idle()


func _physics_process(delta: float) -> void:
	if not _alive:
		return

	if _target != null:
		_beetle_skin.walk()
		var target_look_position := _target.global_position
		target_look_position.y = global_position.y
		if target_look_position != Vector3.ZERO:
			look_at(target_look_position)

		_navigation_agent.target_position = _target.global_position

		var next_location := _navigation_agent.get_next_path_position()

		if not _navigation_agent.is_target_reached():
			var direction := (next_location - global_position)
			direction.y = 0
			direction = direction.normalized()

			var collision := move_and_collide(direction * delta * move_speed)
			if collision:
				var collider := collision.get_collider()
				if collider is Player:
					if collider.is_ground_pounding:
						print("Beetle hit by ground pound!")
						var impact_point = global_position - collider.global_position
						var force = Vector3.UP * 6  # Upward impulse
						damage(impact_point, force)
					else:
						# Standard bump damage to player
						var impact_point: Vector3 = global_position - collider.global_position
						var force := -impact_point
						force.y = 0.5
						force *= 10.0
						collider.take_damage(1, global_position)
						_beetle_skin.attack()



func damage(impact_point: Vector3, force: Vector3) -> void:
	lock_rotation = false
	force = force.limit_length(3.0)
	apply_impulse(force, impact_point)

	if not _alive:
		return

	_defeat_sound.play()
	_alive = false
	_beetle_skin.power_off()

	_detection_area.body_entered.disconnect(_on_body_entered)
	_detection_area.body_exited.disconnect(_on_body_exited)
	_target = null
	_death_collision_shape.set_deferred("disabled", false)


	#axis_lock_angular_x = false
	#axis_lock_angular_y = false
	#axis_lock_angular_z = false
	gravity_scale = 1.0

	await get_tree().create_timer(2).timeout

	#var puff := PUFF_SCENE.instantiate()
	#get_parent().add_child(puff)
	#puff.global_position = global_position
	#await puff.full
	#for i in range(coins_count):
		#var coin := COIN_SCENE.instantiate()
		#get_parent().add_child(coin)
		#coin.global_position = global_position
		#coin.spawn()
	#await get_tree().create_timer(1.0).timeout  # Delay before dissolve
	disable_all_collisions(self)
	gravity_scale = 0.2
	_beetle_mesh.set_surface_override_material(0, DISSOLVE_MATERIAL)
	_beetle_mesh.set_surface_override_material(1, DISSOLVE_MATERIAL)
	_beetle_mesh.set_surface_override_material(2, DISSOLVE_MATERIAL)
	#_beetle_mesh.material_overlay = DISSOLVE_MATERIAL
	# Animate dissolve over 1 second
	for i in range(30):
		var t = i / 30.0
		DISSOLVE_MATERIAL.set_shader_parameter("dissolve_amount", t)
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(0.1).timeout
	queue_free()

func disable_all_collisions(root: Node):
	for child in root.get_children():
		if child is CollisionShape3D:
			child.disabled = true
		elif child.get_child_count() > 0:
			disable_all_collisions(child)

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		print("beetle _on_body_entered ", body)
		_target = body
		_reaction_animation_player.play("found_player")


func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		_target = null
		_reaction_animation_player.play("lost_player")
		_beetle_skin.idle()
