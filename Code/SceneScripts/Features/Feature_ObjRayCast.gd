extends Feature_RigidBodyGrab

export var active := true;
export var ui_raycast_length := 3.0;
export var ui_mesh_length := 1.0;

export var adjust_left_right := true;

export(vr.CONTROLLER_BUTTON) var ui_raycast_visible_button := vr.CONTROLLER_BUTTON.TOUCH_INDEX_TRIGGER;
export(vr.CONTROLLER_BUTTON) var ui_raycast_click_button := vr.CONTROLLER_BUTTON.INDEX_TRIGGER;

onready var ui_raycast_position : Spatial = $RayCastPosition;
onready var ui_raycast : RayCast = $RayCastPosition/RayCast;
onready var ui_raycast_mesh : MeshInstance = $RayCastPosition/RayCastMesh;
onready var ui_raycast_hitmarker : MeshInstance = $RayCastPosition/RayCastHitMarker;

const hand_click_button := vr.CONTROLLER_BUTTON.XA;

var is_colliding := false;


func _set_raycast_transform():
	# woraround for now until there is a more standardized way to know the controller
	# orientation
	
	
	if (controller.is_hand):
		
		if (vr.ovrBaseAPI):
			ui_raycast_position.transform = controller.transform.inverse() * vr.ovrBaseAPI.get_pointer_pose(controller.controller_id);
		else:
			ui_raycast_position.transform.basis = Basis(Vector3(deg2rad(-90),0,0));
	else:
		ui_raycast_position.transform = Transform();
		
		# center the ray cast better to the actual controller position
		if (adjust_left_right):
			ui_raycast_position.translation.y = -0.005;
			ui_raycast_position.translation.z = -0.01;
		
			if (controller.controller_id == 1):
				ui_raycast_position.translation.x = -0.01;
			if (controller.controller_id == 2):
				ui_raycast_position.translation.x =  0.01;
		
	
		

func _update_raycasts():
	ui_raycast_hitmarker.visible = false;
	
	
	if (controller.is_hand && vr.ovrBaseAPI): # hand has separate logic
		ui_raycast_mesh.visible = vr.ovrBaseAPI.is_pointer_pose_valid(controller.controller_id);
		if (!ui_raycast_mesh.visible): return;
	elif (ui_raycast_visible_button == vr.CONTROLLER_BUTTON.None ||
		  controller._button_pressed(ui_raycast_visible_button) ||
		  controller._button_pressed(ui_raycast_click_button)): 
		ui_raycast_mesh.visible = true;
	else:
		# Process when raycast just starts to not be visible,
		# To allow for button release
		if (!ui_raycast_mesh.visible): return;
		ui_raycast_mesh.visible = false;
		
	_set_raycast_transform();

		
	ui_raycast.force_raycast_update(); # need to update here to get the current position; else the marker laggs behind
	
	
	if ui_raycast.is_colliding():
		var c = ui_raycast.get_collider();
		if (!c.has_method("ui_raycast_hit_event")): return;
		
		var click = false;
		var release = false;
		if (controller.is_hand):
			click = controller._button_just_pressed(hand_click_button);
			release = controller._button_just_released(hand_click_button);
		else:
			click = controller._button_just_pressed(ui_raycast_click_button);
			release = controller._button_just_released(ui_raycast_click_button);
		
		var position = ui_raycast.get_collision_point();
		ui_raycast_hitmarker.visible = true;
		ui_raycast_hitmarker.global_transform.origin = position;
		
		c.ui_raycast_hit_event(position, click, release);
		is_colliding = true;
	else:
		is_colliding = false;

func _ready():
	controller = get_parent();
	if (not controller is ARVRController):
		vr.log_error(" in Feature_UIRayCast: parent not ARVRController.");
		
	vr.log_info("hola estoy en el ready el obj ray cast")	
	grab_area = $RayCastPosition/RayCastHitMarker/GrabArea;
	grab_area.collision_mask = grab_layer;
	#grab_area.connect("body_entered", self, "_on_GrabArea_body_entered")
	#grab_area.connect("body_exited", self, "_on_GrabArea_body_exited")
	vr.log_info("conecte las señales")
	
	ui_raycast.set_cast_to(Vector3(0, 0, -ui_raycast_length));
	
	#setup the mesh
	ui_raycast_mesh.mesh.size.z = ui_mesh_length;
	ui_raycast_mesh.translation.z = -ui_mesh_length * 0.5;
	
	ui_raycast_hitmarker.visible = false;
	ui_raycast_mesh.visible = false;

# we use the physics process here be in sync with the controller position
func _physics_process(_dt):
	if (!active): return;
	if (!visible): return;
	_update_raycasts();
	

func _on_GrabArea_body_entered(body):
	print("esto debería estar llamandose owo")
	if body is RayCastGrabbableRigidBody:
		if body.grab_enabled:
			grabbable_candidates.push_back(body)
			
			if grabbable_candidates.size() == 1:
				body._notify_became_grabbable(self)
				
				# initiate "grabbable" rumble when first candidate acquired
				if rumble_on_grabbable and controller:
					controller.simple_rumble(rumble_on_grabbable_intensity,0.1)
				

func _on_GrabArea_body_exited(body):
	if body is RayCastGrabbableRigidBody:
		var prev_candidate = null
		
		# see if body is losing its grab candidacy. if so, notify
		if grabbable_candidates.size() > 0:
			prev_candidate = grabbable_candidates.front()
			if prev_candidate == body:
				prev_candidate._notify_lost_grabbable(self)
		
		grabbable_candidates.erase(body)
		
		# see if a grab candidacy has changed after removal. if so, notify
		if grabbable_candidates.size() > 0:
			var curr_candidate = grabbable_candidates.front()
			if prev_candidate != curr_candidate:
				curr_candidate._notify_became_grabbable(self)
