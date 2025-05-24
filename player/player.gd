extends CharacterBody3D


# moving
@export var speed: float = 10
@export var speed_change_rate: float = 15.0

var forward := false
var backward := false
var left := false
var right := false

# animation
# additional distance from the end of foot's bone to the ground
# used to make foot be on the ground instead of in the ground.
# sometimes the leg is not on the ground because of the magnet vector of SkeletonIK
@export var foot_bone_dist_to_ground: float = -0.05
# maximal distance in which the left leg can move away from proper leg position
@export var max_left_leg_dist: float = 0.3
# legs move animation time for both legs
@export var step_anim_time := 0.5
# additional distance for moving legs a little bit farther in direction of
# velocity. Allows walk animation to look properly. When human walks he places
# legs a little bit further in direction of walking.
@export var directional_delta := 1.5
# the height of lifting foot when animating walk
@export var step_anim_height := 1.0
# maximum distance between legs in 2D space.
# it should be calculated but to make it simpler just tweak the value and look
# if it looks good to you.
@export var max_legs_spread: float = 3.0

var last_l_leg_pos: Vector3
var last_r_leg_pos: Vector3
var l_leg_pos: Vector3
var r_leg_pos: Vector3

@onready var skeleton := $Armature/Skeleton3D

var is_animating_legs := false
var legs_anim_timer := 0.0

@onready var original_hips_pos := get_hips_pos()
@onready var current_hips_pos := get_hips_pos()

@export var crouch_delta: float = 1
var is_crouching := false

# raycast
@onready var space_state = get_world_3d().direct_space_state
@export var ray_length: float = 10

# camera
@export var mouse_sensivitiy = 0.3 # (float, 0.1, 1.0)
@export var min_pitch = -90 # (float, -90, 0)
@export var max_pitch = 90 # (float, 0, 90)

@export var velocity_damp: float = 6
@export var velocity_change_rate: float = 5
@export var min_velocity: float = 0.5
@export var up: Vector3 = Vector3.UP
var static_velocity: Vector3

@onready var camera_pivot := $CameraPivot
@onready var camera := $CameraPivot/CameraBoom/Camera3D

@export var first_camera: bool = true

# respawn
@export var spawn_point: NodePath

func _ready():
	set_proper_local_legs_pos()
	$Armature/Skeleton3D/LeftLeg.start()
	$Armature/Skeleton3D/RightLeg.start()

func set_proper_local_legs_pos() -> void:
	return
	# Gets incorrect position, configure manually
	"""
	var l_foot_id: int = skeleton.find_bone('Bip01_L_Foot')
	var l_foot_rest: Transform3D = skeleton.get_bone_global_pose(l_foot_id)
	$PropLeftLegPos.transform.origin = l_foot_rest.origin
	
	var r_foot_id: int = skeleton.find_bone('Bip01_R_Foot')
	var r_foot_rest: Transform3D = skeleton.get_bone_global_pose(r_foot_id)
	$PropRightLegPos.transform.origin = r_foot_rest.origin
	"""

func get_hips_pos() -> Vector3:
	var hips_id: int = skeleton.find_bone('Bip01_Pelvis')
	var hips_rest: Transform3D = skeleton.get_bone_pose(hips_id)
	
	return hips_rest.origin

func set_hips_pos(pos: Vector3) -> void:
	#TODO
	pass

func set_legs_pos_to_prop_legs_pointers_pos() -> void:
	l_leg_pos = $PropLeftLegPosToGround.global_transform.origin + Vector3.UP * foot_bone_dist_to_ground
	r_leg_pos = $PropRightLegPosToGround.global_transform.origin + Vector3.UP * foot_bone_dist_to_ground

func _process(delta):
	handle_respawn()
	set_global_legs_pos()
	set_prop_legs_ground_pointers()
	move_legs(delta)
	if is_flying():
		set_legs_pos_to_prop_legs_pointers_pos()
	
	kinamatic_process(delta)

func kinamatic_process(delta):
	for i in get_slide_collision_count():
		_handle_collision(get_slide_collision(i), delta)
	
	#apply_gravity(delta)
	apply_dyn_vel_damp(delta)
	
	_manipulate_velocities(delta)
	
	if velocity.length() < min_velocity:
		velocity = Vector3.ZERO

	move_character(delta)
	move_character_static(delta)

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

func _handle_collision(collision: KinematicCollision3D, delta: float) -> void:
	pass

func handle_respawn() -> void:
	if transform.origin.y < -20:
		transform.origin = get_node(spawn_point).transform.origin

func is_flying() -> bool:
	return abs(static_velocity.y) > 1.0

func set_global_legs_pos() -> void:
	$LeftLegControl.global_transform.origin = l_leg_pos
	$RightLegControl.global_transform.origin = r_leg_pos

func set_prop_legs_ground_pointers() -> void:
	var legs_pos := get_prop_legs_to_ground()
	$PropLeftLegPosToGround.global_transform.origin = legs_pos[0] 
	$PropRightLegPosToGround.global_transform.origin = legs_pos[1]
	pass

