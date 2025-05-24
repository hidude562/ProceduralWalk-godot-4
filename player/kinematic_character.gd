class_name KinematicCharacter
extends CharacterBody3D


@export var gravity: float = 98
@export var velocity_damp: float = 6
@export var velocity_change_rate: float = 5
@export var min_velocity: float = 0.5
@export var up: Vector3 = Vector3.UP

#var velocity: Vector3
var static_velocity: Vector3


func _physics_process(delta: float) -> void:
	for i in get_slide_collision_count():
		_handle_collision(get_slide_collision(i), delta)

	apply_gravity(delta)
	apply_dyn_vel_damp(delta)
	
	_manipulate_velocities(delta)
	
	if velocity.length() < min_velocity:
		velocity = Vector3.ZERO

	move_character(delta)
	move_character_static(delta)

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity -= up * gravity * delta
	else:
		velocity.y = max(velocity.y, 0)

func apply_dyn_vel_damp(delta: float) -> void:
	velocity -= Vector3(velocity.x, 0, velocity.z) * velocity_damp * delta

func move_character(delta: float) -> void:
	if velocity.length() > 0:
		if velocity.y > 0:
			set_velocity(velocity)
			set_up_direction(up)
			move_and_slide()
			velocity = velocity
		else:
			set_velocity(velocity)
			# TODOConverter3To4 looks that snap in Godot 4 is float, not vector like in Godot 3 - previous value `Vector3.DOWN * 2`
			set_up_direction(up)
			move_and_slide()
			velocity = velocity

func move_character_static(delta: float) -> void:
	if static_velocity.length() > 0:
		if static_velocity.y > 0:
			set_velocity(static_velocity)
			set_up_direction(up)
			move_and_slide()
		else:
			set_velocity(static_velocity)
			# TODOConverter3To4 looks that snap in Godot 4 is float, not vector like in Godot 3 - previous value `Vector3.DOWN * 2`
			set_up_direction(up)
			move_and_slide()

func apply_impulse(vel: Vector3) -> void:
	velocity += vel

func _manipulate_velocities(delta: float) -> void:
	pass

func _handle_collision(collision: KinematicCollision3D, delta: float) -> void:
	pass

# bounces character based on its velocity
func bounce(direction: Vector3, absorption: float = 0.17) -> void:
	velocity = direction * velocity.length() * absorption
