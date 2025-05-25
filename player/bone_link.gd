@tool
extends Node3D

@export var bone_name: String
@export var offset: Vector3

func _process(delta: float) -> void:
	var skeleton: Skeleton3D = get_node('../../Armature/Skeleton3D')
	var bone_idx = skeleton.find_bone(bone_name)
	var pose = skeleton.get_bone_global_pose(bone_idx)
	self.global_position = skeleton.to_global(pose.origin) + offset