func get_prop_legs_to_ground() -> Array:
	# prop legs pos moved in direction of characters velocity
	# TODO: static velocity?
	var l_prop_leg_pos: Vector3 = $PropLeftLegPos.global_transform.origin + static_velocity.normalized() * directional_delta
	var r_prop_leg_pos: Vector3 = $PropRightLegPos.global_transform.origin + static_velocity.normalized() * directional_delta
	
	var l_leg_ray_params = PhysicsRayQueryParameters3D.new()
	l_leg_ray_params.from = l_prop_leg_pos + Vector3.UP * ray_length
	l_leg_ray_params.to = l_prop_leg_pos + Vector3.DOWN * ray_length
	l_leg_ray_params.exclude = [self]
	
	var r_leg_ray_params = PhysicsRayQueryParameters3D.new()
	r_leg_ray_params.from = r_prop_leg_pos + Vector3.UP * ray_length
	r_leg_ray_params.to =  r_prop_leg_pos + Vector3.DOWN * ray_length
	r_leg_ray_params.exclude = [self]
	
	var l_leg_ray = space_state.intersect_ray(
			l_leg_ray_params)
	var r_leg_ray = space_state.intersect_ray(
			r_leg_ray_params)
	
	
	return [
		l_leg_ray.position if not l_leg_ray.is_empty() else l_prop_leg_pos,
		r_leg_ray.position if not r_leg_ray.is_empty() else r_prop_leg_pos
	]

func get_left_leg_prop_dist() -> float:
	var left_leg_pos2d := Vector2(
			$PropLeftLegPosToGround.global_transform.origin.x,
			$PropLeftLegPosToGround.global_transform.origin.z)
	var curr_left_leg_pos2d := Vector2(l_leg_pos.x, l_leg_pos.z)
	return left_leg_pos2d.distance_to(curr_left_leg_pos2d)

func move_legs(delta: float) -> void:
	# doesn't do anything when player is in air
	if is_flying():
		return
	
	# if left legs is too far and leg animation isn't playing the set up the animation.
	if get_left_leg_prop_dist() > max_left_leg_dist and not is_animating_legs:
		last_l_leg_pos = l_leg_pos
		last_r_leg_pos = r_leg_pos
		legs_anim_timer = 0.0
		is_animating_legs = true

	if is_animating_legs:
		var desired_l_leg_pos: Vector3 = $PropLeftLegPosToGround.global_transform.origin + Vector3.DOWN * foot_bone_dist_to_ground
		var desired_r_leg_pos: Vector3 = $PropRightLegPosToGround.global_transform.origin + Vector3.DOWN * foot_bone_dist_to_ground
		# half of animation time goes to left leg
		if legs_anim_timer / step_anim_time <= 0.5:
			var l_leg_interpolation_v := legs_anim_timer / step_anim_time * 2.0
			l_leg_pos = last_l_leg_pos.lerp(desired_l_leg_pos, l_leg_interpolation_v)
			# moving left leg up
			l_leg_pos = l_leg_pos + Vector3.UP * step_anim_height * sin(PI * l_leg_interpolation_v)
		# half of animation time goes to right leg
		if legs_anim_timer / step_anim_time >= 0.5:
			var r_leg_interpolation_v := (legs_anim_timer / step_anim_time - 0.5) * 2.0
			r_leg_pos = last_r_leg_pos.lerp(desired_r_leg_pos, r_leg_interpolation_v)
			# moving right leg up
			r_leg_pos = r_leg_pos + Vector3.UP * step_anim_height * sin(PI * r_leg_interpolation_v)
		# moving hips up and down depending on ratio of distance between legs and maximum allowed distance
		set_hips_pos(current_hips_pos + Vector3.DOWN * get_legs_spread() / max_legs_spread * 0.3)
		# increase timer time
		legs_anim_timer += delta
		# if timer time is greater than whole animation time then stop animating
		if legs_anim_timer >= step_anim_time:
			is_animating_legs = false

func get_legs_spread() -> float:
	return Vector2(l_leg_pos.x, l_leg_pos.z).distance_to(Vector2(r_leg_pos.x, r_leg_pos.z))

func _manipulate_velocities(delta: float) -> void:
	var dir := Vector3.ZERO
	
	if forward:
		dir += transform.basis.x
	if backward:
		dir -= transform.basis.x
	if left:
		dir -= transform.basis.z
	if right:
		dir += transform.basis.z
	
	# grows static_velocity to desired speed every frame
	static_velocity = static_velocity.lerp(dir.normalized() * speed, speed_change_rate * delta)
	if static_velocity.length() < min_velocity:
		static_velocity = Vector3.ZERO

func _input(event):
	if event is InputEventMouseMotion:
		rotation_degrees.y -= event.relative.x * mouse_sensivitiy
		camera_pivot.rotation_degrees.x += event.relative.y * mouse_sensivitiy
		camera_pivot.rotation_degrees.x = clamp(camera_pivot.rotation_degrees.x, min_pitch, max_pitch)
	if event.is_action_pressed("forward"):
		forward = true
	elif event.is_action_released("forward"):
		forward = false
	if event.is_action_pressed("backward"):
		backward = true
	elif event.is_action_released("backward"):
		backward = false
	if event.is_action_pressed("left"):
		left = true
	elif event.is_action_released("left"):
		left = false
	if event.is_action_pressed("right"):
		right = true
	elif event.is_action_released("right"):
		right = false
	if event.is_action_released("change_camera"):
		first_camera = not first_camera
		$CameraPivot/CameraBoom/Camera3D.current = first_camera
		$Camera3D.current = not first_camera
	if event.is_action_released("crouch"):
		is_crouching = not is_crouching
		if is_crouching:
			current_hips_pos = original_hips_pos + Vector3.DOWN * crouch_delta
			set_hips_pos(current_hips_pos)
		else:
			current_hips_pos = original_hips_pos
			set_hips_pos(current_hips_pos)
