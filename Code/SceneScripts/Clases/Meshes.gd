extends Node


onready var cubeMeshInstance = $Cube
onready var camera = get_node("../Character/OQ_ARVRCamera")

# Called when the node enters the scene tree for the first time.
func _ready():
	createAndAssignCubeMesh()
	drawSurfaceNormals()

func createAndAssignCubeMesh():
	var uniqueCubeVertices = [
		Vector3(-0.5,0.5,0.5),
		Vector3(0.5,0.5,0.5),
		Vector3(0.5,-0.5,0.5),
		Vector3(-0.5,-0.5,0.5),

		Vector3(-0.5,0.5,-0.5),
		Vector3(0.5,0.5,-0.5),
		Vector3(0.5,-0.5,-0.5),
		Vector3(-0.5,-0.5,-0.5),
	]

	var cube_faces = [
		uniqueCubeVertices[0], uniqueCubeVertices[1], uniqueCubeVertices[2], # top
		uniqueCubeVertices[0], uniqueCubeVertices[2], uniqueCubeVertices[3],
		uniqueCubeVertices[4], uniqueCubeVertices[6], uniqueCubeVertices[5], # back
		uniqueCubeVertices[4], uniqueCubeVertices[7], uniqueCubeVertices[6],
		uniqueCubeVertices[0], uniqueCubeVertices[7], uniqueCubeVertices[4], # left
		uniqueCubeVertices[0], uniqueCubeVertices[3], uniqueCubeVertices[7],
		uniqueCubeVertices[1], uniqueCubeVertices[5], uniqueCubeVertices[6], # right
		uniqueCubeVertices[1], uniqueCubeVertices[6], uniqueCubeVertices[2],
		uniqueCubeVertices[0], uniqueCubeVertices[4], uniqueCubeVertices[1], # top
		uniqueCubeVertices[4], uniqueCubeVertices[5], uniqueCubeVertices[1],
		uniqueCubeVertices[7], uniqueCubeVertices[3], uniqueCubeVertices[2], # bottom
		uniqueCubeVertices[6], uniqueCubeVertices[7], uniqueCubeVertices[2]
	]

	var sTool = SurfaceTool.new()
	sTool.begin(Mesh.PRIMITIVE_TRIANGLES)

	for x in cube_faces:
		sTool.add_vertex(x)

	sTool.generate_normals()
	cubeMeshInstance.mesh = sTool.commit()
	
	var material = SpatialMaterial.new()
	material.albedo_color = Color("36c92a")
	cubeMeshInstance.material_override = material
	
	cubeMeshInstance.create_convex_collision()
	var cubesStaticBody = cubeMeshInstance.get_child(0)
	cubesStaticBody.name = "CubeStaticBody"
	#cubesStaticBody.connect("input_event", get_node("/root/Main"), "_on_StaticBody_input_event")
	#cubesStaticBody.connect("mouse_exited", get_node("/root/Main"), "_on_StaticBody_mouse_exited")
	#cubesStaticBody.connect("mouse_entered", get_node("/root/Main"), "_on_StaticBody_mouse_entered")
	
func drawSurfaceNormals():
	var cubeMesh = cubeMeshInstance.get_mesh()
	var vertices = cubeMesh.get_faces()
	var arrayMesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	arrays[ArrayMesh.ARRAY_VERTEX] = vertices
	arrayMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var meshDataTool = MeshDataTool.new()
	meshDataTool.create_from_surface(arrayMesh, 0)
	
	var ig = ImmediateGeometry.new()
	ig.name = "SurfaceNormals_ImmediateGeometry"
	var sm = SpatialMaterial.new()
	sm.flags_unshaded = true
	sm.vertex_color_use_as_albedo = true
	ig.material_override = sm

	ig.begin(Mesh.PRIMITIVE_LINES)
	ig.set_color(Color.white)
	
	var i = 0
	while i < meshDataTool.get_face_count():
		var verticesIndex = i * 3
		var a = vertices[verticesIndex]
		var b = vertices[verticesIndex + 1]
		var c = vertices[verticesIndex + 2]
		var face_center = (a+b+c)/3

		ig.add_vertex(face_center)
		ig.add_vertex(meshDataTool.get_face_normal(i) + face_center)
		i += 1

	ig.end()
	cubeMeshInstance.add_child(ig)

"""
func drawSelectedOutline(selectedFace):
	var cubeMesh = cubeMeshInstance.get_mesh()
	
	var ig = get_node("/Cube/DrawSelectedOutline_ImmediateGeometry") if get_node_or_null("Cube/DrawSelectedOutline_ImmediateGeometry") != null else ImmediateGeometry.new()
	var sm = SpatialMaterial.new()
	sm.flags_unshaded = true
	sm.vertex_color_use_as_albedo = true
	ig.clear()
	ig.material_override = sm
	ig.name = "DrawSelectedOutline_ImmediateGeometry"

	ig.begin(Mesh.PRIMITIVE_TRIANGLES)
	ig.set_color(Color.purple)
	
	cubeMesh.create_outline(1.0)
	var vertices = cubeMesh.get_faces()
	
	var startVertex = selectedFace * 3
	ig.add_vertex(vertices[startVertex])
	ig.add_vertex(vertices[startVertex + 1])
	ig.add_vertex(vertices[startVertex + 2])
	
	ig.end()
	var sf = 1.005
	ig.set_scale(Vector3(sf, sf, sf))
	cubeMeshInstance.add_child(ig)

func _on_StaticBody_input_event(camera, event, click_position, click_normal, shape_idx):
	if event.is_action_pressed("left_mouse"):
		print("Pos ", click_position)
		var face_index = get_hit_mesh_triangle_face_index(click_position)
		if face_index > -1:
			drawSelectedOutline(face_index)

func get_hit_mesh_triangle_face_index(hitVector):
	var cubeMeshInstance = $Cube
	var cubeMesh = cubeMeshInstance.get_mesh()
	var vertices = cubeMesh.get_faces()
	var arrayMesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	arrays[ArrayMesh.ARRAY_VERTEX] = vertices
	arrayMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var meshDataTool = MeshDataTool.new()
	meshDataTool.create_from_surface(arrayMesh, 0)
	var camera_origin = camera.get_global_transform().origin
	var test_vector = hitVector - camera_origin
	var i = 0
	while i < vertices.size():
		var face_index = i / 3
		var a = cubeMeshInstance.to_global(vertices[i])
		var b = cubeMeshInstance.to_global(vertices[i + 1])
		var c = cubeMeshInstance.to_global(vertices[i + 2])
		print("Triangle coords: ", a, b, c)

		var intersects_triangle = Geometry.ray_intersects_triangle(camera_origin, test_vector, a, b, c)

		if intersects_triangle != null:
			var angle = rad2deg(test_vector.angle_to(cubeMeshInstance.to_global(meshDataTool.get_face_normal(face_index))))
			if angle > 90 and angle < 180:
				return face_index

		i += 3

	return -1
"""
