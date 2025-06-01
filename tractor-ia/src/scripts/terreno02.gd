extends StaticBody3D

@export var filas: int = 40
@export var columnas: int = 40
@export var probabilidad_obstaculos: float = 0.004
var spacing := 2
var matriz = []
var celdas = []
var obstaculos = []
var vallas = []  # Para el perímetro
var decoraciones = []  # Para elementos decorativos

var textura_tierra_sin_arar = preload("res://src/assets/img/grassB.bmp.png")
var textura_tierra_arada = preload("res://src/assets/img/arada.png")

enum TipoTerreno {
	TIERRA_SIN_ARAR = 0,
	TIERRA_ARADA = 1,
	OBSTACULO = 2
}

func _ready() -> void:
	# var mesh_node = $base
	# var material_base = mesh_node.get_surface_override_material(0)
	# if material_base == null:
	# 	material_base = StandardMaterial3D.new()
	# Césped más natural para la base
	# material_base.albedo_color = Color(0.2, 0.4, 0.1)
	# material_base.roughness = 0.8
	# material_base.metallic = 0.0
	# mesh_node.set_surface_override_material(0, material_base)
	
	var plane_mesh = PlaneMesh.new()
	generar_campo()
	crear_celdas_visuales(plane_mesh)
	crear_obstaculos_3d()
	crear_valla_perimetral()
	agregar_decoraciones()

func generar_campo():
	matriz.clear()
	for i in range(filas):
		var fila := []
		for j in range(columnas):
			if randf() < probabilidad_obstaculos:
				fila.append(TipoTerreno.OBSTACULO)
			else:
				fila.append(TipoTerreno.TIERRA_SIN_ARAR)
		matriz.append(fila)

func crear_celdas_visuales(plane_mesh: PlaneMesh):
	celdas.clear()

	# Validación rápida
	if matriz.size() != filas or matriz[0].size() != columnas:
		push_error("Dimensiones de la matriz no coinciden con filas/columnas.")
		return

	for i in range(filas):
		var fila_celdas := []
		for j in range(columnas):
			var tipo_terreno = matriz[i][j]
			var mesh_instance := MeshInstance3D.new()
			mesh_instance.mesh = plane_mesh

			# Posición centrada y ajustada en altura
			var x := (j - columnas / 2.0) * spacing
			var z := (i - filas / 2.0) * spacing
			var y := 0.02  # variación para naturalidad
			mesh_instance.transform.origin = Vector3(x + 1, y, z + 1)

			# Crear y aplicar material
			var material := StandardMaterial3D.new()
			actualizar_material_celda(material, tipo_terreno)
			mesh_instance.set_surface_override_material(0, material)

			add_child(mesh_instance)
			fila_celdas.append(mesh_instance)
		
		celdas.append(fila_celdas)


func crear_valla_perimetral():
	vallas.clear()
	var altura_valla = 1.5
	var ancho_valla = 0.1
	
	# Calcular límites del campo
	var limite_x = columnas * spacing / 2.0 + spacing
	var limite_z = filas * spacing / 2.0 + spacing
	
	# Valla horizontal superior
	for i in range(int(columnas * spacing / spacing) + 3):
		var valla = crear_poste_valla(altura_valla)
		var x = (i * spacing) - limite_x
		valla.position = Vector3(x, 0, -limite_z)
		add_child(valla)
		vallas.append(valla)
	
	# Valla horizontal inferior
	for i in range(int(columnas * spacing / spacing) + 3):
		var valla = crear_poste_valla(altura_valla)
		var x = (i * spacing) - limite_x
		valla.position = Vector3(x, 0, limite_z)
		add_child(valla)
		vallas.append(valla)
	
	# Valla vertical izquierda
	for i in range(int(filas * spacing / spacing) + 1):
		var valla = crear_poste_valla(altura_valla)
		var z = (i * spacing) - limite_z + spacing
		valla.position = Vector3(-limite_x, 0, z)
		add_child(valla)
		vallas.append(valla)
	
	# Valla vertical derecha
	for i in range(int(filas * spacing / spacing) + 1):
		var valla = crear_poste_valla(altura_valla)
		var z = (i * spacing) - limite_z + spacing
		valla.position = Vector3(limite_x, 0, z)
		add_child(valla)
		vallas.append(valla)

