extends MeshInstance


onready var coll_shape = get_node("../CollisionShape")
var meta
var x ="blaz"
# Called when the node enters the scene tree for the first time.
func _ready():
	#Array that holds multiple arrays
	var arr = Array()
	arr.resize(Mesh.ARRAY_MAX)
	
	var tmpMesh = ArrayMesh.new()
	
	# PoolVectorXXArrays for mesh construction.
	var verts = PoolVector3Array()
	var uvs = PoolVector2Array()
	var normals = PoolVector3Array()
	var indices = PoolIntArray()
	var colors = PoolColorArray()
	
	#vr.log_info("jewaxuxetumare>:C10")

	#######################################
	## Insert code here to generate mesh ##
	#######################################
	#verts += Mesh.ARRAY_VERTEX
	#uvs += Mesh.ARRAY_TEX_UV
	#normals += Mesh.ARRAY_NORMAL
	#indices += Mesh.ARRAY_INDEX
	
	#verts.push_back(Vector3(0,1,0))
	#verts.push_back(Vector3(1,0,0))
	#verts.push_back(Vector3(0,0,1))

	verts.append(Vector3(-1,-1,0))
	indices.append(0)
	
	verts.append(Vector3(0,1,0))
	indices.append(1)
	
	verts.append(Vector3(1,-1,0))
	indices.append(2)

	#var tmpMesh = ArrayMesh.new()
	#var arrays = Array()
	#arrays.resize(ArrayMesh.ARRAY_MAX)
	#arrays[ArrayMesh.ARRAY_VERTEX] = vertices

	#tmpMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	#$MeshInstance.mesh = tmpMesh
	
	#vr.log_info("jewaxuxetumare>:C11")

	# Assign arrays to mesh array.
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_INDEX] = indices
	#vr.log_info("jewaxuxetumare>:C11.5")

	# Create mesh surface from mesh array.
	#quizas se muere porque esta vacio al momento de crerlo, no inserte nada en el generate meshowoo, no les he hechoappend sth
	tmpMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr) # No blendshapes or compression used.
	#vr.log_info("jewaxuxetumare>:C12")
	mesh = tmpMesh
	#vr.log_info("12.5")
	coll_shape.shape = mesh.create_trimesh_shape()
	#vr.log_info("12.55")
	
	var mdt = MeshDataTool.new()
	#vr.log_info("jewaxuxetumare>:C13")
	mdt.create_from_surface(mesh,0)
	#vr.log_info("jewaxuxetumare>:C14")
	
	meta = mdt.get_edge_meta(1)
	#vr.log_info("jewaxuxetumare>:C15")
	#vr.log_info(typeof(meta))
	#vr.log_info("jewaxuxetumare>:C16")
	#vr.log_info("hola")
	#x = "gdfhnkhsbooooaoaoaoao"
	#for i in range(mdt.get_vertex_count()):
	#	var vertex = mdt.get_vertex(i)
	#	vr.log_info(vertex)
	#var num_vert = mdt.get_vertex_count()
	#vr.log_info(str(num_vert))
	#vr.log_info("hola")
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	vr.log_info("wat")
#	vr.log_info(typeof(meta))
#	var x2 = "kdlfjslkkksksksks"
#	vr.log_info(x)
#	vr.log_info(x2)
