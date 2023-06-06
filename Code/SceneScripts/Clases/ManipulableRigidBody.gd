# Attach this script to any rigid body you want to be grabbable
# by the Feature_RigidBodyGrab
extends RigidBody

class_name ManipulableRigidBody

# Emitted when the objects grabbability changes state.
# Example usage could be for making an object "glow" when it is within
# grab distance.
signal grabbability_changed(body, grabbable, controller)
export(Material) var cross_section_material

#onready var body_mesh = $ManipulableMesh

var controller = null;
var other_controller = null;
var controller_feature = null;
var other_controller_feature = null;

# the grab feature class that's currently holding us, null if not held
var feature_grab_node = null;
var delta_orientation = Basis();
var delta_position = Vector3();
var is_grabbed := false

# zoom variables
var started_zoom = false;
var zooming = false;
var starting_zoom_distance = 0;

# properties variables
var edges_ig = null
var normals_ig = null

# slice variables
export var enabled:bool = true
export (int, 1, 10)var _delete_at_children = 3 
export (int, 1, 10)var _disable_at_children = 3 
#export (int,LAYERS_3D_PHYSICS) var _cut_body_collision_layer
#export (int,LAYERS_3D_PHYSICS) var _cut_body_collision_mask
export var _cut_body_gravity_scale:float
export (Material)var _cross_section_material =  null
export var _cross_section_texture_UV_scale:float = 1
export var _cross_section_texture_UV_offset:Vector2 = Vector2(0,0)
export var _apply_force_on_cut:bool = false
export var _normal_force_on_cut:float  = 1
var _current_child_number = 0
var _mesh:MeshInstance = null
var _collider:CollisionShape = null

#var manipulable_model = preload("res://Scenes/Features/ManipulableModel.tscn")
# fin slice variables

# set to false to prevent the object from being grabbable
export var grab_enabled := true
# set to true to allow grab to be transferable between hands
export var is_transferable := true

var last_reported_collision_pos : Vector3 = Vector3(0,0,0);

var _orig_can_sleep := true;

var _release_next_physics_step := false;
var _cached_linear_velocity := Vector3(0,0,0); # required for kinematic grab
var _cached_angular_velocity := Vector3(0,0,0);

func _ready():
	set_mode(RigidBody.MODE_STATIC)
	set_collision_layer_bit(1, true)
	#set_collision_layer_bit(2, true)
	#set_collision_mask_bit(1, true)
	vr.log_info("ready del manipulable");
	
	for child in get_children():
		#vr.log_info("child is "+ str(child))
		if child is MeshInstance:
			_mesh = child
			vr.log_info("found mesh of "+str(self))
		if child is CollisionShape:
			_collider = child
			vr.log_info("found collider of "+str(self))
		if _mesh!= null and _collider !=null:
			_mesh.global_transform.origin = global_transform.origin
			_mesh.create_convex_collision()
			_collider.shape = _mesh.get_child(0).get_child(0).shape
			_mesh.get_child(0).queue_free()
			_collider.scale = _mesh.scale
			_collider.rotation_degrees = _mesh.rotation_degrees
	#		print("children of object are ",get_children(),area.get_child(0))
	#		print("current_number ",current_child_number," delete at ",delete_at_children)
			if _current_child_number >= _delete_at_children:
				queue_free()
			if _current_child_number >= _disable_at_children:
				enabled = false
			break
	set_initial_highlight()
	set_up_immediate_geometry_instances()
	#ogkdsal

func get_mesh():
	vr.log_info("get mesh" + str(_mesh))
	return _mesh

func get_collider():
	vr.log_info("get collider" + str(_collider))
	return _collider

func get_cross_section_material():
	return _cross_section_material

func set_initial_highlight():
	var material = _mesh.get_surface_material(0)
	var shader = material.next_pass.shader
	var new_shader = Shader.new()
	new_shader.set_code(shader.get_code())
	var new_material = SpatialMaterial.new()
	var new_shader_material = ShaderMaterial.new()
	new_shader_material.shader = new_shader
	new_material.next_pass = new_shader_material
	_mesh.set_surface_material(0,new_material)	
	_mesh.set_material_override(new_material)
	set_highlight(0.0)

