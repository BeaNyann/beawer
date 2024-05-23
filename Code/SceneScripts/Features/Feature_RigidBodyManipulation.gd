extends Spatial
class_name Feature_RigidBodyManipulation

var manipulable_object_scene = preload("res://Scenes/Features/ManipulableModel.tscn")

# The controller that this grab feature is bound to
var controller : ARVRController = null;
# The other controller's grab feature. null if it doesn't exist, or isn't found.
# This is needed so that we can release the object from the other controller
# prior to transferring grab ownership to this controller. If the release isn't
# performed correctly, strange node reparenting behavior can occur.
var other_manipulation_feature : Feature_RigidBodyManipulation = null
var other_controller : ARVRController = null
var grab_area : Area = null;
var held_object = null;
var held_object_data = {};
var other_held_object = null;
var other_held_object_data = {};
var grab_mesh : MeshInstance = null;
var held_object_initial_parent : Node
var last_gesture := "";
# A list of grabbable objects that are within the controller's grab distance.
# First object that entered the grab area is at the front. When grab event is
# initiated, the object at the front of the list will be grabbed.
var grabbable_candidates = []
# zoom var
var started_zooming = false;
var started_cutting = false;

# nodes variables
onready var _cutter_mesh = $Cutter
onready var _cutter_collision = $Cutter/CutterArea/CollisionShape
onready var _cutter_area = $Cutter/CutterArea
onready var _interactive_area = $InteractiveArea
onready var models_holder : Node = get_node("../../../../Manipulables")

#Slicer 
var mesh_slicer = MeshSlicer.new()
onready var slicer: Node = get_node("../Slicer")

# Inputs
export(vr.CONTROLLER_BUTTON) var grab_button = vr.CONTROLLER_BUTTON.GRIP_TRIGGER;
export(vr.CONTROLLER_BUTTON) var xa_button = vr.CONTROLLER_BUTTON.XA;
export(vr.CONTROLLER_BUTTON) var yb_button = vr.CONTROLLER_BUTTON.YB;

export(String) var grab_gesture := "Fist"
export(int, LAYERS_3D_PHYSICS) var grab_layer := 1
export var collision_body_active := false;
export(int, LAYERS_3D_PHYSICS) var collision_body_layer := 1
onready var _hinge_joint : HingeJoint = $HingeJoint;
export var reparent_mesh = false;
export var hide_model_on_grab := false;
# set to true to vibrate controller when object is grabbed
export var rumble_on_grab := false;
# control the intesity of vibration when player grabs an object
export(float,0,1,0.01) var rumble_on_grab_intensity = 0.4
# set to true to vibrate controller when object becomes grabbable
export var rumble_on_grabbable := false;
# control the intesity of vibration when an object becomes grabbable
export(float,0,1,0.01) var rumble_on_grabbable_intensity = 0.2


# Returns true if controller's grab button was pressed, or hand's grab gesture
# was detected
func just_grabbed() -> bool:
	var did_grab: bool
	
	if (controller.is_hand):
		var cur_gesture = controller.get_hand_model().detect_simple_gesture()
		did_grab = cur_gesture != last_gesture and cur_gesture == grab_gesture
		last_gesture = cur_gesture
	else:
		did_grab = controller._button_just_pressed(grab_button)
	
	return did_grab

# Returns true if controller's grab button is not pressed, or hand's grab
# gesture is not detected
func not_grabbing() -> bool:
	var not_grabbed: bool
	
	if (controller.is_hand):
		last_gesture = controller.get_hand_model().detect_simple_gesture()
		not_grabbed = last_gesture != grab_gesture
	else:
		not_grabbed = !controller._button_pressed(grab_button)
	
	return not_grabbed

func check_holding_and_pressing(button) -> bool:
	if (other_manipulation_feature.held_object != null):
		return controller._button_pressed(button)
	else:
		return false

# Returns true if controller's xa button was pressed
func zooming() -> bool:
	return check_holding_and_pressing(xa_button)

func cutting() -> bool:
	return controller._button_pressed(yb_button)

func _ready():
	_cutter_collision.disabled = true
	_cutter_mesh.visible = false

	# signals
	_cutter_area.connect("body_entered", self, "_on_cutter_collision_body_entered")
	_interactive_area.connect("body_entered", self, "_on_interactive_area_body_entered")
	_interactive_area.connect("body_exited", self, "_on_interactive_area_body_exited")

	controller = get_parent();
	if (not controller is ARVRController):
		vr.log_error(" in Feature_RigidBodyManipulation: parent not ARVRController.")
	grab_area = $InteractiveArea
	grab_area.collision_mask = grab_layer
	
	$CollisionKinematicBody.collision_layer = collision_body_layer
	$CollisionKinematicBody.collision_mask = collision_body_layer
	
	if (!collision_body_active):
		$CollisionKinematicBody/CollisionBodyShape.disabled = true
	
	# find the other Feature_RigidBodyGrab if it exists
	if (controller):
		if (controller.controller_id == 1): # left
			if (vr.rightController):
				other_controller = vr.rightController
				for c in vr.rightController.get_children():
					# can't use "is" because of cyclical dependency issue
					if (c.get_class() == "Feature_RigidBodyManipulation"):
						other_manipulation_feature = c
						break
		else: # right
			if (vr.leftController):
				other_controller = vr.leftController
				for c in vr.leftController.get_children():
					# can't use "is" because of cyclical dependency issue
					if (c.get_class() == "Feature_RigidBodyManipulation"):
						other_manipulation_feature = c
						break
						
