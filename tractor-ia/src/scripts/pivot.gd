extends Node3D

var direction: Vector3 = Vector3.FORWARD
@export var smooth_speed: float = 2.5

func _physics_process(delta: float) -> void:
	var parent = get_parent()
	if not parent or not parent is PhysicsBody3D:
		return  # Asegura que el padre tiene velocidad lineal

	var current_velocity = parent.linear_velocity
	current_velocity.y = 0  # Ignorar la componente vertical

	if current_velocity.length_squared() > 1.0:
		var target_direction = -current_velocity.normalized()  # Mirar hacia atrás
		direction = direction.slerp(target_direction, clamp(smooth_speed * delta, 0.0, 1.0))

	# Aplicar rotación
	look_at(global_transform.origin + direction, Vector3.UP)