func set_up_immediate_geometry_instances():
	# Edges ImmediateGeometry	
	edges_ig = ImmediateGeometry.new()
	var edges_sm = SpatialMaterial.new()
	edges_sm.flags_unshaded = true
	edges_sm.vertex_color_use_as_albedo = true
	edges_ig.material_override = edges_sm
	edges_ig.name = "Wireframe_ImmediateGeometry"

	# Normals ImmediateGeometry
	normals_ig = ImmediateGeometry.new()
	var normals_sm = SpatialMaterial.new()
	normals_sm.flags_unshaded = true
	normals_sm.vertex_color_use_as_albedo = true
	normals_ig.material_override = normals_sm
	normals_ig.name = "SurfaceNormals_ImmediateGeometry"

func set_highlight(width:float):
	_mesh.get_surface_material(0).next_pass.set_shader_param("border_width",width)
	
func update_edges_visibility(boolean):
	if(boolean):
		draw_wireframe()
	else:
		edges_ig.clear()
	
func update_normals_visibility(boolean):
	if(boolean):
		draw_normals()
	else:
		normals_ig.clear()
	
func draw_wireframe():
	edges_ig.begin(Mesh.PRIMITIVE_LINES)
	edges_ig.set_color(Color.purple)

	var mesh_resource = _mesh.get_mesh()
	mesh_resource.create_outline(1.0)
	var vertices = mesh_resource.get_faces()
	
	var i = 0
	while i < vertices.size():
		edges_ig.add_vertex(vertices[i])
		edges_ig.add_vertex(vertices[i+1])
		edges_ig.add_vertex(vertices[i+1])
		edges_ig.add_vertex(vertices[i+2])
		edges_ig.add_vertex(vertices[i+2])
		edges_ig.add_vertex(vertices[i])
		i += 3
	edges_ig.end()
	var sf = 1.001
	edges_ig.set_scale(Vector3(sf, sf, sf))
	_mesh.add_child(edges_ig)

func draw_normals():
	normals_ig.begin(Mesh.PRIMITIVE_LINES)
	normals_ig.set_color(Color.white)

	var mesh_resource = _mesh.get_mesh()
	var modelVertices = mesh_resource.get_faces()
	var arrayMesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	arrays[ArrayMesh.ARRAY_VERTEX] = modelVertices
	arrayMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var meshDataTool = MeshDataTool.new()
	meshDataTool.create_from_surface(arrayMesh,0)

	var i = 0
	while i < meshDataTool.get_face_count():
		var verticesIndex = i * 3
		var a = modelVertices[verticesIndex]
		var b = modelVertices[verticesIndex + 1]
		var c = modelVertices[verticesIndex + 2]
		var face_center = (a+b+c)/3
		normals_ig.add_vertex(face_center)
		normals_ig.add_vertex(meshDataTool.get_face_normal(i) + face_center)
		i += 1
	normals_ig.end()
	_mesh.add_child(normals_ig)

# funciones del slice
func _create_cut_body(_sign,mesh_instance,cutplane : Plane, manipulation_feature):
	vr.log_info("CREar UN CUT BODY, llamare instance model");
	var rigid_body_half = manipulation_feature.instance_model()
	#var rigid_body_half = manipulable_model.instance()
	#get_tree().get_root().add_child(rigid_body_half)
	#get_tree().get_root().add_child(rigid_body_half)
	#var rigid_body_half = ManipulableRigidBody.new();
	#vr.log_info("ahi si se creo")
	#rigid_body_half.collision_layer = _cut_body_collision_layer
	#rigid_body_half.collision_mask = _cut_body_collision_mask
	rigid_body_half.gravity_scale = _cut_body_gravity_scale
#	rigid_body_half.physics_material_override = load("res://scenes/models/BeepCube_Cut.phymat");
	rigid_body_half.global_transform = global_transform;
	#vr.log_info("ya setie el global transform")
	#create mesh
	var object = MeshInstance.new()
	#vr.log_info("cree un new mesh instance")
	object.mesh = mesh_instance
	#vr.log_info("setie el mesh instance post")
	object.scale = _mesh.scale
	#vr.log_info("going to ask 4 surface count")
	if _mesh.mesh.get_surface_count() > 0:
		#vr.log_info("surface count is greater than 0")
