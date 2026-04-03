extends CharacterBody2D

# --- Constants ---
const SPEED = 120.0
const JUMP_VELOCITY = -320.0
const GRAVITY = 900.0
const GRAVITY_CAP = 600.0
const DASH_SPEED = 500.0
const DASH_DURATION = 0.25
const DASH_COOLDOWN = 0.6

# --- State ---
var is_dashing = false
var dash_timer = 0.0
var dash_cooldown_timer = 0.0
var facing = 1  # 1 = right, -1 = left

# --- Nodes ---
@onready var sprite = $AnimatedSprite2D

func _physics_process(delta):
	_handle_gravity(delta)
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
	var dir = Input.get_axis("ui_left", "ui_right")
	if dir != 0:
		velocity.x = dir * SPEED
	else:
		velocity.x = 0

func _handle_jump():
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
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

func _handle_facing():
	var dir = Input.get_axis("ui_left", "ui_right")
	if dir != 0:
		facing = int(sign(dir))
		sprite.flip_h = facing == -1

func _handle_animation():
	if is_dashing:
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