func crear_poste_valla(altura: float) -> MeshInstance3D:
	var poste_grupo = Node3D.new()
	
	# Poste principal
	var poste = MeshInstance3D.new()
	var poste_mesh = CylinderMesh.new()
	poste_mesh.top_radius = 0.08
	poste_mesh.bottom_radius = 0.08
	poste_mesh.height = altura
	poste_mesh.radial_segments = 8
	poste.mesh = poste_mesh
	
	var material_madera = StandardMaterial3D.new()
	material_madera.albedo_color = Color(0.4, 0.25, 0.15)
	material_madera.roughness = 0.9
	material_madera.metallic = 0.0
	poste.set_surface_override_material(0, material_madera)
	poste.position = Vector3(0, altura/2, 0)
	
	# Tabla horizontal superior
	var tabla_sup = MeshInstance3D.new()
	var tabla_mesh = BoxMesh.new()
	tabla_mesh.size = Vector3(1.8, 0.1, 0.15)
	tabla_sup.mesh = tabla_mesh
	tabla_sup.set_surface_override_material(0, material_madera)
	tabla_sup.position = Vector3(0, altura * 0.8, 0)
	
	# Tabla horizontal inferior
	var tabla_inf = MeshInstance3D.new()
	var tabla_inf_mesh = BoxMesh.new()
	tabla_inf_mesh.size = Vector3(1.8, 0.1, 0.15)
	tabla_inf.mesh = tabla_inf_mesh
	tabla_inf.set_surface_override_material(0, material_madera)
	tabla_inf.position = Vector3(0, altura * 0.4, 0)
	
	poste_grupo.add_child(poste)
	poste_grupo.add_child(tabla_sup)
	poste_grupo.add_child(tabla_inf)
	
	var contenedor = MeshInstance3D.new()
	contenedor.add_child(poste_grupo)
	return contenedor

func agregar_decoraciones():
	decoraciones.clear()
	
	# Agregar algunas rocas decorativas
	for i in range(5):
		var roca = crear_roca()
		var x = randf_range(-columnas * spacing / 2.0, columnas * spacing / 2.0)
		var z = randf_range(-filas * spacing / 2.0, filas * spacing / 2.0)
		
		# Verificar que no esté en el área de cultivo
		var j_grid = int((x / spacing) + columnas / 2.0)
		var i_grid = int((z / spacing) + filas / 2.0)
		
		if i_grid < 0 or i_grid >= filas or j_grid < 0 or j_grid >= columnas:
			roca.position = Vector3(x, 0, z)
			add_child(roca)
			decoraciones.append(roca)
	
	# Agregar algunos arbustos pequeños
	for i in range(8):
		var arbusto = crear_arbusto()
		var x = randf_range(-columnas * spacing / 2.0 - spacing, columnas * spacing / 2.0 + spacing)
		var z = randf_range(-filas * spacing / 2.0 - spacing, filas * spacing / 2.0 + spacing)
		
		arbusto.position = Vector3(x, 0, z)
		add_child(arbusto)
		decoraciones.append(arbusto)

func crear_roca() -> MeshInstance3D:
	var roca = MeshInstance3D.new()
	var roca_mesh = SphereMesh.new()
	roca_mesh.radius = randf_range(0.3, 0.8)
	roca_mesh.height = randf_range(0.4, 0.6)
	roca.mesh = roca_mesh
	
	var material_roca = StandardMaterial3D.new()
	material_roca.albedo_color = Color(0.4, 0.4, 0.45)
	material_roca.roughness = 0.95
	material_roca.metallic = 0.1
	roca.set_surface_override_material(0, material_roca)
	
	# Aplastar un poco la roca
	roca.scale = Vector3(1.2, 0.6, 1.0)
	roca.rotation_degrees.y = randf_range(0, 360)
	
	return roca

func crear_arbusto() -> MeshInstance3D:
	var arbusto_grupo = Node3D.new()
	
	# Crear varias esferas pequeñas para simular un arbusto
	for i in range(randf_range(2, 5)):
		var hoja = MeshInstance3D.new()
		var hoja_mesh = SphereMesh.new()
		hoja_mesh.radius = randf_range(0.2, 0.4)
		hoja_mesh.height = randf_range(0.3, 0.6)
		hoja.mesh = hoja_mesh
		
		var material_arbusto = StandardMaterial3D.new()
		material_arbusto.albedo_color = Color(0.15, 0.5, 0.12)
		material_arbusto.roughness = 0.8
		hoja.set_surface_override_material(0, material_arbusto)
		
		hoja.position = Vector3(
			randf_range(-0.3, 0.3),
			randf_range(0.1, 0.4),
			randf_range(-0.3, 0.3)
		)
		
		arbusto_grupo.add_child(hoja)
	
	var contenedor = MeshInstance3D.new()
	contenedor.add_child(arbusto_grupo)
	return contenedor

func crear_obstaculos_3d():
	obstaculos.clear()
	for i in range(filas):
		for j in range(columnas):
			if matriz[i][j] == TipoTerreno.OBSTACULO:
				var obstaculo_body = StaticBody3D.new()
				var mesh_instance = crear_arbol_mejorado()
				var collision_shape = crear_colision_tronco()
				
				var x = (j - columnas / 2.0) * spacing
				var z = (i - filas / 2.0) * spacing
				obstaculo_body.position = Vector3(x, 0, z)

				obstaculo_body.add_child(mesh_instance)
				obstaculo_body.add_child(collision_shape)

				add_child(obstaculo_body)
				obstaculos.append(obstaculo_body)


