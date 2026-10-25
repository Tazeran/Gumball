extends Node3D

enum PlatformPhase { IDLE, FALLING, WAITING_TO_RESPAWN }

@export var fall_acceleration := 15.0
@export var respawn_delay := 3.0

var phase: PlatformPhase = PlatformPhase.IDLE
var phase_elapsed := 0.0
var state_revision := 0
var start_position := Vector3.ZERO
var start_scale := Vector3.ONE
var _network_revision := -1
var _is_online_client := false

func _ready() -> void:
	add_to_group("network_falling_platforms")
	start_position = position
	start_scale = scale
	var session := get_node_or_null("/root/NetworkSession")
	_is_online_client = session != null and not bool(session.get("IsDedicatedServer")) \
		and not Array(session.get("LocalPlayerSlots")).is_empty()

func _process(delta: float) -> void:
	match phase:
		PlatformPhase.IDLE:
			return
		PlatformPhase.FALLING:
			phase_elapsed += delta
			# Elapsed-time motion is smooth between packets and independent of FPS.
			position = start_position + Vector3.DOWN * (0.5 * fall_acceleration * phase_elapsed * phase_elapsed)
			var pulse_scale := start_scale * Vector3(1.25, 1.0, 1.25)
			scale = pulse_scale.lerp(start_scale, clampf(phase_elapsed * 10.0, 0.0, 1.0))
			if position.y < -10.0:
				_set_phase(PlatformPhase.WAITING_TO_RESPAWN, not _is_online_client)
		PlatformPhase.WAITING_TO_RESPAWN:
			phase_elapsed += delta
			if phase_elapsed >= respawn_delay:
				_set_phase(PlatformPhase.IDLE, not _is_online_client)

func _set_phase(next_phase: PlatformPhase, authoritative: bool) -> void:
	phase = next_phase
	phase_elapsed = 0.0
	if authoritative:
		state_revision += 1
	match phase:
		PlatformPhase.IDLE:
			position = start_position
			scale = start_scale
		PlatformPhase.FALLING:
			scale = start_scale * Vector3(1.25, 1.0, 1.25)
			Audio.play("res://sounds/fall.ogg")
		PlatformPhase.WAITING_TO_RESPAWN:
			pass

func _on_area_3d_body_entered(body: Node) -> void:
	if _is_online_client or not body is Player or phase != PlatformPhase.IDLE:
		return
	_set_phase(PlatformPhase.FALLING, true)

func get_network_state() -> Array:
	return [int(phase), phase_elapsed, state_revision]

func apply_network_state(next_phase: int, elapsed: float, revision: int) -> void:
	if not _is_online_client or revision == _network_revision:
		return
	_network_revision = revision
	phase = next_phase as PlatformPhase
	phase_elapsed = maxf(0.0, elapsed)
	match phase:
		PlatformPhase.IDLE:
			position = start_position
			scale = start_scale
		PlatformPhase.FALLING:
			Audio.play("res://sounds/fall.ogg")
		PlatformPhase.WAITING_TO_RESPAWN:
			pass
