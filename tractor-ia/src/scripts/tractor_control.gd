extends VehicleBody3D

var max_rpm = 400  # Aumentado un poco para mejor respuesta en torque
var max_torque = 1200  # MUCHO más torque, ideal para subir cuestas
var brake_force = 400  # Frenado más fuerte para controlar el peso

func _physics_process(_delta: float) -> void:
	# Dirección más suave para un tractor
	steering = lerp(steering, Input.get_axis("ui_right", "ui_left") * 0.4, 2.5 * _delta)
	var acceleration = Input.get_axis("ui_down", "ui_up")
	
	var is_braking = Input.is_action_pressed("ui_select")

	# Ruedas traseras: tracción y freno
	for wheel in [$VehicleWheelTL, $VehicleWheelTR, $VehicleWheelDL, $VehicleWheelDR]:
		var rpm = wheel.get_rpm()
		var torque_factor = clamp(1 - rpm / max_rpm, 0.2, 1.0)
		wheel.engine_force = acceleration * max_torque * torque_factor
		wheel.brake = brake_force if is_braking else 0.0

	# Ruedas delanteras: dirección, freno, y soporte
	for wheel in [$VehicleWheelDL, $VehicleWheelDR]:
		wheel.brake = brake_force if is_braking else 0.0
