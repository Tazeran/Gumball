extends Node3D

@export var card_scene: PackedScene  # Your Card.tscn

@export var A_GoalStack: DeckStack
@export var A_CycleStack: DeckStack
@export var A_SolitaireStack1: SolitairePathStack
@export var A_SolitaireStack2: SolitairePathStack
@export var A_SolitaireStack3: SolitairePathStack
@export var A_SolitaireStack4: SolitairePathStack

@export var B_GoalStack: DeckStack
@export var B_CycleStack: DeckStack
@export var B_SolitaireStack1: SolitairePathStack
@export var B_SolitaireStack2: SolitairePathStack
@export var B_SolitaireStack3: SolitairePathStack
@export var B_SolitaireStack4: SolitairePathStack

var team_a_deck: Deck
var team_b_deck: Deck

func _ready():
	await get_tree().process_frame
	deal_team_hand("A", team_a_deck, A_GoalStack, A_CycleStack, A_SolitaireStack1, A_SolitaireStack2, A_SolitaireStack3, A_SolitaireStack4)
	deal_team_hand("B", team_b_deck, B_GoalStack, B_CycleStack, B_SolitaireStack1, B_SolitaireStack2, B_SolitaireStack3, B_SolitaireStack4)
	
	#A_CycleStack.scatter_all_cards()
	#A_GoalStack.scatter_all_cards()
	
	#verify_full_deck_for_team("A")

func spawn_card(team: String, card_data, stack: DeckStack) -> void:
	var card = card_scene.instantiate()
	add_child(card)
	card.set_team(team)
	card.set_card(card_data.suit, card_data.rank)
	stack.add_card(card)
	
func deal_team_hand(team_str: String, deck: Deck, goal_stack: DeckStack, cycle_stack: DeckStack, solitaire1: SolitairePathStack, solitaire2: SolitairePathStack, solitaire3: SolitairePathStack, solitaire4: SolitairePathStack):
	# TODO: cleanup old cards if replaying
	goal_stack.team = team_str
	cycle_stack.team = team_str
	solitaire1.team = team_str
	solitaire2.team = team_str
	solitaire3.team = team_str
	solitaire4.team = team_str


	deck = Deck.new()
	deck.create_full_deck()
	deck.shuffle()
	print("Team ", team_str," deck cards:", deck.cards_remaining())

	# Deal 1 card to 4 solitaire paths
	spawn_card(team_str, deck.draw_card(), solitaire1)
	spawn_card(team_str, deck.draw_card(), solitaire2)
	spawn_card(team_str, deck.draw_card(), solitaire3)
	spawn_card(team_str, deck.draw_card(), solitaire4)

	for i in range(13): # Deal 13 to goal stack
		spawn_card(team_str, deck.draw_card(), goal_stack)
	for i in range(35): # Deal 35 to cycle stack
		spawn_card(team_str, deck.draw_card(), cycle_stack)


func verify_full_deck_for_team(team: String) -> bool:
	var found_cards := {}
	print("verify_full_deck_for_team: ", team)
	for card in get_tree().get_nodes_in_group("cards"):
		if card.team == team:
			var key = "%s_%s" % [card.suit, card.rank]
			found_cards[key] = true

	for suit in Deck.SUITS:
		for rank in Deck.RANKS:
			var key = "%s_%s" % [suit, rank]
			if not found_cards.has(key):
				print("Missing card for team %s: %s" % [team, key])
				return false

	return true
