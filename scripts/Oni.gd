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
var max_health = 150.0
var health = 150.0
var is_phase2 = false
var has_shouted = false
var shout_push_triggered = false
var player_is_dead = false

# --- Attack damage ---
const ATTACK_1_DAMAGE = 20.0
const ATTACK_2_DAMAGE = 30.0
const ATTACK_3_DAMAGE = 25.0
const JUMP_ATTACK_DAMAGE = 40.0

# --- Jump Attack Knockback ---
const JUMP_ATTACK_PUSH_FORCE = 350.0
const JUMP_ATTACK_STUN_DURATION = 0.8

# --- Shout Constants ---
const SHOUT_PUSH_RANGE = 150.0
const SHOUT_PUSH_FORCE = 400.0

# --- Timers ---
const ATTACK_COOLDOWN = 2.0
const JUMP_ATTACK_COOLDOWN = 8.0
const HURT_DURATION = 0.4
const SHOUT_DURATION = 1.5
const DEATH_DURATION = 2.6

var attack_cooldown_timer = 0.0
var jump_attack_cooldown_timer = 0.0
var action_timer = 0.0

# --- State Machine ---
enum State { DORMANT, IDLE, CHASE, ATTACK, HURT, SHOUT, DEATH }
var state = State.DORMANT
var current_attack = ""
var facing = -1

# --- Nodes ---
@onready var sprite = $AnimatedSprite2D
@onready var hitbox = $Hitbox

# --- Player Reference ---
var player = null
var already_hit_player = false

func _ready():
	player = get_tree().get_first_node_in_group("player")
	add_to_group("enemies")
	sprite.speed_scale = DORMANT_FPS / 10.0
	hitbox.monitoring = false
	set_collision_layer_value(1, false)
	set_collision_mask_value(2, false)

func _physics_process(delta):
	_handle_gravity(delta)
	_handle_state(delta)
	_handle_facing()
	_check_shout_frame()
	_handle_hitbox()
	_handle_animation()
	move_and_slide()

func _handle_gravity(delta):
	if not is_on_floor():
		velocity.y = min(velocity.y + GRAVITY * delta, GRAVITY_CAP)
	else:
		velocity.y = 0

func _handle_facing():
	if player == null or state == State.DEATH or player_is_dead:
		return
	facing = sign(player.global_position.x - global_position.x)

func _check_shout_frame():
	if state == State.SHOUT and not shout_push_triggered:
		if sprite.frame >= 7:
			shout_push_triggered = true
			_trigger_shout_push()

func _handle_hitbox():
	if state == State.ATTACK and not player_is_dead:
		hitbox.monitoring = true
		hitbox.position.x = abs(hitbox.position.x) * facing
		for area in hitbox.get_overlapping_areas():
			var body = area.get_parent()
			if body.has_method("take_damage") and not already_hit_player:
				already_hit_player = true
				# Jump attack applies knockback and longer stun
				if current_attack == "jump_attack" or current_attack == "jump_attack_flaming":
					var dir = sign(body.global_position.x - global_position.x)
					body.apply_push(dir * JUMP_ATTACK_PUSH_FORCE, -150.0)
					body.take_damage_with_stun(get_attack_damage(), JUMP_ATTACK_STUN_DURATION)
				else:
					body.take_damage(get_attack_damage())
	else:
		hitbox.monitoring = false
		already_hit_player = false

func _handle_state(delta):
	# If player is dead, freeze all AI
	if player_is_dead:
		velocity = Vector2.ZERO
		return

	if action_timer > 0:
		action_timer -= delta
		if action_timer <= 0:
			_end_action()
		return

	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta

	if jump_attack_cooldown_timer > 0:
		jump_attack_cooldown_timer -= delta

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
			if not is_phase2 and dist > GIVEUP_RANGE:
				state = State.DORMANT
				return
			if dist <= ATTACK_RANGE and attack_cooldown_timer <= 0:
				_choose_attack()
				return
			var dir = sign(player.global_position.x - global_position.x)
			velocity.x = dir * SPEED

		State.ATTACK, State.HURT, State.SHOUT, State.DEATH:
			velocity.x = 0

func _choose_attack():
	# 1 in 5 chance for jump attack if cooldown is ready
	var roll = randi() % 5
	if roll == 0 and jump_attack_cooldown_timer <= 0:
		_start_attack("jump_attack")
		jump_attack_cooldown_timer = JUMP_ATTACK_COOLDOWN
	else:
		var attack_roll = randi() % 3
		if attack_roll == 0:
			_start_attack("attack_1")
		elif attack_roll == 1:
			_start_attack("attack_2")
		else:
			_start_attack("attack_3")

func _start_attack(attack_name):
	state = State.ATTACK
	# Use flaming variant if in phase 2
	if is_phase2 and attack_name == "jump_attack":
		current_attack = "jump_attack_flaming"
	else:
		current_attack = attack_name
	attack_cooldown_timer = ATTACK_COOLDOWN
	action_timer = 1.2 if current_attack.begins_with("jump_attack") else 0.8
	already_hit_player = false

func _trigger_phase2():
	has_shouted = true
	shout_push_triggered = false
	state = State.SHOUT
	action_timer = SHOUT_DURATION

func _trigger_shout_push():
	if player and _distance_to_player() <= SHOUT_PUSH_RANGE:
		var dir = sign(player.global_position.x - global_position.x)
		player.apply_push(dir * SHOUT_PUSH_FORCE, -200.0)

	for body in get_tree().get_nodes_in_group("enemies"):
		if body == self:
			continue
		if body is CharacterBody2D:
			var dist = abs(body.global_position.x - global_position.x)
			if dist <= SHOUT_PUSH_RANGE:
				var dir = sign(body.global_position.x - global_position.x)
				body.velocity.x = dir * SHOUT_PUSH_FORCE

func _end_action():
	if state == State.DEATH:
		queue_free()
		return
	if state == State.HURT and health <= 0:
		state = State.DEATH
		velocity.x = 0
		action_timer = DEATH_DURATION
		return
	if state == State.SHOUT and has_shouted and not is_phase2:
		is_phase2 = true
	state = State.CHASE
	current_attack = ""

func take_damage(amount: float):
	if state == State.DEATH or state == State.SHOUT:
		return
	health -= amount
	health = max(health, 0.0)

	if not has_shouted and health / max_health <= PHASE2_HEALTH_THRESHOLD:
		_trigger_phase2()
		return

	if health <= 0:
		state = State.DEATH
		velocity.x = 0
		action_timer = DEATH_DURATION
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
	elif current_attack == "jump_attack" or current_attack == "jump_attack_flaming":
		base = JUMP_ATTACK_DAMAGE
	return base * (2.0 if is_phase2 else 1.0)

func _distance_to_player() -> float:
	if player == null:
		return 9999.0
	return abs(global_position.x - player.global_position.x)

func on_player_died():
	player_is_dead = true
	state = State.DORMANT
	velocity = Vector2.ZERO
	action_timer = 0.0
	attack_cooldown_timer = 0.0

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
			sprite.play(current_attack)
			sprite.flip_h = facing == -1
		State.HURT:
			sprite.speed_scale = 1.0
			sprite.play("hurt" + suffix)
		State.SHOUT:
			sprite.speed_scale = 1.0
			sprite.play("shout")
		State.DEATH:
			sprite.speed_scale = 1.0
			sprite.play("death")
			sprite.flip_h = facing == -1