# Godot's get_class() method only return native class names
# we need this because we can't use "is" to test against a class_name within
# the class itself, Godot complains about a weird cyclical dependency...
func get_class():
	return "Feature_RigidBodyManipulation"

func _physics_process(_dt):
	update_grab()
	update_zoom()
	update_cut()
	if (controller._button_just_pressed(yb_button)):
		cut_object() #temporal
		vr.log_info("pressed")

func cut_object():
	var area = get_node("../Slicer/Area")
	for body in area.get_overlapping_bodies().duplicate():
		vr.log_info("the object to cut is: " + str(body))
		if (body is ManipulableRigidBody):
			body.update_edges_visibility(false)
			body.update_normals_visibility(false)
			#The plane transform at the rigidbody local transform
			var meshinstance = body.get_mesh()
			var transform = Transform.IDENTITY
			transform.origin = meshinstance.to_local((slicer.global_transform.origin))
			transform.basis.x = meshinstance.to_local((slicer.global_transform.basis.x+body.global_transform.origin))
			transform.basis.y = meshinstance.to_local((slicer.global_transform.basis.y+body.global_transform.origin))
			transform.basis.z = meshinstance.to_local((slicer.global_transform.basis.z+body.global_transform.origin))		
			var collision = body.get_collider()
			#Slice the mesh
			var meshes = mesh_slicer.slice_mesh(transform,meshinstance.mesh,body.get_cross_section_material())
			meshinstance.mesh = meshes[0]

			#generate collision
			if (len(meshes[0].get_faces()) > 2):
				collision.shape = meshes[0].create_convex_shape()
	
			#second half of the mesh
			var body2 = body.duplicate()

			models_holder.add_child(body2)
			meshinstance = body2.get_mesh()
			collision = body2.get_collider()
			meshinstance.mesh = meshes[1]

			#generate collision
			if (len(meshes[1].get_faces()) > 2):
				collision.shape = meshes[1].create_convex_shape()
			
			# #get mesh size
			# var aabb = meshes[0].get_aabb()
			# var aabb2 = meshes[1].get_aabb()
			# #queue_free() if the mesh is too small
			# if aabb2.size.length() < 0.3:
			# 	body2.queue_free()
			# if aabb.size.length() < 0.3:
			# 	body.queue_free()
			# no eliminemos para probar

func instance_model():
	return manipulable_object_scene.instance()
	
func update_grab() -> void:
	if (just_grabbed()):
		grab()
	elif (not_grabbing()):
		release()

func update_zoom() -> void:
	if (zooming() and !started_zooming):
		start_zooming(other_manipulation_feature.held_object)
	elif (!zooming() and started_zooming):
		stop_zooming(other_manipulation_feature.held_object)

func update_cut() -> void:
	if (cutting() and !started_cutting):
		start_cutting()
	elif (!cutting() and started_cutting):
		stop_cutting()

func grab() -> void:
	vr.log_info("Grip button pressed on right controller")
	if (held_object):
		return
	# get the next grabbable candidate
	var grabbable_rigid_body = null
	if (grabbable_candidates.size() > 0):
		grabbable_rigid_body = grabbable_candidates.front()
	
	if (grabbable_rigid_body):
		# rumble controller to acknowledge grab action
		if (rumble_on_grab and controller):
			controller.simple_rumble(rumble_on_grab_intensity,0.1)
			
		start_interaction(grabbable_rigid_body)
		
		# Hiding a hand tracking model disables pose updating,
		# so we can't hide it here or we can't ever change gesture again
		if (hide_model_on_grab and not controller.is_hand):
			#make model dissappear
			var model = $"../Feature_ControllerModel_Left"
			if (model):
				model.hide()
			else:
				model = $"../Feature_ControllerModel_Right"
				if (model):
					model.hide()


func release():
	if (!held_object):
		return
	release_interaction()
	# Hiding a hand tracking model disables pose updating,
	# so we can't hide it here or we can't ever change gesture again
	if (hide_model_on_grab and not controller.is_hand):
		#make model reappear
		var model = $"../Feature_ControllerModel_Left"
		if (model):
			model.show()
		else:
			model = $"../Feature_ControllerModel_Right"
			if (model):
				model.show()