func crear_arbol_mejorado() -> MeshInstance3D:
	var arbol_completo = Node3D.new()
	
	# Variación aleatoria para hacer cada árbol único
	var altura_base = randf_range(1.8, 2.5)
	var grosor_base = randf_range(0.2, 0.3)
	var tamaño_copa = randf_range(1.0, 1.4)
	
	# === RAÍCES VISIBLES ===
	for i in range(4):
		var raiz = MeshInstance3D.new()
		var raiz_mesh = CylinderMesh.new()
		raiz_mesh.top_radius = 0.08
		raiz_mesh.bottom_radius = 0.12
		raiz_mesh.height = 0.4
		raiz.mesh = raiz_mesh
		
		var material_raiz = StandardMaterial3D.new()
		material_raiz.albedo_color = Color(0.25, 0.15, 0.08)
		material_raiz.roughness = 0.9
		raiz.set_surface_override_material(0, material_raiz)
		
		var angulo = i * PI / 2 + randf_range(-0.3, 0.3)
		raiz.position = Vector3(cos(angulo) * 0.3, -0.1, sin(angulo) * 0.3)
		raiz.rotation_degrees = Vector3(randf_range(15, 25), angulo * 180/PI, 0)
		
		arbol_completo.add_child(raiz)
	
	# === TRONCO PRINCIPAL ===
	var tronco = MeshInstance3D.new()
	var tronco_mesh = CylinderMesh.new()
	tronco_mesh.top_radius = grosor_base * 0.6
	tronco_mesh.bottom_radius = grosor_base
	tronco_mesh.height = altura_base
	tronco_mesh.radial_segments = 12
	tronco.mesh = tronco_mesh
	
	var material_tronco = StandardMaterial3D.new()
	material_tronco.albedo_color = Color(0.32, 0.22, 0.12)
	material_tronco.roughness = 0.85
	material_tronco.metallic = 0.0
	tronco.set_surface_override_material(0, material_tronco)
	tronco.position = Vector3(0, altura_base/2, 0)
	
	# === COPA PRINCIPAL ===
	var copa = MeshInstance3D.new()
	var copa_mesh = SphereMesh.new()
	copa_mesh.radius = tamaño_copa
	copa_mesh.height = tamaño_copa * 1.6
	copa.mesh = copa_mesh
	
	var material_copa = StandardMaterial3D.new()
	material_copa.albedo_color = Color(0.18, 0.55, 0.12)
	material_copa.roughness = 0.75
	copa.set_surface_override_material(0, material_copa)
	copa.position = Vector3(0, altura_base + tamaño_copa * 0.6, 0)
	
	# === CAPAS DE FOLLAJE ===
	var num_capas = randi_range(3, 5)
	for i in range(num_capas):
		var capa = MeshInstance3D.new()
		var capa_mesh = SphereMesh.new()
		capa_mesh.radius = randf_range(0.6, 0.9)
		capa_mesh.height = randf_range(1.0, 1.4)
		capa.mesh = capa_mesh
		
		var color_variacion = randf_range(-0.05, 0.05)
		var material_capa = StandardMaterial3D.new()
		material_capa.albedo_color = Color(0.18 + color_variacion, 0.55 + color_variacion, 0.12 + color_variacion)
		material_capa.roughness = 0.75
		capa.set_surface_override_material(0, material_capa)
		
		var radio = randf_range(0.5, 1.0)
		var angulo = randf_range(0, PI * 2)
		capa.position = Vector3(
			cos(angulo) * radio,
			altura_base + randf_range(0.8, 2.2),
			sin(angulo) * radio
		)
		
		arbol_completo.add_child(capa)
	
	# === RAMAS PRINCIPALES ===
	var num_ramas = randi_range(4, 7)
	for i in range(num_ramas):
		var rama = MeshInstance3D.new()
		var rama_mesh = CylinderMesh.new()
		rama_mesh.top_radius = 0.03
		rama_mesh.bottom_radius = randf_range(0.06, 0.1)
		rama_mesh.height = randf_range(0.6, 1.2)
		rama.mesh = rama_mesh
		rama.set_surface_override_material(0, material_tronco)
		
		var angulo = (i * PI * 2 / num_ramas) + randf_range(-0.5, 0.5)
		var altura_rama = altura_base * randf_range(0.6, 0.9)
		rama.position = Vector3(
			cos(angulo) * 0.15,
			altura_rama,
			sin(angulo) * 0.15
		)
		rama.rotation_degrees = Vector3(
			randf_range(20, 45),
			angulo * 180/PI,
			randf_range(-15, 15)
		)
		
		arbol_completo.add_child(rama)
	
	# === FLORES OCASIONALES ===
	if randf() < 0.3:  # 30% de probabilidad de tener flores
		for i in range(randi_range(3, 8)):
			var flor = MeshInstance3D.new()
			var flor_mesh = SphereMesh.new()
			flor_mesh.radius = 0.05
			flor.mesh = flor_mesh
			
			var material_flor = StandardMaterial3D.new()
			material_flor.albedo_color = Color(1.0, 0.8, 0.9)  # Rosa claro
			material_flor.emission = Color(0.2, 0.1, 0.15)
			flor.set_surface_override_material(0, material_flor)
			
			var radio = randf_range(0.8, 1.2)
			var angulo = randf_range(0, PI * 2)
			flor.position = Vector3(
				cos(angulo) * radio,
				altura_base + randf_range(1.0, 2.0),
				sin(angulo) * radio
			)
			
			arbol_completo.add_child(flor)
	
	# Ensamblar todo
	arbol_completo.add_child(tronco)
	arbol_completo.add_child(copa)
	
	# Rotación aleatoria para variedad
	arbol_completo.rotation_degrees.y = randf_range(0, 360)
	
	var contenedor = MeshInstance3D.new()
	contenedor.add_child(arbol_completo)
	return contenedor

