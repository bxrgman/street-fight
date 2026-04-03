extends CharacterBody2D

# --- Constants ---
const SPEED = 120.0
const JUMP_VELOCITY = -320.0
const GRAVITY = 900.0
const GRAVITY_CAP = 600.0
const DASH_SPEED = 500.0
const DASH_DURATION = 0.25
const DASH_COOLDOWN = 0.6

# --- Combat Constants ---
const ATTACK_DURATION = 0.45
const SPECIAL_ATTACK_DURATION = 0.8
const SPECIAL_ATTACK_HEALTH_COST = 25.0
const COMBO_RESET_TIME = 0.6

# --- Karma Constants ---
const KARMA_MAX = 100.0
const KARMA_LIGHT_GAIN = 8.0
const KARMA_SPECIAL_GAIN = 25.0
const KARMA_DECAY_RATE = 12.0
const KARMA_OVERHEAT_DURATION = 2.0

# --- Stats ---
var max_health = 100.0
var health = 100.0
var karma = 0.0
var is_overheated = false
var overheat_timer = 0.0

# --- State ---
var is_dashing = false
var dash_timer = 0.0
var dash_cooldown_timer = 0.0
var facing = 1
var is_attacking = false
var attack_timer = 0.0
var current_attack = ""
var combo_step = 0
var combo_reset_timer = 0.0

# --- Nodes ---
@onready var sprite = $AnimatedSprite2D

func _physics_process(delta):
	_handle_gravity(delta)
	_handle_karma(delta)
	_handle_attack(delta)

	if not is_attacking and not is_overheated:
		_handle_dash(delta)

	if not is_dashing:
		_handle_movement()
		_handle_jump()

	_handle_facing()
	_handle_animation()
	move_and_slide()

func _handle_gravity(delta):
	if not is_on_floor():
		velocity.y = min(velocity.y + GRAVITY * delta, GRAVITY_CAP)
	else:
		velocity.y = 0

func _handle_movement():
	if (is_attacking or is_overheated) and is_on_floor():
		velocity.x = 0
		return
	var dir = Input.get_axis("ui_left", "ui_right")
	if dir != 0:
		velocity.x = dir * SPEED
	else:
		velocity.x = 0

func _handle_jump():
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_overheated:
		velocity.y = JUMP_VELOCITY

func _handle_dash(delta):
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0 and not is_dashing:
		is_dashing = true
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_COOLDOWN

	if is_dashing:
		velocity.x = facing * DASH_SPEED
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false

func _handle_karma(delta):
	if is_overheated:
		overheat_timer -= delta
		if overheat_timer <= 0:
			is_overheated = false
			karma = 0.0
		return

	if not is_attacking:
		karma = max(karma - KARMA_DECAY_RATE * delta, 0.0)

func _add_karma(amount: float):
	if is_overheated:
		return
	karma = min(karma + amount, KARMA_MAX)
	if karma >= KARMA_MAX:
		is_overheated = true
		overheat_timer = KARMA_OVERHEAT_DURATION
		is_attacking = false
		current_attack = ""

func _handle_attack(delta):
	if is_overheated:
		return

	# Tick combo reset
	if combo_reset_timer > 0 and not is_attacking:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0:
			combo_step = 0

	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0:
			is_attacking = false
			current_attack = ""
			combo_reset_timer = COMBO_RESET_TIME
		return

	if not is_on_floor():
		if Input.is_action_just_pressed("attack_light"):
			is_attacking = true
			current_attack = "air_attack"
			attack_timer = ATTACK_DURATION
			combo_step = 0
			_add_karma(KARMA_LIGHT_GAIN)
		return

	if Input.is_action_just_pressed("attack_heavy"):
		if health > SPECIAL_ATTACK_HEALTH_COST:
			health -= SPECIAL_ATTACK_HEALTH_COST
			is_attacking = true
			current_attack = "special_attack"
			attack_timer = SPECIAL_ATTACK_DURATION
			combo_step = 0
			combo_reset_timer = 0.0
			_add_karma(KARMA_SPECIAL_GAIN)
		return

	if Input.is_action_just_pressed("attack_light"):
		combo_step = (combo_step % 3) + 1
		current_attack = "attack_" + str(combo_step)
		is_attacking = true
		attack_timer = ATTACK_DURATION
		combo_reset_timer = 0.0
		_add_karma(KARMA_LIGHT_GAIN)

func _handle_facing():
	var dir = Input.get_axis("ui_left", "ui_right")
	if dir != 0 and not is_attacking:
		facing = int(sign(dir))
		sprite.flip_h = facing == -1

func _handle_animation():
	if is_overheated:
		sprite.play("hurt")
	elif is_attacking:
		sprite.play(current_attack)
	elif is_dashing:
		sprite.play("dash")
	elif not is_on_floor():
		if velocity.y < 0:
			sprite.play("jump")
		else:
			sprite.play("jump_fall")
	elif velocity.x != 0:
		sprite.play("walk")
	else:
		sprite.play("idle")
