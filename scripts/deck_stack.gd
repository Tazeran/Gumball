# DeckStack.gd (base class)
class_name DeckStack
extends Node3D

@export var cards: Array[Node3D] = []

func push_card(card: Node3D):
	cards.append(card)
	arrange_cards()

func pop_card() -> Node3D:
	if cards.size() > 0:
		return cards.pop_back()
	return null

func top_card() -> Node3D:
	return cards[-1] if cards.size() > 0 else null

func arrange_cards():
	# Default: stack flat
	for i in range(cards.size()):
		var card = cards[i]
		card.mount_target = self
		card.mount_offset = Transform3D(Basis(), Vector3(0, 0.01 * i, 0))
