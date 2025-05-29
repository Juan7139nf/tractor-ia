extends StaticBody3D

@export var filas: int = 50
@export var columnas: int = 50

var spacing := 2

var matriz = []
var celdas = []

func _ready() -> void:
	var mesh_node = $base  # Asegúrate de que el nodo se llama "base"
	# Obtener el material actual o crear uno nuevo
	var material_base = mesh_node.get_surface_override_material(0)
	if material_base == null:
		material_base = StandardMaterial3D.new()
	# Cambiar el color (por ejemplo, a rojo)
	material_base.albedo_color = Color(1, 0, 0)  # RGB: rojo
	# Aplicar el material al mesh
	mesh_node.set_surface_override_material(0, material_base)
	var cube_mesh = PlaneMesh.new()

	# mapear la matriz
	for i in range(filas):
		var fila := []
		for j in range(columnas):
			if i < 3 or i >= filas - 3 or j < 3 or j >= columnas - 3:
				fila.append(0)  # Bordes de 3 celdas
			else:
				fila.append(1)  # Interior
		matriz.append(fila)
	
	# añadir planos
	for i in range(filas):
		var fila_celdas := []
		for j in range(columnas):
			var valor = matriz[i][j]
			var mesh_instance = MeshInstance3D.new()
			mesh_instance.mesh = cube_mesh
			
			var x = (j - columnas / 2) * spacing
			var z = (i - filas / 2) * spacing
			
			mesh_instance.position = Vector3(x + 1, 0, z + 1)  # Espaciado
			var material = StandardMaterial3D.new()
			match valor:
				0:
					material.albedo_color = Color(0.5, 0.5, 0.5)  # Gris
				1:
					material.albedo_color = Color(0, 1, 0)  # Verde
				2:
					material.albedo_color = Color(0.4, 0.26, 0.13)  # Café
			mesh_instance.set_surface_override_material(0, material)
			add_child(mesh_instance)
			fila_celdas.append(mesh_instance)
		celdas.append(fila_celdas)

func _process(delta: float) -> void:
	if not Global.surcador_collision:
		return  # No pintar si no hay colisión

	var pos = Global.surcador_position  # Usamos la posición del surcador, no del tractor

	# Convertir posición mundial a índices de matriz
	var j = int((pos.x / spacing) + columnas / 2)
	var i = int((pos.z / spacing) + filas / 2)

	# Asegurarse de que los índices están dentro del rango
	if i >= 0 and i < filas and j >= 0 and j < columnas:
		var valor_actual = matriz[i][j]

		if valor_actual == 1:
			var target_mesh = celdas[i][j]
			var material = StandardMaterial3D.new()
			material.albedo_color = Color(0.4, 0.26, 0.13)  # Café
			target_mesh.set_surface_override_material(0, material)
			matriz[i][j] = 2