#		print(_mesh.mesh.get_surface_count())
		var material_count
		if _cross_section_material != null:
			 material_count= _mesh.mesh.get_surface_count()+1
		else:
			 material_count= _mesh.mesh.get_surface_count()
		for i in range(material_count):
			var mat 
			if i == material_count -1 and _cross_section_material != null:
				mat = _cross_section_material
			else:
				mat = _mesh.mesh.surface_get_material(i)
			object.mesh.surface_set_material(i,mat)
	#create collider 
	#vr.log_info("creando collider antes de setear")
	var coll = CollisionShape.new()
	#vr.log_info("creado ya el collider")
	#add the body to scene
	rigid_body_half.add_child(object)
	#vr.log_info("agregue el mesh como child")
	#object.create_convex_collision()
	#vr.log_info("agregare convex collision cmo hijo")
	rigid_body_half.add_child(coll)
	#vr.log_info("voy a agregar el script")
	rigid_body_half.set_script(self.get_script())
	#vr.log_info("agrege el script")
	#rigid_body_half._cut_body_collision_layer = _cut_body_collision_layer
	#rigid_body_half._cut_body_collision_mask = _cut_body_collision_mask
	rigid_body_half._cut_body_gravity_scale = _cut_body_gravity_scale
	rigid_body_half._current_child_number = _current_child_number+1 
	rigid_body_half._delete_at_children =  _delete_at_children
	rigid_body_half._disable_at_children = _disable_at_children
	rigid_body_half._cross_section_material = _cross_section_material
	rigid_body_half._normal_force_on_cut = _normal_force_on_cut
	#vr.log_info("agregare al wea como child del padre")
	get_tree().get_root().add_child(rigid_body_half)
	#vr.log_info("agregue ya al padre")
	#vr.log_info("aca viene info porque equis de")
	#vr.log_info("amount of faces"+str(object.mesh.get_surface_count()))
	var mesh = object.mesh
	var vertices = mesh.get_faces()
	var arrays = object.mesh.surface_get_arrays(2)
	#vr.log_info("why do u die")
	#var normals = arrays[2]
	#vr.log_info("dont die")
	#ese de arriba fue el ultimo en aparecer
	#for i in arrays:
	#	vr.log_info("olaaaafdskdsklfnklfdn")
	#	vr.log_info(i)
	if _apply_force_on_cut:
		rigid_body_half.apply_central_impulse(_sign*cutplane.normal*_normal_force_on_cut)
	

func cut_object(cutplane:Plane, manipulation_feature):
	vr.log_info("CORTARRRRR");
	#  there are a lot of parameters for the constructor
	#-------------------------------------------------
	#  cutplane = plane to cut mesh with , in global space
	#  mesh =  the mesh you want to cut
	#  is solid = if you want a surface for cross section
	#  cross_section_material = cross section material you want for the cut pieces , overides is_solid to be true
	#  cross section texture UV scale , scale of the planar projection UV
	#  cross section texture UV offset , offset of the Planar projection UV
	#  createReverseTriangleWindings 
	#  shareVertices
	#  smoothVertices
	#-------------------------------------------------
	if enabled: 
		#vr.log_info("ESTOY ENABLED");
		var slices = slice_calculator.new(cutplane,_mesh,true,_cross_section_material,_cross_section_texture_UV_scale,_cross_section_texture_UV_offset,true,true,true)
	#	print("+ve mesh is ",slices.negative_mesh())
	#	print("-ve mesh is ",slices.positive_mesh())
		vr.log_info("voi a crear las mitades");
		_create_cut_body(-1,slices.negative_mesh(),cutplane, manipulation_feature);
		_create_cut_body( 1,slices.positive_mesh(),cutplane, manipulation_feature);
		queue_free();

func _get_configuration_warning():
	var warning = PoolStringArray()
	if _mesh == null: 
		warning.append("please add a Mesh Instance with some mesh")
	return warning.join("\n")
# fin funciones del slice

