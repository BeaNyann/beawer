extends MeshInstance


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
var meta
var x ="blaz"
# Called when the node enters the scene tree for the first time.
func _ready():
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	
	# PoolVectorXXArrays for mesh construction.
	var verts = PoolVector3Array()
	var uvs = PoolVector2Array()
	var normals = PoolVector3Array()
	var indices = PoolIntArray()

	#######################################
	## Insert code here to generate mesh ##
	#######################################

	# Assign arrays to mesh array.
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_INDEX] = indices
	#vr.log_info("jewaxuxetumare>:C11")

	# Create mesh surface from mesh array.
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr) # No blendshapes or compression used.
	#vr.log_info("jewaxuxetumare>:C12")
	
	var mdt = MeshDataTool.new()
	#vr.log_info("jewaxuxetumare>:C13")
	mdt.create_from_surface(mesh)
	#vr.log_info("jewaxuxetumare>:C14")
	
	meta = mdt.get_edge_meta(1)
	#vr.log_info("jewaxuxetumare>:C15")
	#vr.log_info(typeof(meta))
	#vr.log_info("jewaxuxetumare>:C16")
	#vr.log_info("hola")
	x = "gdfhnkhsbooooaoaoaoao"
	
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	vr.log_info("wat")
#	vr.log_info(typeof(meta))
#	var x2 = "kdlfjslkkksksksks"
#	vr.log_info(x)
#	vr.log_info(x2)
