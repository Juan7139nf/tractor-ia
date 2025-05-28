extends VehicleBody3D

var max_rpm = 400
var max_torque = 500
var extra_torque = 2800
var brake_force = 400

func _physics_process(_delta: float) -> void:
	# Dirección suave
	steering = lerp(steering, Input.get_axis("ui_right", "ui_left") * 0.4, 2.5 * _delta)
	var acceleration = Input.get_axis("ui_down", "ui_up")
	var is_braking = Input.is_action_pressed("ui_select")
	var is_four_wheel_drive = Input.is_key_pressed(KEY_SHIFT)

	# Ruedas traseras siempre tienen tracción
	for wheel in [$VehicleWheelTL, $VehicleWheelTR]:
		var rpm = wheel.get_rpm()
		var torque_factor = clamp(1 - rpm / max_rpm, 0.2, 1.0)
		wheel.engine_force = acceleration * max_torque * torque_factor
		wheel.brake = brake_force if is_braking else 0.0

	# Ruedas delanteras solo tienen tracción si se activa 4x4
	for wheel in [$VehicleWheelDL, $VehicleWheelDR]:
		var rpm = wheel.get_rpm()
		var torque_factor = clamp(1 - rpm / max_rpm, 0.2, 1.0)
		wheel.engine_force = acceleration * (extra_torque if is_four_wheel_drive else 0) * torque_factor
		wheel.brake = brake_force if is_braking else 0.0
