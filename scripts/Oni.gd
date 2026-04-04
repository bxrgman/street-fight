extends CharacterBody2D

# --- Constants ---
const SPEED = 40.0
const GRAVITY = 900.0
const GRAVITY_CAP = 600.0
const ACTIVATION_RANGE = 150.0
const ATTACK_RANGE = 55.0
const GIVEUP_RANGE = 250.0
const PHASE2_HEALTH_THRESHOLD = 0.33

# --- Idle FPS ---
const DORMANT_FPS = 3
const ACTIVE_FPS = 10
const FLAMING_IDLE_FPS = 14

# --- Stats ---
var max_health = 300.0
var health = 300.0
var is_phase2 = false
var has_shouted = false

# --- Attack damage ---
const ATTACK_1_DAMAGE = 20.0
const ATTACK_2_DAMAGE = 30.0
const ATTACK_3_DAMAGE = 25.0

# --- Shout Constants ---
const SHOUT_PUSH_RANGE = 150.0
const SHOUT_PUSH_FORCE = 400.0

# --- Timers ---
const ATTACK_COOLDOWN = 2.0
const HURT_DURATION = 0.4
const SHOUT_DURATION = 1.5
const DEFEND_DURATION = 1.0

var attack_cooldown_timer = 0.0
var action_timer = 0.0

# --- State Machine ---
enum State { DORMANT, IDLE, CHASE, ATTACK, HURT, DEFEND, SHOUT, DEATH }
var state = State.DORMANT
var current_attack = ""
var facing = -1

# --- Nodes ---
@onready var sprite = $AnimatedSprite2D

# --- Player Reference ---
var player = null

func _ready():
	player = get_tree().get_first_node_in_group("player")
	add_to_group("enemies")
	sprite.speed_scale = DORMANT_FPS / 10.0

func _physics_process(delta):
	_handle_gravity(delta)
	_handle_state(delta)
	_handle_facing()
	_handle_animation()
	move_and_slide()

func _handle_gravity(delta):
	if not is_on_floor():
		velocity.y = min(velocity.y + GRAVITY * delta, GRAVITY_CAP)
	else:
		velocity.y = 0

func _handle_facing():
	if player == null:
		return
	# Always face the player
	facing = sign(player.global_position.x - global_position.x)

func _handle_state(delta):
	if action_timer > 0:
		action_timer -= delta
		if action_timer <= 0:
			_end_action()
		return

	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta

	match state:
		State.DORMANT:
			velocity.x = 0
			if player and _distance_to_player() <= ACTIVATION_RANGE:
				state = State.IDLE

		State.IDLE:
			velocity.x = 0
			if player == null:
				state = State.DORMANT
				return
			var dist = _distance_to_player()
			if dist > GIVEUP_RANGE:
				state = State.DORMANT
				return
			if dist <= ACTIVATION_RANGE:
				state = State.CHASE

		State.CHASE:
			if player == null:
				state = State.DORMANT
				return
			var dist = _distance_to_player()
			if dist > GIVEUP_RANGE:
				state = State.DORMANT
				return
			if dist <= ATTACK_RANGE and attack_cooldown_timer <= 0:
				_choose_attack()
				return
			var dir = sign(player.global_position.x - global_position.x)
			velocity.x = dir * SPEED

		State.ATTACK, State.HURT, State.DEFEND, State.SHOUT:
			velocity.x = 0

		State.DEATH:
			velocity.x = 0

func _choose_attack():
	# Only attacks — no random defend or shout during combat
	var attack_roll = randi() % 3
	if attack_roll == 0:
		_start_attack("attack_1")
	elif attack_roll == 1:
		_start_attack("attack_2")
	else:
		_start_attack("attack_3")

func _start_attack(attack_name):
	state = State.ATTACK
	current_attack = attack_name
	attack_cooldown_timer = ATTACK_COOLDOWN
	action_timer = 0.8

func _trigger_phase2():
	# Phase transition — shout then go flaming
	has_shouted = true
	state = State.SHOUT
	action_timer = SHOUT_DURATION
	_trigger_shout_push()

func _trigger_shout_push():
	if player and _distance_to_player() <= SHOUT_PUSH_RANGE:
		var dir = sign(player.global_position.x - global_position.x)
		player.velocity.x += dir * SHOUT_PUSH_FORCE
		player.velocity.y = -150.0

	for body in get_tree().get_nodes_in_group("enemies"):
		if body == self:
			continue
		if body is CharacterBody2D:
			var dist = abs(body.global_position.x - global_position.x)
			if dist <= SHOUT_PUSH_RANGE:
				var dir = sign(body.global_position.x - global_position.x)
				body.velocity.x += dir * SHOUT_PUSH_FORCE

func _end_action():
	if state == State.DEATH:
		queue_free()
		return
	if state == State.HURT and health <= 0:
		state = State.DEATH
		action_timer = 2.0
		return
	# Phase 2 activates after shout finishes
	if state == State.SHOUT and has_shouted and not is_phase2:
		is_phase2 = true
	state = State.CHASE
	current_attack = ""

func take_damage(amount: float):
	if state == State.DEATH:
		return
	if state == State.DEFEND:
		amount *= 0.2
	health -= amount
	health = max(health, 0.0)

	# Trigger phase 2 transition via shout
	if not has_shouted and health / max_health <= PHASE2_HEALTH_THRESHOLD:
		_trigger_phase2()
		return

	if health <= 0:
		state = State.DEATH
		action_timer = 2.0
		velocity.x = 0
		return

	state = State.HURT
	action_timer = HURT_DURATION

func get_attack_damage() -> float:
	var base = 0.0
	if current_attack == "attack_1":
		base = ATTACK_1_DAMAGE
	elif current_attack == "attack_2":
		base = ATTACK_2_DAMAGE
	elif current_attack == "attack_3":
		base = ATTACK_3_DAMAGE
	return base * (2.0 if is_phase2 else 1.0)

func _distance_to_player() -> float:
	if player == null:
		return 9999.0
	return abs(global_position.x - player.global_position.x)

func _handle_animation():
	var suffix = "_flaming" if is_phase2 else ""
	match state:
		State.DORMANT:
			sprite.speed_scale = DORMANT_FPS / 10.0
			sprite.play("idle")
			sprite.flip_h = facing == -1
		State.IDLE:
			if is_phase2:
				sprite.speed_scale = FLAMING_IDLE_FPS / 10.0
				sprite.play("idle_flaming")
			else:
				sprite.speed_scale = ACTIVE_FPS / 10.0
				sprite.play("idle")
			sprite.flip_h = facing == -1
		State.CHASE:
			sprite.speed_scale = 1.0
			sprite.play("run" + suffix)
			sprite.flip_h = facing == -1
		State.ATTACK:
			sprite.speed_scale = 1.0
			sprite.play(current_attack + suffix)
			sprite.flip_h = facing == -1
		State.HURT:
			sprite.speed_scale = 1.0
			sprite.play("hurt" + suffix)
		State.DEFEND:
			sprite.speed_scale = 1.0
			sprite.play("defend")
		State.SHOUT:
			sprite.speed_scale = 1.0
			sprite.play("shout")
		State.DEATH:
			sprite.speed_scale = 1.0
			sprite.play("death")
