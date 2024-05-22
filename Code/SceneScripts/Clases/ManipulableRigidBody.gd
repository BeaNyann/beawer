# Attach this script to any rigid body you want to be grabbable
# by the Feature_RigidBodyGrab
extends RigidBody

class_name ManipulableRigidBody

# Emitted when the objects grabbability changes state.
# Example usage could be for making an object "glow" when it is within
# grab distance.
signal grabbability_changed(body, grabbable, controller)
export(Material) var cross_section_material

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
export var enabled: bool = true
export (int, 1, 10) var _delete_at_children = 3 
export (int, 1, 10) var _disable_at_children = 3 
export var _cut_body_gravity_scale: float
export (Material) var _cross_section_material =  null
export var _cross_section_texture_UV_scale: float = 1
export var _cross_section_texture_UV_offset: Vector2 = Vector2(0,0)
export var _apply_force_on_cut: bool = false
export var _normal_force_on_cut: float  = 1
var _current_child_number = 0

var _mesh: MeshInstance = null
var _collider: CollisionShape = null
var _marker: MeshInstance = null
var _keep_marker: bool = false

# set to false to prevent the object from being grabbable
export var grab_enabled := true
# set to true to allow grab to be transferable between hands
export var is_transferable := true

var last_reported_collision_pos : Vector3 = Vector3(0,0,0)

var _orig_can_sleep := true

var _release_next_physics_step := false;
var _cached_linear_velocity := Vector3(0,0,0); # required for kinematic grab
var _cached_angular_velocity := Vector3(0,0,0);

func _ready():
	set_mode(RigidBody.MODE_STATIC)
	set_collision_layer_bit(1, true)
	for child in get_children():
		if (child is MeshInstance):
			if (child.name == "ManipulableMesh"):
				_mesh = child
			else:
				_marker = child
				var unique_material = _marker.get_surface_material(0).duplicate()
				_marker.set_surface_material(0, unique_material)
		if (child is CollisionShape):
			_collider = child
		if (_mesh != null and _collider != null and _marker != null):
			_mesh.global_transform.origin = global_transform.origin
			_mesh.create_convex_collision()
			_collider.shape = _mesh.get_child(0).get_child(0).shape
			_mesh.get_child(0).queue_free()
			_collider.scale = _mesh.scale
			_collider.rotation_degrees = _mesh.rotation_degrees
			if (_current_child_number >= _delete_at_children):
				queue_free()
			if (_current_child_number >= _disable_at_children):
				enabled = false
			break
	set_highlight(false)
	set_up_immediate_geometry_instances()

func get_mesh():
	vr.log_info("get mesh" + str(_mesh))
	return _mesh

func get_collider():
	vr.log_info("get collider" + str(_collider))
	return _collider

func get_cross_section_material():
	return _cross_section_material

func set_up_edges_ig_instance():
	# Edges ImmediateGeometry	
	edges_ig = ImmediateGeometry.new()
	var edges_sm = SpatialMaterial.new()
	edges_sm.flags_unshaded = true
	edges_sm.vertex_color_use_as_albedo = true
	edges_ig.material_override = edges_sm
	edges_ig.name = "Wireframe_ImmediateGeometry"

func set_up_normals_ig_instance():
	# Normals ImmediateGeometry
	normals_ig = ImmediateGeometry.new()
	var normals_sm = SpatialMaterial.new()
	normals_sm.flags_unshaded = true
	normals_sm.vertex_color_use_as_albedo = true
	normals_ig.material_override = normals_sm
	normals_ig.name = "SurfaceNormals_ImmediateGeometry"

func set_up_immediate_geometry_instances():
	set_up_edges_ig_instance()
	set_up_normals_ig_instance()

func set_highlight(activate: bool):
	var color: Color = Color.chartreuse if activate else Color.gold
	_marker.get_surface_material(0).albedo_color = color
	
func update_edges_visibility(boolean: bool):
	if (boolean):
		draw_wireframe()
	else:
		edges_ig.clear()
		#edges_ig.queue_free()
	
func update_normals_visibility(boolean: bool):
	if (boolean):
		draw_normals()
	else:
		normals_ig.clear()
		#normals_ig.queue_free()
	
func draw_wireframe():
	#set_up_edges_ig_instance()
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
	#set_up_normals_ig_instance()
	normals_ig.begin(Mesh.PRIMITIVE_LINES)
	normals_ig.set_color(Color.white)

	var mesh_resource = _mesh.get_mesh()
	var modelVertices = mesh_resource.get_faces()
	var arrayMesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	arrays[ArrayMesh.ARRAY_VERTEX] = modelVertices
	arrayMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var meshDataTool = MeshDataTool.new()
	meshDataTool.create_from_surface(arrayMesh, 0)

	var scaling_factor = 0.15
	var i = 0
	while i < meshDataTool.get_face_count():
		var verticesIndex = i * 3
		var a = modelVertices[verticesIndex]
		var b = modelVertices[verticesIndex + 1]
		var c = modelVertices[verticesIndex + 2]
		var face_center = (a+b+c)/3
		normals_ig.add_vertex(face_center)
		normals_ig.add_vertex((meshDataTool.get_face_normal(i) * scaling_factor) + face_center)
		i += 1
	normals_ig.end()
	_mesh.add_child(normals_ig)

