<p align="center"><img src="icon.png"/></p>

# My Notes:


### MVP Goals
Card can be:
	dropped on ground
		In which it's either laying flat (probably like a physics object), or doing the hoverbob floating?
	on a player (remembering the last place it was, to return if dropped)
	on a Goal Stack (13 pile, empty to win, must touch flag)
	on a Cycle Stack (3 at time, ground pound button to cycle)
	on a Solitaire Path (4x, Building down alternating, can be empty)
	on a Field Stack (out in middle)

Goal Stack, Cycle Stack, and Table Stack can probably be derivations (if that's possible) of some Deck type component
	Maybe even Solitaire Path can too, data wise, but display wise in the world the cards lay out along a path instead of stack.

each team of players has a 52 card playing deck and their own "Home Base" with the following:
starting setup that is shuffled and "dealt" randomly for each team:
	Goal stack of 13 (all face down, top can be flipped over with a ground pound only once round starts, if top is face up, it can be grabbed)
	Cycle stack of 35
	1 card face down (till game start) for each of the four Solitaire Paths

Grab will just be like, player is within the collision sphere, and is prompted with "[A] Grab Card" as long as they aren't holding anything presently, and A will grab the item, putting the card flat over the characters head, and maybe showing the 2d card on HUD. (Lock will show over the deck/stack it was taken from maybe, as you can't grab the card below if any, till that card is legally played or returned)
If player has a card, then going in collision spheres of places that it can be dropped will show like a hologram and prompt "[A] Place Card"

Cards legally played on Field Stacks are done, those are positive points at end of round.

Picking up a card from the Goal, Cycle, or any of 4 solitaire paths, locks the next available card on that stack till player returns card in some manner or it is legally played somewhere else
So we need to indicate visually where to place cards
	Goal (starts with 13, top card face up once game has begun, player of that decks team can grab top card)
	Cycle (the left over 35 cards after we dealt the starting setup)
	Solitaire
	Table

Assets to make:
	Hologram Shader on a card to show where it goes down maybe when your near and A (activate) shows up for player
	Hologram animation emanating up kind of deal rectangle glow
	Stone Card Altar shapes
		Goal
		Cycle
		Table
		Solitaire? (Rounded puzzly so you can make curved path out of them?)


Glider Purchase with coins? Other abilities?
	LOL, actually if your holding a card, you can glide down, however it costs stamina? Might be slower, might be a wind direction that changes at times or ceases that will help or not, maybe bribes to change it.

Game Reset Controller:
	Shuffle and Deal 13, 1, 1, 1, 1, 35

Play Slot awaiting Ace and built up to King
	Fireworks when you place a king, spawns things around Table Arena

Team Play-Mat
	A single 13-Deck slot
	4 array slots to play downward on
		Could be a thin stack, could be train tracks that move away from the base like tentacles and may be different based on the Table Arena layout.

Goal stacks could have effects, maybe rewards for each card placed there, some addition decision possibility.

Bribe the cannons to launch randomly at teams hills.

LOL, players have to run around and sort the cards afterwards. Just run around and tag them.

### Strech Goals
Stamina Pickups?


MiniMap / Global HUD: Play Slot
	Possibly so you can monitor Play Slots
	Each Team Jail-Cards
	Points in Play

Coins spent on map specials.
	Maybe you can rotate a platform that has 4 of the Play Slots on it so the one your watching is closer, cooldown before someone else can do it again.
	Move obstacles or monster spawners
	Curse certain suits or cards for whole map, run slower or stamina drain










# Starter Kit 3D Platformer

This package includes a basic template for a 3D platformer game in Godot 4.3 (stable). Includes features like;

- Character controller (with double jump)
- Collectable coins and falling platforms
- Camera controls (rotate, zoom)
- Gamepad support
- Sprites and 3D Models _(CC0 licensed)_
- Sound effects _(CC0 licensed)_

### Screenshot

<p align="center"><img src="screenshots/screenshot.png"/></p>

### License

MIT License

Copyright (c) 2024 Kenney

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Assets included in this package (2D sprites, 3D models and sound effects) are [CC0 licensed](https://creativecommons.org/publicdomain/zero/1.0/)
