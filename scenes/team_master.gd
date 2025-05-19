extends Node3D
class_name TeamMaster

@export var card_scene: PackedScene  # Your Card.tscn
@export var team_name: String

@export var goalStack: GoalStack
@export var solitaireStack1: SolitairePathStack
@export var solitaireStack2: SolitairePathStack
@export var solitaireStack3: SolitairePathStack
@export var solitaireStack4: SolitairePathStack
@export var stockStack: StockStack
@export var flipStack: FlipStack
@export var cycleInteractable: HoldInteractable

const MAX_CYCLE_CARDS = 3
var deck: Deck

func _ready():
	if cycleInteractable:
		cycleInteractable.hold_completed.connect(_on_cycle_triggered)

func spawn_card(card_data, stack: DeckStack) -> void:
	var card = card_scene.instantiate()
	add_child(card)
	card.set_team(team_name)
	card.set_card(card_data.suit, card_data.rank)
	stack.add_card(card)
	
func deal_hand():
	# TODO: cleanup old cards if replaying, make it's own function
	goalStack.team = team_name
	stockStack.team = team_name
	flipStack.team = team_name
	cycleInteractable.team = team_name
	solitaireStack1.team = team_name
	solitaireStack2.team = team_name
	solitaireStack3.team = team_name
	solitaireStack4.team = team_name

	deck = Deck.new()
	deck.create_full_deck()
	deck.shuffle()
	print("Team ", team_name," deck cards:", deck.cards_remaining())

	# Deal 1 card to 4 solitaire paths
	spawn_card(deck.draw_card(), solitaireStack1)
	spawn_card(deck.draw_card(), solitaireStack2)
	spawn_card(deck.draw_card(), solitaireStack3)
	spawn_card(deck.draw_card(), solitaireStack4)

	for i in range(13): # Deal 13 to goal stack
		spawn_card(deck.draw_card(), goalStack)
	for i in range(35): # Deal 35 to cycle stack
		spawn_card(deck.draw_card(), stockStack)

	#stockStack.scatter_all_cards()
	#goalStack.scatter_all_cards()


func verify_full_deck() -> bool:
	var found_cards := {}
	print("verify_full_deck_for_team: ", team_name)
	for card in get_tree().get_nodes_in_group("cards"):
		if card.team == team_name:
			var key = "%s_%s" % [card.suit, card.rank]
			found_cards[key] = true

	for suit in Deck.SUITS:
		for rank in Deck.RANKS:
			var key = "%s_%s" % [suit, rank]
			if not found_cards.has(key):
				print("Missing card for team %s: %s" % [team_name, key])
				return false

	return true

func _on_cycle_triggered(_player_id: int, _player: Node):
	# Step 1: If deck is empty, flip pile back into deck (face down)
	if stockStack.cards.is_empty():
		while not flipStack.cards.is_empty():
			var card = flipStack.remove_top_card()
			card.set_face_up(false)
			stockStack.add_card(card)
		return

	# Step 2: Flip up to 3 cards from deck to pile
	var flips = min(MAX_CYCLE_CARDS, stockStack.get_card_count())
	for i in range(flips):
		var card = stockStack.remove_top_card()
		card.set_face_up(true)
		flipStack.add_card(card)
