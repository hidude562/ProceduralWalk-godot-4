extends SpringBoneSimulator3D

@export var crouch = false

func _process(delta: float) -> void:
	print(crouch)
	if crouch:
		var rotation = get_node('../../../').rotation.y - PI / 2
		var amount = 15.0
		set_gravity_direction(1, Vector3(cos(rotation) * amount, 10, sin(rotation) * amount))
	else:
		set_gravity_direction(1, Vector3.UP)
