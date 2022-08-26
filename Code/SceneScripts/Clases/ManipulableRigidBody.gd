# Attach this script to any rigid body you want to be grabbable
# by the Feature_RigidBodyGrab
extends RigidBody

class_name ManipulableRigidBody

# Emitted when the objects grabbability changes state.
# Example usage could be for making an object "glow" when it is within
# grab distance.
signal grabbability_changed(body, grabbable, controller)

var controller = null;
var other_controller = null;

# the grab feature class that's currently holding us, null if not held
var feature_grab_node = null;
var delta_orientation = Basis();
var delta_position = Vector3();
var is_grabbed := false

# zoom variables
var started_zoom = false;
var zooming = false;
var starting_zoom_distance = 0;


# set to false to prevent the object from being grabbable
export var grab_enabled := true
# set to true to allow grab to be transferable between hands
export var is_transferable := true

var last_reported_collision_pos : Vector3 = Vector3(0,0,0);

var _orig_can_sleep := true;

var _release_next_physics_step := false;
var _cached_linear_velocity := Vector3(0,0,0); # required for kinematic grab
var _cached_angular_velocity := Vector3(0,0,0);

func ready():
	set_mode(RigidBody.MODE_STATIC)

func grab_init(node) -> void:
	feature_grab_node = node
	
	is_grabbed = true
	sleeping = false;
	_orig_can_sleep = can_sleep;
	can_sleep = false;

func _release():
	var controller = feature_grab_node.controller
	is_grabbed = false
	feature_grab_node = null
	can_sleep = _orig_can_sleep;


func grab_release() -> void:
	_release();
	
# The zoom started so we have to start the distance calculation
# func zoom_init(distance, first_controller, second_controller) -> void:
# 	vr.log_info("se llamo el zoom init");
# 	zooming = true
# 	starting_zoom_distance = distance
# 	controller = first_controller
# 	other_controller = second_controller

# func zoom_release() -> void:
# 	vr.log_info("se llamo el zoom release");
# 	zooming = false
# 	controller = null
# 	other_controller = null
# 	starting_zoom_distance = 0

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

func _integrate_forces(state):
	if (!is_grabbed): return;
	
	if (_release_next_physics_step):
		_release_next_physics_step = false;
		_release();
	return;
	
func _physics_process(delta):
	# if zooming:
	# 	vr.log_info("fisic proses suming");
	# 	var x = controller.get_global_transform().origin.x - other_controller.get_global_transform().origin.x
	# 	var y = controller.get_global_transform().origin.y - other_controller.get_global_transform().origin.y
	# 	var distance = sqrt(x*x + y*y)
	# 	var zoom_delta = distance - starting_zoom_distance
	# 	var zoom_speed = zoom_delta * 0.001
	# 	var zoom_factor = 1.0 + zoom_speed
	# 	global_scale(Vector3(zoom_factor, zoom_factor, zoom_factor));
	pass
