extends CanvasLayer

@onready var health_bar = $HealthBar
@onready var karma_bar = $KarmaBar
@onready var heart = $Heart

var player: CharacterBody2D

func _ready():
	player = get_tree().get_first_node_in_group("player")
	print("karma_bar node: ", karma_bar)
	print("player found: ", player)

func _process(_delta):
	if player == null:
		return
	_update_health()
	_update_karma()
	_update_heart()

func _update_health():
	var ratio = player.health / player.max_health
	if ratio > 0.83:
		health_bar.texture = preload("res://assets/sprites/HUD/bar_full.png")
	elif ratio > 0.66:
		health_bar.texture = preload("res://assets/sprites/HUD/bar_5.png")
	elif ratio > 0.5:
		health_bar.texture = preload("res://assets/sprites/HUD/bar_4.png")
	elif ratio > 0.33:
		health_bar.texture = preload("res://assets/sprites/HUD/bar_3.png")
	elif ratio > 0.16:
		health_bar.texture = preload("res://assets/sprites/HUD/bar_2.png")
	else:
		health_bar.texture = preload("res://assets/sprites/HUD/bar_1.png")

func _update_karma():
	karma_bar.max_value = 100
	karma_bar.value = 100 - (player.karma / player.KARMA_MAX * 100)

func _update_heart():
	pass