func grab_init(node) -> void:
	feature_grab_node = node
	
	is_grabbed = true
	sleeping = false;
	_orig_can_sleep = can_sleep;
	can_sleep = false;
	vr.log_info("se llamo el grab init");

func _release():
	controller = feature_grab_node.controller
	is_grabbed = false
	feature_grab_node = null
	can_sleep = _orig_can_sleep;


func grab_release() -> void:
	_release();
	
#The zoom started so we have to start the distance calculation
func zoom_init(distance, first_controller_feature, second_controller_feature, first_controller, second_controller) -> void:
	#vr.log_info("se llamo el zoom init");
	zooming = true
	starting_zoom_distance = distance
	controller = first_controller
	other_controller = second_controller
	controller_feature = first_controller_feature
	other_controller_feature = second_controller_feature

func zoom_release() -> void:
	#vr.log_info("se llamo el zoom release");
	zooming = false
	controller_feature = null
	other_controller_feature = null
	starting_zoom_distance = 0

func cut_init(first_controller_feature, second_controller_feature, first_controller, second_controller) -> void:
	#vr.log_info("se llamo el cut init");
	controller = first_controller
	other_controller = second_controller
	controller_feature = first_controller_feature
	other_controller_feature = second_controller_feature
	controller_feature.cut()
	#vr.log_info("adios init");
	
func be_selected() -> void:
	vr.log_info("se llamo el be selected");
	#selected = true
	#vr.log_info("se llamo el be selected");

#func cut_release():
#	vr.log_info("se llamo el cut release");

func orientation_follow(state, current_basis : Basis, target_basis : Basis) -> void:
	var delta : Basis = target_basis * current_basis.inverse();
	
	var q = Quat(delta);
	var axis = Vector3(q.x, q.y, q.z);

	if (axis.length_squared() > 0.0001):  # bullet fuzzyzero() is < FLT_EPSILON (1E-5)
		axis = axis.normalized();
		var angle = 2.0 * acos(q.w);
		state.set_angular_velocity(axis * (angle / (state.get_step())));
	else:
		state.set_angular_velocity(Vector3(0,0,0));



func position_follow(state, current_position, target_position) -> void:
	var dir = target_position - current_position;
	state.set_linear_velocity(dir / state.get_step());

# called by the Feature_RigidBodyGrab class when this object becomes the
# next grabbable object candidacy
func _notify_became_grabbable(feature_grab):
	# for now, just fire the signal
	emit_signal("grabbability_changed",self,true,feature_grab.controller)

# called by the Feature_RigidBodyGrab class when this object loses the
# next grabbable object candidacy
func _notify_lost_grabbable(feature_grab):
	# for now, just fire the signal
	emit_signal("grabbability_changed",self,false,feature_grab.controller)

func _integrate_forces(_state):
	if (!is_grabbed): return;
	
	if (_release_next_physics_step):
		_release_next_physics_step = false;
		_release();
	return;
	
func _physics_process(_delta):
	if zooming:
		#vr.log_info("fisic proses suming");
		var x = controller.get_global_transform().origin.x - other_controller.get_global_transform().origin.x
		var y = controller.get_global_transform().origin.y - other_controller.get_global_transform().origin.y
		var distance = sqrt(x*x + y*y)
		var zoom_delta = distance - starting_zoom_distance
		var zoom_speed = zoom_delta * 0.05
		var zoom_factor = 1.0 + zoom_speed
		#vr.log_info("ek zoom factor es: " + str(zoom_factor));
		#vr.log_info("ek zoom delta es: " + str(zoom_delta));
		#vr.log_info("ek distance es: " + str(distance));
		#vr.log_info("ek distance es: " + str(starting_zoom_distance));

		global_scale(Vector3(zoom_factor, zoom_factor, zoom_factor));
	#update_properties()

func setup(mesh: Mesh, position: Transform):
	vr.log_info("ssetup setup");
	_mesh.mesh = mesh
	self.transform = position

func cut(origin: Vector3, normal: Vector3):
	vr.log_info("ola q tal");
	return $Slicer.slice(_mesh.mesh, self.transform, origin, normal, cross_section_material)
