# Tractor.gd - Versión con surcador siempre activo y bajado
extends VehicleBody3D

# Configuración del tractor
var max_rpm = 400
var max_torque = 500
var extra_torque = 1200
var brake_force = 200
var surcador_activo := false  # Siempre activo y bajado




# WebSocket
var tcp_server := TCPServer.new()
var connected_client: WebSocketPeer = null
var port := 8765

# Variables RL
var last_progress := 0.0
var step_count := 0
var stuck_timer := 0.0
var max_steps := 2000

var actions := {
	"acceleration": 0.0, "steering": 0.0, "brake": false,
	"four_wheel_drive": false, "reset_episode": false
}  # Eliminado "activate_plow"

func _ready():
	tcp_server.listen(port, "127.0.0.1")
	print("🚀 Servidor WebSocket en ws://localhost:", port)
	configurar_tractor()
	reset_episode()
	# Bajamos el surcador inmediatamente al inicio

func _process(_delta):
	step_count += 1
	handle_websocket()
func handle_websocket():
	# Nueva conexión
	if tcp_server.is_connection_available():
		var ws_peer = WebSocketPeer.new()
		var conn = tcp_server.take_connection()
		
		# Configuración compatible con Godot 4
		ws_peer.set_no_delay(true)  # Mejor para mensajes pequeños
		
		var err = ws_peer.accept_stream(conn)
		if err == OK:
			connected_client = ws_peer
			print("🤝 Cliente conectado | Protocolo: ", ws_peer.get_selected_protocol())
			# Enviar confirmación (modo texto implícito)
			connected_client.send_text(JSON.stringify({"handshake": "ok"}))
		else:
			push_error("❌ Error aceptando conexión: ", err)
	
	# Cliente activo
	if connected_client:
		connected_client.poll()
		var state = connected_client.get_ready_state()
		
		if state == WebSocketPeer.STATE_OPEN:
			# Recepción (automáticamente detecta texto/binario)
			while connected_client.get_available_packet_count() > 0:
				var pkt = connected_client.get_packet()
				if pkt.size() > 0:
					# Godot 4 ya maneja automáticamente el modo texto/binario
					var data = JSON.parse_string(pkt.get_string_from_utf8())
					if data:
						actions = data
						if actions.get("reset_episode", false): 
							reset_episode()
			
			# Envío (sin especificar modo)
			send_state()
			
		elif state == WebSocketPeer.STATE_CLOSED:
			var code = connected_client.get_close_code()
			var reason = connected_client.get_close_reason()
			print("🚪 Conexión cerrada: ", code, " - ", reason)
			connected_client = null

func send_state():
	var progress = get_progress()
	var reward = calculate_reward(progress)
	var done = step_count > max_steps or progress >= 99.9
	
	var state = {
		"observation": get_observation(),
		"reward": reward,
		"done": done,
		"info": {"progress": progress, "steps": step_count}
	}
	
	connected_client.send_text(JSON.stringify(state))

func get_observation() -> Array:
	var obs = []
	
	# Posición y rotación
	var pos = global_position / 20.0
	var rot = transform.basis.get_euler().y
	obs.append_array([pos.x, pos.z, sin(rot), cos(rot)])
	
	# Velocidad
	var vel = linear_velocity
	obs.append_array([vel.x / 10.0, vel.z / 10.0])
	
	# Progreso
	obs.append(get_progress() / 100.0)
	
	return obs

func get_progress() -> float:
	var terreno = get_node_or_null("/root/principal/Node3D2/StaticBody3D")
	if terreno and terreno.has_method("obtener_progreso_arado"):
		return terreno.obtener_progreso_arado()
	return min(step_count / 100.0, 100.0)  # Simulado

func calculate_reward(current_progress: float) -> float:
	var reward = 0.0
	
	# Progreso en arado
	reward += (current_progress - last_progress) * 10.0
	
	# Velocidad
	var speed = linear_velocity.length()
	if speed < 0.1:
		stuck_timer += 0.016
		reward -= stuck_timer * 0.1
	else:
		stuck_timer = 0.0
	
	# Recompensa por estar en tierra sin arar (surcador siempre activo y bajado)
	if get_terrain_type(global_position) == 0:
		reward += 0.1
	
	reward -= 0.01  # Penalización temporal
	last_progress = current_progress
	return reward

func get_terrain_type(pos: Vector3) -> int:
	var terreno = get_node_or_null("/root/principal/Node3D2/StaticBody3D")
	if terreno and terreno.has_method("obtener_tipo_terreno"):
		return terreno.obtener_tipo_terreno(pos)
	
	# Simulación básica
	var dist = global_position.distance_to(Vector3.ZERO)
	return 2 if dist > 15.0 else (1 if randf() > 0.7 else 0)

