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
const COMBO_RESET_TIME = 0.6

# --- Karma Constants ---
const KARMA_MAX = 100.0
const KARMA_LIGHT_GAIN = 8.0
const KARMA_SPECIAL_GAIN = 60.0
const KARMA_DECAY_RATE = 12.0
const KARMA_DECAY_DASH_MULTIPLIER = 3.0
const KARMA_OVERHEAT_DURATION = 2.0

# --- Attack Damage ---
const LIGHT_ATTACK_DAMAGE = 10.0
const SPECIAL_ATTACK_DAMAGE = 30.0

# --- Push State ---
var is_pushed = false
var push_timer = 0.0
const PUSH_DURATION = 0.3

# --- Hurt State ---
var is_hurt = false
var hurt_timer = 0.0
const HURT_DURATION = 0.4
var is_invincible = false
var invincible_timer = 0.0
const INVINCIBLE_DURATION = 0.5

# --- Death State ---
var is_dead = false

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
var special_attack_blocked = false
var already_hit = []

# --- Nodes ---
@onready var sprite = $AnimatedSprite2D
@onready var hitbox = $Hitbox
@onready var hurtbox = $Hurtbox

func _ready():
	add_to_group("player")
	hitbox.monitoring = false

func _physics_process(delta):
	if is_dead:
		return

	_handle_gravity(delta)
	_handle_karma(delta)
	_handle_hurt(delta)
	_handle_invincible(delta)
	_handle_attack(delta)
	_handle_hitbox()

	if not is_attacking and not is_overheated and not is_hurt:
		_handle_dash(delta)

	if not is_dashing:
		_handle_movement(delta)
		_handle_jump()

	_handle_facing()
	_handle_animation()
	move_and_slide()

func _handle_gravity(delta):
	if not is_on_floor():
		velocity.y = min(velocity.y + GRAVITY * delta, GRAVITY_CAP)
	else:
		velocity.y = 0

func _handle_hurt(delta):
	if is_hurt:
		hurt_timer -= delta
		if hurt_timer <= 0:
			is_hurt = false

func _handle_invincible(delta):
	if is_invincible:
		invincible_timer -= delta
		if invincible_timer <= 0:
			is_invincible = false

func _handle_movement(delta):
	if is_pushed:
		push_timer -= delta
		if push_timer <= 0:
			is_pushed = false
		return

	if (is_attacking or is_overheated or is_hurt) and is_on_floor():
		velocity.x = 0
		return
	var dir = Input.get_axis("ui_left", "ui_right")
	if dir != 0:
		velocity.x = dir * SPEED
	else:
		velocity.x = 0

func apply_push(force_x: float, force_y: float):
	velocity.x = force_x
	velocity.y = force_y
	is_pushed = true
	push_timer = PUSH_DURATION

func take_damage(amount: float):
	if is_dashing or is_dead or is_invincible:
		return
	health -= amount
	health = max(health, 0.0)
	if health <= 0:
		health = 0.0
		_die()
		return
	is_hurt = true
	hurt_timer = HURT_DURATION
	is_invincible = true
	invincible_timer = INVINCIBLE_DURATION
	is_attacking = false
	current_attack = ""
	already_hit.clear()

func _die():
	is_dead = true
	velocity = Vector2.ZERO
	hitbox.monitoring = false
	sprite.play("death")
	# Wait for death animation to finish before notifying enemies
	sprite.animation_finished.connect(_on_death_animation_finished)

func _on_death_animation_finished():
	if sprite.animation == "death":
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.has_method("on_player_died"):
				enemy.on_player_died()

func _handle_jump():
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_overheated and not is_hurt:
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
		return

	if not is_attacking:
		if is_dashing:
			karma = max(karma - KARMA_DECAY_RATE * KARMA_DECAY_DASH_MULTIPLIER * delta, 0.0)
		else:
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
	if is_hurt:
		return

	if special_attack_blocked and not Input.is_action_pressed("attack_heavy"):
		special_attack_blocked = false

	if is_overheated:
		return

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
			already_hit.clear()
		return

	if not is_on_floor():
		if Input.is_action_just_pressed("attack_light"):
			is_attacking = true
			current_attack = "air_attack"
			attack_timer = ATTACK_DURATION
			combo_step = 0
			already_hit.clear()
			_add_karma(KARMA_LIGHT_GAIN)
		return

	if Input.is_action_just_pressed("attack_heavy"):
		if special_attack_blocked:
			return
		if health <= 33.0:
			return
		if karma >= KARMA_MAX * 0.9:
			health -= 33.0
			health = max(health, 0.0)
		else:
			_add_karma(KARMA_SPECIAL_GAIN)
		is_attacking = true
		current_attack = "special_attack"
		attack_timer = SPECIAL_ATTACK_DURATION
		combo_step = 0
		combo_reset_timer = 0.0
		already_hit.clear()
		return

	if Input.is_action_just_pressed("attack_light"):
		combo_step = (combo_step % 3) + 1
		current_attack = "attack_" + str(combo_step)
		is_attacking = true
		attack_timer = ATTACK_DURATION
		combo_reset_timer = 0.0
		already_hit.clear()
		_add_karma(KARMA_LIGHT_GAIN)

func _handle_hitbox():
	if is_attacking:
		hitbox.monitoring = true
		for area in hitbox.get_overlapping_areas():
			var parent = area.get_parent()
			if parent.has_method("take_damage") and not already_hit.has(parent):
				already_hit.append(parent)
				var damage = SPECIAL_ATTACK_DAMAGE if current_attack == "special_attack" else LIGHT_ATTACK_DAMAGE
				parent.take_damage(damage)
	else:
		hitbox.monitoring = false

func _handle_facing():
	var dir = Input.get_axis("ui_left", "ui_right")
	if dir != 0 and not is_attacking and not is_hurt:
		facing = int(sign(dir))
		sprite.flip_h = facing == -1
		hitbox.position.x = abs(hitbox.position.x) * facing

func _handle_animation():
	if is_hurt:
		sprite.play("hurt")
	elif is_overheated:
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
