extends Control

@export var heart_empty_texture: Texture2D
@export var heart_half_texture: Texture2D
@export var heart_full_texture: Texture2D

var health: int = 6  # Max health in half-hearts (6 = 3 full hearts)
var health_max: int = 6
@onready var container = $Hearts

func _ready():
	update_hearts()

func set_health(val: int, val_max: int):
	health = clamp(val, 0, health_max)
	health_max = max(1, val_max)
	update_hearts()


func update_hearts():
	print(container)
	if !container:
		return
	for child in container.get_children():
		child.queue_free()

	var hearts_needed = int(ceil(health_max / 2.0))

	for i in range(hearts_needed):
		var heart = TextureRect.new()
		#heart.expand = true
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		heart.custom_minimum_size = Vector2(64, 64)

		var heart_index = i * 2

		if health >= heart_index + 2:
			heart.texture = heart_full_texture
		elif health == heart_index + 1:
			heart.texture = heart_half_texture
		else:
			heart.texture = heart_empty_texture

		container.add_child(heart)