func reset_episode():
	# Reset tractor
	global_position = Vector3(1, 1, 0)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	transform.basis = Basis.IDENTITY
	
	# Reset variables
	last_progress = 0.0
	step_count = 0
	stuck_timer = 0.0
	surcador_activo = true  # Siempre activo
	
	# Bajamos el surcador al resetear
	if $AnimationPlayer:
		$AnimationPlayer.play("activar_surcador")
	
	# Reset terreno
	var terreno = get_node_or_null("/root/principal/Node3D2/StaticBody3D")
	if terreno and terreno.has_method("regenerar_campo"):
		terreno.regenerar_campo()

func _physics_process(_delta):
	# Combinar acciones del WebSocket con input manual
	var manual_steering = Input.get_axis("ui_right", "ui_left")
	var manual_acceleration = Input.get_axis("ui_down", "ui_up")
	var manual_brake = Input.is_action_pressed("ui_accept")
	
	# La entrada manual tiene prioridad si existe, sino usa WebSocket
	var final_steering = manual_steering if abs(manual_steering) > 0.1 else actions["steering"]
	var final_acceleration = manual_acceleration if abs(manual_acceleration) > 0.1 else actions["acceleration"]
	var final_brake = manual_brake or actions["brake"]
	
	# Aplicar steering
	steering = lerp(steering, final_steering * 0.4, 2.5 * _delta)
	
	# Fuerzas en ruedas (surcador siempre activo y bajado)
	apply_forces_combined(final_acceleration, final_brake)
	
	# Actualizar Global si existe
	if has_node("/root/Global"):
		var global_node = get_node("/root/Global")
		global_node.tractor_position = global_position
		if has_node("StaticBody3D/RayCast3D"):
			var ray = $StaticBody3D/RayCast3D
			global_node.surcador_position = ray.global_position
			global_node.surcador_collision = ray.is_colliding()
	
	
	if Input.is_key_pressed(KEY_CTRL):
		if $AnimationPlayer.is_playing():
			return
		surcador_activo = not surcador_activo  # Alterna el estado
		if surcador_activo:
			if $AnimationPlayer.has_animation("desactivar_surcador"):
				$AnimationPlayer.play("desactivar_surcador")
			else:
				print("Animación 'desactivar_surcador' no encontrada")
		else:
			if $AnimationPlayer.has_animation("activar_surcador"):
				$AnimationPlayer.play("activar_surcador")
			else:
				print("Animación 'activar_surcador' no encontrada")

func apply_forces_combined(accel: float, brake: bool):
	var four_wd = actions.get("four_wheel_drive", false) 
	
	# Ruedas traseras
	for wheel in [$VehicleWheelTL, $VehicleWheelTR]:
		if wheel:
			var torque_factor = clamp(1 - wheel.get_rpm() / max_rpm, 0.2, 1.0)
			wheel.engine_force = accel * max_torque * torque_factor
			wheel.brake = brake_force if brake else 0.0
	
	# Ruedas delanteras
	for wheel in [$VehicleWheelDL, $VehicleWheelDR]:
		if wheel:
			var torque_factor = clamp(1 - wheel.get_rpm() / max_rpm, 0.2, 1.0)
			wheel.engine_force = accel * (extra_torque if four_wd else 0) * torque_factor
			wheel.brake = brake_force if brake else 0.0

func apply_forces():
	var accel = actions["acceleration"]
	var brake = actions["brake"]
	var four_wd = actions.get("four_wheel_drive", false) 


	
	# Ruedas traseras
	for wheel in [$VehicleWheelTL, $VehicleWheelTR]:
		if wheel:
			var torque_factor = clamp(1 - wheel.get_rpm() / max_rpm, 0.2, 1.0)
			wheel.engine_force = accel * max_torque * torque_factor
			wheel.brake = brake_force if brake else 0.0
	
	# Ruedas delanteras
	for wheel in [$VehicleWheelDL, $VehicleWheelDR]:
		if wheel:
			var torque_factor = clamp(1 - wheel.get_rpm() / max_rpm, 0.2, 1.0)
			wheel.engine_force = accel * (extra_torque if four_wd else 0) * torque_factor
			wheel.brake = brake_force if brake else 0.0

func configurar_tractor():
	collision_layer = 2
	collision_mask = 1
	
	for wheel in [$VehicleWheelTL, $VehicleWheelTR, $VehicleWheelDL, $VehicleWheelDR]:
		if wheel:
			wheel.use_as_traction = true
			wheel.use_as_steering = (wheel.name in ["VehicleWheelDL", "VehicleWheelDR"])

func _exit_tree():
	if tcp_server: tcp_server.stop()
	print("🛑 WebSocket cerrado")