func start_interaction(grabbable_rigid_body):
	if (grabbable_rigid_body == null):
		vr.log_warning("Invalid grabbable_rigid_body in start_grab_hinge_joint()")
		return
	
	if (grabbable_rigid_body.is_grabbed):
		if (grabbable_rigid_body.is_transferable):
			# release from other hand to we can transfer to this hand
			other_manipulation_feature.release()
		else:
			# reject grab if object is already held and it's non-transferable
			return
		
	held_object = grabbable_rigid_body
	held_object.grab_init(self)
	
	_hinge_joint.set_node_b(held_object.get_path());
	held_object.set_mode(RigidBody.MODE_RIGID)
	
	if (reparent_mesh): _reparent_mesh()
	
func release_interaction():
	_release_reparent_mesh()
	_hinge_joint.set_node_b("")
	held_object.set_mode(RigidBody.MODE_STATIC)
	held_object.grab_release()
	held_object = null

#Starts the zoom with the initial distance between the controllers
func start_zooming(manipulable_rigidbody):
	if (manipulable_rigidbody == null):
		vr.log_warning("Invalid manipulable_rigid_body in start_zooming()")
		return;
	started_zooming = true
	#calculate the distance between the two objects and use that as the zoom distance
	var x = controller.get_global_transform().origin.x - other_controller.get_global_transform().origin.x
	var y = controller.get_global_transform().origin.y - other_controller.get_global_transform().origin.y
	var distance = sqrt(x*x + y*y)
	manipulable_rigidbody.zoom_init(distance, self, other_manipulation_feature, controller, other_controller)

#Stops the zoom
func stop_zooming(manipulable_rigidbody):
	if (manipulable_rigidbody.zooming):
		manipulable_rigidbody.zoom_release()
	started_zooming = false
	other_manipulation_feature.release()

func start_cutting():
	_cutter_collision.disabled = false
	_cutter_mesh.visible = true
	started_cutting = true

func stop_cutting():
	_cutter_collision.disabled = true
	_cutter_mesh.visible = false
	started_cutting = false

func _release_reparent_mesh():
	if (grab_mesh):
		remove_child(grab_mesh)
		held_object.add_child(grab_mesh)
		grab_mesh.transform = Transform()
		grab_mesh = null

func _reparent_mesh():
	for c in held_object.get_children():
		if (c is MeshInstance):
			grab_mesh = c
			break
	if (grab_mesh):
		vr.log_info("Feature_RigidBodyGrab: reparentin mesh " + grab_mesh.name)
		var mesh_global_trafo = grab_mesh.global_transform
		held_object.remove_child(grab_mesh)
		add_child(grab_mesh)
		grab_mesh.global_transform = mesh_global_trafo

func _on_cutter_collision_body_entered(body):
	if (body is ManipulableRigidBody):
		#body.cut_init(self, other_manipulation_feature, controller, other_controller)
		vr.log_info("debería empezar el corte (#comentado)")

func _on_interactive_area_body_entered(body):
	if (body is ManipulableRigidBody):
		if (body.grab_enabled):
			grabbable_candidates.push_back(body)
			
			if (grabbable_candidates.size() == 1):
				body._notify_became_grabbable(self)
				
				# initiate "grabbable" rumble when first candidate acquired
				if (rumble_on_grabbable and controller):
					controller.simple_rumble(rumble_on_grabbable_intensity,0.1)

func _on_interactive_area_body_exited(body):
	if (body is ManipulableRigidBody):
		var prev_candidate = null
		
		# see if body is losing its grab candidacy. if so, notify
		if (grabbable_candidates.size() > 0):
			prev_candidate = grabbable_candidates.front()
			if (prev_candidate == body):
				prev_candidate._notify_lost_grabbable(self)
		grabbable_candidates.erase(body)
		
		# see if a grab candidacy has changed after removal. if so, notify
		if (grabbable_candidates.size() > 0):
			var curr_candidate = grabbable_candidates.front()
			if (prev_candidate != curr_candidate):
				curr_candidate._notify_became_grabbable(self)

func cut():
	vr.log_info("cut feature")
	var cutter_transform = _cutter_mesh.global_transform
	for body in _cutter_area.get_overlapping_bodies():
		if (body is ManipulableRigidBody):
			var origin = cutter_transform.origin - body.transform.origin
			var normal = body.transform.basis.xform_inv(cutter_transform.basis.y)
			var dist = cutter_transform.basis.y.dot(origin)
			var plane = Plane(normal, dist)
			var sliced_mesh = body.cut(cutter_transform.origin, cutter_transform.basis.y)
			if (not sliced_mesh):
				continue

			if (sliced_mesh.upper_mesh):
				var upper = manipulable_object_scene.instance()
				upper.setup(sliced_mesh.upper_mesh, body.transform)
				upper.cross_section_material = body.cross_section_material
				models_holder.add_child(upper)
#
			if (sliced_mesh.lower_mesh):
				var lower = manipulable_object_scene.instance()
				lower.setup(sliced_mesh.lower_mesh, body.transform)
				lower.cross_section_material = body.cross_section_material
				models_holder.add_child(lower)
			body.queue_free()
