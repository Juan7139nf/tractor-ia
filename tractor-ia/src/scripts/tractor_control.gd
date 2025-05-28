extends VehicleBody3D

var max_rpm = 400
var max_torque = 500
var extra_torque = 2800
var brake_force = 400

var websocket := WebSocketPeer.new()
var connected := false

func _ready():
	websocket.connect_to_url("ws://localhost:8765")
	set_process(true)

var server_data := {
	"acceleration": 0.0,
	"steering": 0.0,
	"brake": false,
	"four_wheel_drive": false
}

func _process(_delta):
	websocket.poll()

	match websocket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not connected:
				print("✅ Conectado")
				connected = true
		WebSocketPeer.STATE_CLOSING, WebSocketPeer.STATE_CLOSED:
			if connected:
				print("❌ Desconectado")
				connected = false

	while websocket.get_available_packet_count() > 0:
		var packet = websocket.get_packet().get_string_from_utf8()
		var json = JSON.parse_string(packet)
		if json:
			server_data = json  # Guardamos los valores del servidor

func _physics_process(_delta):
	steering = lerp(steering, server_data["steering"] * 0.4, 2.5 * _delta)
	var acceleration = server_data["acceleration"]
	var is_braking = server_data["brake"]
	var is_four_wheel_drive = server_data["four_wheel_drive"]

	# Ruedas traseras
	for wheel in [$VehicleWheelTL, $VehicleWheelTR]:
		var rpm = wheel.get_rpm()
		var torque_factor = clamp(1 - rpm / max_rpm, 0.2, 1.0)
		wheel.engine_force = acceleration * max_torque * torque_factor
		wheel.brake = brake_force if is_braking else 0.0

	# Ruedas delanteras
	for wheel in [$VehicleWheelDL, $VehicleWheelDR]:
		var rpm = wheel.get_rpm()
		var torque_factor = clamp(1 - rpm / max_rpm, 0.2, 1.0)
		wheel.engine_force = acceleration * (extra_torque if is_four_wheel_drive else 0) * torque_factor
		wheel.brake = brake_force if is_braking else 0.0
