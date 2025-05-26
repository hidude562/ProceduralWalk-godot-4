extends Node3D

# It'll try to wrap arms around to actually hold something
# Assume there is a CollisionShape3D child.
@export var holding: PhysicsBody3D
# The target position to move holding to
@export var target: Vector3
@export var hand_offset_distance: float = 0.01  # How far hands should be from surface
@export var grip_strength: float = 1.0  # How tightly to grip (0-1)

func set_holding(holding: PhysicsBody3D):
	if self.holding != null:
		if self.holding is RigidBody3D:
			self.holding.freeze = false
	
	self.holding = holding
	
	if self.holding is RigidBody3D:
		self.holding.freeze = true

func get_actual_holding_center(hands_at: Vector3, target_weighting=0.5) -> Vector3:
	var global_target = self.to_global(target)
	var hands_at_weighting = 1-target_weighting
	
	return hands_at_weighting * hands_at + global_target * target_weighting

func update_holding_position() -> void:
	var skeleton: Skeleton3D = get_node('../Armature/Skeleton3D')
	var hand_r = skeleton.get_bone_global_pose(skeleton.find_bone('hand_R'))
	var hand_l = skeleton.get_bone_global_pose(skeleton.find_bone('hand_L'))
	
	var hands_at = skeleton.to_global((hand_r.origin + hand_l.origin) / 2)
	
	if holding:
		for child in holding.get_children():
			if child is not CollisionShape3D:
				child.global_position = get_actual_holding_center(hands_at, 0.0)#($RightHandControl.global_position + $LeftHandControl.global_position) / 2#get_actual_holding_center()
			else:
				child.global_position = get_actual_holding_center(hands_at, 1.0)
			child.global_rotation = self.global_rotation

func get_collision_shape() -> CollisionShape3D:
	if not holding:
		return null
	
	# Find the CollisionShape3D in the held object
	for child in holding.get_children():
		if child is CollisionShape3D:
			return child
	return null

func get_optimal_grip_points(collision_shape: CollisionShape3D) -> Dictionary:
	var shape = collision_shape.shape
	var shape_transform = collision_shape.global_transform
	var grip_points = {"right": Vector3.ZERO, "left": Vector3.ZERO}
	
	if shape is BoxShape3D:
		# For boxes, grip on opposite sides
		var box_shape = shape as BoxShape3D
		var size = box_shape.size
		
		# Choose the best axis to grip (usually the smallest dimension)
		var min_axis = 0
		if size.y < size.x and size.y < size.z:
			min_axis = 1
		elif size.z < size.x and size.z < size.y:
			min_axis = 2
		
		match min_axis:
			0: # Grip on X axis (left/right sides)
				grip_points.right = shape_transform * Vector3(size.x/2 + hand_offset_distance, 0, 0)
				grip_points.left = shape_transform * Vector3(-size.x/2 - hand_offset_distance, 0, 0)
			1: # Grip on Y axis (top/bottom)
				grip_points.right = shape_transform * Vector3(size.x/4, size.y/2 + hand_offset_distance, 0)
				grip_points.left = shape_transform * Vector3(-size.x/4, size.y/2 + hand_offset_distance, 0)
			2: # Grip on Z axis (front/back)
				grip_points.right = shape_transform * Vector3(size.x/4, 0, size.z/2 + hand_offset_distance)
				grip_points.left = shape_transform * Vector3(-size.x/4, 0, -size.z/2 - hand_offset_distance)
	
	elif shape is SphereShape3D:
		# For spheres, grip on opposite sides
		var sphere_shape = shape as SphereShape3D
		var radius = sphere_shape.radius
		var grip_distance = radius + hand_offset_distance
		
		grip_points.right = shape_transform * Vector3(grip_distance, 0, 0)
		grip_points.left = shape_transform * Vector3(-grip_distance, 0, 0)
	
	elif shape is CapsuleShape3D:
		# For capsules, grip around the middle
		var capsule_shape = shape as CapsuleShape3D
		var radius = capsule_shape.radius
		var grip_distance = radius + hand_offset_distance
		
		grip_points.right = shape_transform * Vector3(grip_distance, 0, 0)
		grip_points.left = shape_transform * Vector3(-grip_distance, 0, 0)
	
	elif shape is CylinderShape3D:
		# For cylinders, grip on the curved surface
		var cylinder_shape = shape as CylinderShape3D
		var radius = cylinder_shape.top_radius
		var grip_distance = radius + hand_offset_distance
		
		grip_points.right = shape_transform * Vector3(grip_distance, 0, 0)
		grip_points.left = shape_transform * Vector3(-grip_distance, 0, 0)
	
	else:
		# Fallback for other shapes - use AABB
		var aabb = shape.get_debug_mesh().get_aabb()
		var size = aabb.size
		var center = shape_transform * aabb.get_center()
		
		grip_points.right = center + Vector3(size.x/2 + hand_offset_distance, 0, 0)
		grip_points.left = center + Vector3(-size.x/2 - hand_offset_distance, 0, 0)
	
	var swap = grip_points.left
	grip_points.left = grip_points.right
	grip_points.right = swap
	
	return grip_points

func calculate_hand_orientation(hand_pos: Vector3, target_pos: Vector3) -> Basis:
	# Calculate orientation so palm faces the object
	var forward = (target_pos - hand_pos).normalized()
	var up = Vector3.UP
	
	# Adjust up vector if it's parallel to forward
	if abs(forward.dot(up)) > 0.9:
		up = Vector3.RIGHT
	
	var right = forward.cross(up).normalized()
	up = right.cross(forward).normalized()
	
	return Basis(-forward, -up, -right)

func update_hand_targets() -> void:
	if not holding:
		return
	
	var collision_shape = get_collision_shape()
	if not collision_shape:
		return
	
	var grip_points = get_optimal_grip_points(collision_shape)
	var object_center = holding.global_position
	
	# Update right hand
	if has_node("RightHandControl"):
		var right_hand = $RightHandControl
		var right_pos = grip_points.right
		var right_orientation = calculate_hand_orientation(right_pos, object_center)
		
		# Convert to local space
		right_hand.position = to_local(right_pos)
		#right_hand.basis = global_transform.basis.inverse() * right_orientation
		#right_hand.rotation.y -= PI 
	
	# Update left hand
	if has_node("LeftHandControl"):
		var left_hand = $LeftHandControl
		var left_pos = grip_points.left
		var left_orientation = calculate_hand_orientation(left_pos, object_center)
		
		# Convert to local space
		left_hand.position = to_local(left_pos)
		#left_hand.basis = global_transform.basis.inverse() * left_orientation
		#left_hand.rotation.y = PI 
		#left_hand.rotation.x += PI / 2

func ignore_targets() -> void:
	var skeleton = get_node('../Armature/Skeleton')
	if skeleton != null:
		skeleton.get_node('LHand').target_node = null
		skeleton.get_node('RHand').target_node = null
	

func _process(delta: float) -> void:
	if holding != null:
		update_hand_targets()
	else:
		#ignore_targets()
		pass


func _on_spring_back_modification_processed() -> void:
	update_holding_position()
