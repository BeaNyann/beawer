extends Spatial

export var active := true;
export var ui_raycast_length := 3.0;
export var ui_mesh_length := 1.0;

export var adjust_left_right := true;

export(vr.CONTROLLER_BUTTON) var ui_raycast_visible_button := vr.CONTROLLER_BUTTON.TOUCH_INDEX_TRIGGER;
export(vr.CONTROLLER_BUTTON) var ui_raycast_click_button := vr.CONTROLLER_BUTTON.INDEX_TRIGGER;

var controller : ARVRController = null;
onready var ui_raycast_position : Spatial = $RayCastPosition;
onready var ui_raycast : RayCast = $RayCastPosition/RayCast;
onready var ui_raycast_mesh : MeshInstance = $RayCastPosition/RayCastMesh;
onready var ui_raycast_hitmarker : MeshInstance = $RayCastPosition/RayCastHitMarker;
onready var root = get_tree().get_root();
onready var models_holder : Node = root.get_node("Manipulables");
onready var selected_holder : Node = root.get_node("SelectedModel");

const hand_click_button := vr.CONTROLLER_BUTTON.INDEX_TRIGGER;

var is_colliding := false;
var cur_selected = null;


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
		if !is_colliding:
			is_colliding = true;
			vr.log_info("colliding")
			cur_selected = ui_raycast.get_collider();
			cur_selected.set_highlight(true)
			
			select_model()

		if (not cur_selected is ManipulableRigidBody): return
		
		if(controller._button_just_pressed(ui_raycast_click_button)):
			select_model()

		var position = ui_raycast.get_collision_point();
		ui_raycast_hitmarker.visible = true;
		ui_raycast_hitmarker.global_transform.origin = position;

	elif is_colliding:
		if(cur_selected):
			cur_selected.set_highlight(false)
		is_colliding = false;

func select_model():
	vr.log_info("selecting model")
	if (models_holder.has_child(cur_selected)):
		models_holder.remove_child(cur_selected)
	if (!selected_holder.has_child(cur_selected)):
		selected_holder.add_child(cur_selected)
	
	# cur_selected.be_selected(); maybe this is not needed anymore

func _ready():
	controller = get_parent();
	if (not controller is ARVRController):
		vr.log_error(" in Feature_UIRayCast: parent not ARVRController.");
	
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