# funciones del slice
func _create_cut_body(_sign,mesh_instance,cutplane : Plane, manipulation_feature):
	vr.log_info("Creating the halves...");
	var rigid_body_half = manipulation_feature.instance_model()
	rigid_body_half.gravity_scale = _cut_body_gravity_scale
	rigid_body_half.global_transform = global_transform;
	#create mesh
	var object = MeshInstance.new()
	object.mesh = mesh_instance
	object.scale = _mesh.scale
	if (_mesh.mesh.get_surface_count() > 0):
		var material_count
		if (_cross_section_material != null):
			 material_count= _mesh.mesh.get_surface_count()+1
		else:
			 material_count= _mesh.mesh.get_surface_count()
		for i in range(material_count):
			var mat 
			if (i == material_count -1 and _cross_section_material != null):
				mat = _cross_section_material
			else:
				mat = _mesh.mesh.surface_get_material(i)
			object.mesh.surface_set_material(i,mat)
	#create collider 
	var coll = CollisionShape.new()
	#add the body to scene
	rigid_body_half.add_child(object)
	rigid_body_half.add_child(coll)
	rigid_body_half.set_script(self.get_script())
	rigid_body_half._cut_body_gravity_scale = _cut_body_gravity_scale
	rigid_body_half._current_child_number = _current_child_number+1 
	rigid_body_half._delete_at_children =  _delete_at_children
	rigid_body_half._disable_at_children = _disable_at_children
	rigid_body_half._cross_section_material = _cross_section_material
	rigid_body_half._normal_force_on_cut = _normal_force_on_cut
	get_tree().get_root().add_child(rigid_body_half)
	var mesh = object.mesh
	var vertices = mesh.get_faces()
	var arrays = object.mesh.surface_get_arrays(2)
	if (_apply_force_on_cut):
		rigid_body_half.apply_central_impulse(_sign*cutplane.normal*_normal_force_on_cut)
	

func cut_object(cutplane:Plane, manipulation_feature):
	vr.log_info("Cutting object :3");
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
	if (enabled): 
		var slices = slice_calculator.new(cutplane,_mesh,true,_cross_section_material,_cross_section_texture_UV_scale,_cross_section_texture_UV_offset,true,true,true)
		_create_cut_body(-1,slices.negative_mesh(),cutplane, manipulation_feature);
		_create_cut_body( 1,slices.positive_mesh(),cutplane, manipulation_feature);
		queue_free();

func _get_configuration_warning():
	var warning = PoolStringArray()
	if (_mesh == null): 
		warning.append("please add a Mesh Instance with some mesh")
	return warning.join("\n")
# fin funciones del slice

func grab_init(node) -> void:
	feature_grab_node = node
	is_grabbed = true
	sleeping = false;
	_orig_can_sleep = can_sleep;
	can_sleep = false;

func _release():
	controller = feature_grab_node.controller
	is_grabbed = false
	feature_grab_node = null
	can_sleep = _orig_can_sleep;

func grab_release() -> void:
	_release();
	
#The zoom started so we have to start the distance calculation
func zoom_init(distance, first_controller_feature, second_controller_feature, first_controller, second_controller) -> void:
	zooming = true
	starting_zoom_distance = distance
	controller = first_controller
	other_controller = second_controller
	controller_feature = first_controller_feature
	other_controller_feature = second_controller_feature

func zoom_release() -> void:
	zooming = false
	controller_feature = null
	other_controller_feature = null
	starting_zoom_distance = 0

func cut_init(first_controller_feature, second_controller_feature, first_controller, second_controller) -> void:
	controller = first_controller
	other_controller = second_controller
	controller_feature = first_controller_feature
	other_controller_feature = second_controller_feature
	controller_feature.cut()
	
func be_selected(boolean: bool) -> void:
	_keep_marker = boolean

func get_keep_marker() -> bool:
	return _keep_marker

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
	emit_signal("grabbability_changed", self, false, feature_grab.controller)

func _integrate_forces(_state):
	if (!is_grabbed): return
	
	if (_release_next_physics_step):
		_release_next_physics_step = false
		_release()
	return
	
func _physics_process(_delta):
	if (zooming):
		var x = controller.get_global_transform().origin.x - other_controller.get_global_transform().origin.x
		var y = controller.get_global_transform().origin.y - other_controller.get_global_transform().origin.y
		var distance = sqrt(x*x + y*y)
		var zoom_delta = distance - starting_zoom_distance
		var zoom_speed = zoom_delta * 0.05
		var zoom_factor = 1.0 + zoom_speed
		global_scale(Vector3(zoom_factor, zoom_factor, zoom_factor))

func setup(mesh: Mesh, position: Transform):
	_mesh.mesh = mesh
	self.transform = position

func cut(origin: Vector3, normal: Vector3):
	vr.log_info("cut in manipulable")
	return $Slicer.slice(_mesh.mesh, self.transform, origin, normal, cross_section_material)
