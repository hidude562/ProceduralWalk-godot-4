extends Node3D

@export var crouch = false
var crouch_intermediate_progress = 0.0
var initial_skeleton_position: Vector3
var offset: Vector3

func _ready() -> void:
	initial_skeleton_position = get_node('../Armature/Skeleton3D').position

func _process(delta: float) -> void:
	if crouch:
		crouch_intermediate_progress -= (crouch_intermediate_progress) / 5
	else:
		crouch_intermediate_progress += (1 - crouch_intermediate_progress) / 5
	
	rotation.x = deg_to_rad(-crouch_intermediate_progress*70 - 5)
	var skeleton = get_node('../Armature/Skeleton3D')
	skeleton.position.z = -crouch_intermediate_progress*2 + 2
	#offset += get_random_smooth_vector3(42, 0.02) * 0.02
	#offset /= 1.01
	var dydx = get_random_smooth_vector3(42, 0.02) * 0.05
	skeleton.position += (dydx)
	skeleton.position += (initial_skeleton_position - skeleton.position) / 20
	
	
func get_random_smooth_vector3(seed: int, speed: float) -> Vector3:
	var noise_vec3d_uncasted = []
	for j in range(3):
		var noise = FastNoiseLite.new()
		noise.fractal_octaves = 2
		noise.seed = seed+j
		var noise_val = noise.get_noise_1d(Time.get_ticks_msec() * speed)
		noise_vec3d_uncasted.append(noise_val)
	var noise_vec3d = Vector3(noise_vec3d_uncasted[0], noise_vec3d_uncasted[1], noise_vec3d_uncasted[2])
	return noise_vec3d
