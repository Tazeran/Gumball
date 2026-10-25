extends CharacterBody3D
class_name BeetleEnemy

signal defeated

const DISSOLVE_MATERIAL := preload("res://shared/shaders/monster_disolve.tres")

enum State { IDLE, PATROL, CHASE, REST, DEFEATED }

@export_category("Movement")
@export var patrol_speed := 1.6
@export var chase_speed := 3.4
@export var acceleration := 12.0
@export var turn_speed := 9.0
@export var patrol_radius := 5.0
@export var idle_time_range := Vector2(1.0, 2.5)
@export var patrol_time_range := Vector2(2.5, 5.0)

@export_category("Combat")
@export var contact_damage := 1
@export var attack_cooldown := 0.9
@export var chase_stamina := 5.0
@export var rest_duration := 1.5

@onready var _reaction_animation: AnimationPlayer = $ReactionLabel/AnimationPlayer
@onready var _detection_area: Area3D = $PlayerDetectionArea
@onready var _skin: Node3D = $BeetlebotSkin
@onready var _mesh: MeshInstance3D = $BeetlebotSkin/beetle_bot/Armature/Skeleton3D/Beetle
@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _defeat_sound: AudioStreamPlayer3D = $DefeatSound

var _state := State.IDLE
var _spawn_position := Vector3.ZERO
var _patrol_target := Vector3.ZERO
var _state_timer := 0.0
var _stamina := 0.0
var _attack_timer := 0.0
var _path_timer := 0.0
var _target: Player
var _players_in_range: Array[Player] = []
var _alive := true


func _ready() -> void:
	add_to_group("enemies")
	_spawn_position = global_position
	_stamina = chase_stamina
	_state_timer = randf_range(idle_time_range.x, idle_time_range.y)
	_agent.path_desired_distance = 0.35
	_agent.target_desired_distance = 0.8
	_detection_area.body_entered.connect(_on_detection_body_entered)
	_detection_area.body_exited.connect(_on_detection_body_exited)
	_skin.idle()


func _physics_process(delta: float) -> void:
	if not _alive:
		return

	_attack_timer = maxf(0.0, _attack_timer - delta)
	_state_timer -= delta
	_path_timer -= delta
	_validate_target()

	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -0.5

	match _state:
		State.IDLE:
			_slow_to_stop(delta)
			_skin.idle()
			_stamina = minf(chase_stamina, _stamina + delta)
			if _target:
				_enter_chase()
			elif _state_timer <= 0.0:
				_begin_patrol()

		State.PATROL:
			_skin.walk()
			_stamina = minf(chase_stamina, _stamina + delta * 0.75)
			if _target:
				_enter_chase()
			elif _state_timer <= 0.0 or _agent.is_navigation_finished():
				_enter_idle()
			else:
				_follow_path(patrol_speed, delta)

		State.CHASE:
			if not _target:
				_enter_idle()
			elif _stamina <= 0.0:
				_enter_rest()
			else:
				_skin.walk()
				_stamina = maxf(0.0, _stamina - delta)
				if _path_timer <= 0.0:
					_agent.target_position = _target.global_position
					_path_timer = 0.15
				_follow_path(chase_speed, delta)

		State.REST:
			_slow_to_stop(delta)
			_skin.idle()
			_stamina = minf(chase_stamina, _stamina + delta * 2.0)
			if _state_timer <= 0.0:
				if _target:
					_enter_chase()
				else:
					_enter_idle()

	move_and_slide()
	_handle_contacts()


func _follow_path(speed: float, delta: float) -> void:
	if _agent.is_navigation_finished():
		_slow_to_stop(delta)
		return

	var next_position := _agent.get_next_path_position()
	var direction := next_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0025:
		_slow_to_stop(delta)
		return

	direction = direction.normalized()
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	var desired_yaw := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, turn_speed * delta)


func _slow_to_stop(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)


