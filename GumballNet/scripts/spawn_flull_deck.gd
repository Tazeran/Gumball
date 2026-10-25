extends Node3D

@export var card_scene: PackedScene  # Your Card.tscn scene
@export var spacing: Vector3 = Vector3(2.5, 0, 3.5)  # distance between cards

var suits = ["hearts", "diamonds", "clubs", "spades"]
var ranks = ["A", "02", "03", "04", "05", "06", "07", "08", "09", "10", "J", "Q", "K"]

func _ready() -> void:
	spawn_deck()

func spawn_deck() -> void:
	print("spawn_deck")
	var card_index = 0
	for suit in suits:
		for rank in ranks:
			#print(suit, rank,)
			var spinandbob = card_scene.instantiate()
			add_child(spinandbob)
			spinandbob.id = card_index
			
			# Calculate grid position (relative to this node's position)
			var row = card_index / 13
			var col = card_index % 13

			spinandbob.base_position = global_position + Vector3(col * spacing.x, 0, row * spacing.z)
			
			var card = spinandbob.find_child("PlayingCard")
			#card.suit = suit
			#card.rank = rank
			#print(card_index, suit, rank, row, col, spinandbob.base_position, spinandbob)

			# Set the card face
			if card.has_method("set_card"):
				card.set_card(suit, rank)

			card_index += 1
