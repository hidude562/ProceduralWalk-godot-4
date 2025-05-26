extends RigidBody3D

var mouse_inside = false

const LABEL = preload('res://scenes/label.tscn')
var label_child = null

func _mouse_enter() -> void:
	mouse_inside = true
	toggle_label()

func _mouse_exit() -> void:
	mouse_inside = false
	toggle_label()

func can_grab() -> bool:
	var distance = self.global_position.distance_to(get_node('/root/World/CharacterBody3D/').global_position)
	return mouse_inside# and distance < 3

func toggle_label() -> void:
	print(mouse_inside)
	if not can_grab():
		if label_child != null:
			label_child.queue_free()
			label_child = null
	else:
		label_child = LABEL.instantiate()
		add_child(label_child)
		label_child.position = Vector3.ZERO

func _input(event: InputEvent) -> void:
	if event.is_action_pressed('take') and can_grab():
		var hand_control = get_node('/root/World/CharacterBody3D/HandControl')
		if hand_control.holding == self:
			hand_control.set_holding(null)
		else:
			hand_control.set_holding(self)
