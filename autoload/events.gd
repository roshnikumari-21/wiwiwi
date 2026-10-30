extends Node
## Global signal bus: anything that other scenes or services care about is announced here.
## Senders don't know who listens (HUD, level, achievements, sounds…), so pieces stay independent.

signal coin_collected
signal yarn_collected
signal hearts_changed(hearts: int)
signal player_hurt                     ## a hazard or enemy touched the cat
signal player_fell_in_water
signal enemy_stomped
signal energy_changed(energy: float)   ## 0..1
signal milk_drunk
signal checkpoint_reached(respawn_position: Vector2)
signal level_completed(stars: int, coins: int, coin_total: int, has_yarn: bool)
signal level_failed