func _handle_contacts() -> void:
	if _attack_timer > 0.0:
		return

	for index in get_slide_collision_count():
		var player := get_slide_collision(index).get_collider() as Player
		if not player:
			continue
		# A descending player is resolved by the landing impact, never as contact damage.
		if player.is_ground_pounding:
			return
		player.take_damage(contact_damage, global_position)
		_skin.attack()
		_attack_timer = attack_cooldown
		return


func _begin_patrol() -> void:
	_state = State.PATROL
	_state_timer = randf_range(patrol_time_range.x, patrol_time_range.y)
	var offset := Vector3(randf_range(-patrol_radius, patrol_radius), 0.0, randf_range(-patrol_radius, patrol_radius))
	_patrol_target = _spawn_position + offset
	_agent.target_position = _patrol_target


func _enter_idle() -> void:
	_state = State.IDLE
	_state_timer = randf_range(idle_time_range.x, idle_time_range.y)


func _enter_chase() -> void:
	_state = State.CHASE
	_path_timer = 0.0


func _enter_rest() -> void:
	_state = State.REST
	_state_timer = rest_duration


func _validate_target() -> void:
	_players_in_range = _players_in_range.filter(func(player: Player): return is_instance_valid(player))
	if _target and not _players_in_range.has(_target):
		_target = null
	if not _target and not _players_in_range.is_empty():
		_target = _closest_player()


func _closest_player() -> Player:
	var closest: Player
	var closest_distance := INF
	for player in _players_in_range:
		var distance := global_position.distance_squared_to(player.global_position)
		if distance < closest_distance:
			closest = player
			closest_distance = distance
	return closest


func receive_ground_pound(player: Player, impact_speed: float) -> void:
	if not _alive:
		return
	var direction := global_position - player.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		direction = Vector3.FORWARD
	defeat(direction.normalized(), impact_speed)


func damage(_impact_point: Vector3, force: Vector3) -> void:
	# Compatibility with existing damageable interactions.
	defeat(Vector3(force.x, 0.0, force.z).normalized(), force.length())


func defeat(knockback_direction := Vector3.ZERO, impact_speed := 12.0) -> void:
	if not _alive:
		return

	_alive = false
	_state = State.DEFEATED
	velocity = Vector3.ZERO
	_detection_area.monitoring = false
	_defeat_sound.play()
	_skin.power_off()
	defeated.emit()

	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)

	var shove := knockback_direction * minf(impact_speed * 0.04, 0.8)
	var fall_tween := create_tween().set_parallel(true)
	fall_tween.tween_property(self, "position", position + shove + Vector3.UP * 0.25, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fall_tween.tween_property(_skin, "rotation:z", deg_to_rad(85.0), 0.28).set_trans(Tween.TRANS_BACK)
	await fall_tween.finished
	await get_tree().create_timer(0.55).timeout
	await _dissolve_and_remove()


func _dissolve_and_remove() -> void:
	var dissolve := DISSOLVE_MATERIAL.duplicate() as ShaderMaterial
	var source_material := _mesh.get_active_material(0)
	if source_material and source_material.get("albedo_texture"):
		dissolve.set_shader_parameter("albedo_texture", source_material.get("albedo_texture"))
	dissolve.set_shader_parameter("dissolve_amount", 0.0)
	for surface in _mesh.get_surface_override_material_count():
		_mesh.set_surface_override_material(surface, dissolve)

	var tween := create_tween()
	tween.tween_method(func(value: float): dissolve.set_shader_parameter("dissolve_amount", value), 0.0, 1.0, 0.8)
	await tween.finished
	queue_free()


func _on_detection_body_entered(body: Node3D) -> void:
	var player := body as Player
	if not player or _players_in_range.has(player):
		return
	_players_in_range.append(player)
	_target = _closest_player()
	_reaction_animation.play("found_player")
	_enter_chase()


func _on_detection_body_exited(body: Node3D) -> void:
	var player := body as Player
	if not player:
		return
	_players_in_range.erase(player)
	if _target == player:
		_target = _closest_player() if not _players_in_range.is_empty() else null
	if not _target:
		_reaction_animation.play("lost_player")
		_enter_idle()
