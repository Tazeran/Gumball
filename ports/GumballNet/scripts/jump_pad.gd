extends Node3D

@export var bounce_force := 20.0

@onready var area: Area3D = $Area3D

func _ready():
	area.body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	print("_on_body_entered ", self)
	if body is Player:
		body.gravity = -bounce_force