func crear_colision_tronco() -> CollisionShape3D:
	var collision_shape = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = 4.5
	collision_shape.shape = shape
	collision_shape.position = Vector3(0, 2.25, 0)
	return collision_shape

func actualizar_material_celda(material: StandardMaterial3D, tipo: TipoTerreno):
	match tipo:
		TipoTerreno.TIERRA_SIN_ARAR:
			material.albedo_texture = textura_tierra_sin_arar
			material.roughness = 0.0
			material.roughness_texture = textura_tierra_sin_arar
			
			material.metallic = 0.0
			material.metallic_specular = 0.0
			
			material.normal_enabled = true
			material.normal_scale = 1.2
			material.normal_texture = textura_tierra_sin_arar
		TipoTerreno.TIERRA_ARADA:
			material.albedo_texture = textura_tierra_arada
			material.roughness = 0.0
			material.roughness_texture = textura_tierra_arada
			
			material.metallic = 0.0
			material.metallic_specular = 0.0
			
			material.normal_enabled = true
			material.normal_scale = 1.1
			material.normal_texture = textura_tierra_arada
		TipoTerreno.OBSTACULO:
			material.albedo_color = Color(0.6, 0.3, 0.1)
			material.roughness = 0.85

func _process(delta: float) -> void:
	if not Global.surcador_collision:
		return
	
	var pos = Global.surcador_position
	var j = int((pos.x / spacing) + columnas / 2)
	var i = int((pos.z / spacing) + filas / 2)
	
	if i >= 0 and i < filas and j >= 0 and j < columnas:
		if matriz[i][j] == TipoTerreno.TIERRA_SIN_ARAR:
			matriz[i][j] = TipoTerreno.TIERRA_ARADA
			var target_mesh = celdas[i][j]
			var material = StandardMaterial3D.new()
			actualizar_material_celda(material, TipoTerreno.TIERRA_ARADA)
			target_mesh.set_surface_override_material(0, material)

func regenerar_campo():
	# Limpiar elementos decorativos
	for decoracion in decoraciones:
		decoracion.queue_free()
	for valla in vallas:
		valla.queue_free()
	for obstaculo in obstaculos:
		obstaculo.queue_free()
	for fila in celdas:
		for celda in fila:
			celda.queue_free()
	
	decoraciones.clear()
	vallas.clear()
	
	generar_campo()
	var plane_mesh = PlaneMesh.new()
	crear_celdas_visuales(plane_mesh)
	crear_obstaculos_3d()
	crear_valla_perimetral()
	agregar_decoraciones()

func obtener_tipo_terreno(pos_mundial: Vector3) -> TipoTerreno:
	var j = int((pos_mundial.x / spacing) + columnas / 2.0)
	var i = int((pos_mundial.z / spacing) + filas / 2.0)
	
	if i >= 0 and i < filas and j >= 0 and j < columnas:
		return matriz[i][j]
	else:
		return TipoTerreno.OBSTACULO

func obtener_progreso_arado() -> float:
	var total_tierra = 0
	var tierra_arada = 0
	
	for i in range(filas):
		for j in range(columnas):
			if matriz[i][j] != TipoTerreno.OBSTACULO:
				total_tierra += 1
				if matriz[i][j] == TipoTerreno.TIERRA_ARADA:
					tierra_arada += 1
	
	return float(tierra_arada) / float(total_tierra) * 100.0 if total_tierra > 0 else 0.0
