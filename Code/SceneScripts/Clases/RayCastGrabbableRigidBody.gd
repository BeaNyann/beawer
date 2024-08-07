# Attach this script to any rigid body you want to be grabbable
# by the Feature_RigidBodyGrab
extends RigidBody

class_name RayCastGrabbableRigidBody

# Emitted when the objects grabbability changes state.
# Example usage could be for making an object "glow" when it is within
# grab distance.
signal grabbability_changed(body, grabbable, controller)

# Emitted when the object is grabbed by the player.
signal grabbed(body, controller)

# Emitted when the object is released by the player.
signal released(body, controller)

# the grab feature class that's currently holding us, null if not held
var feature_grab_node = null;
var delta_orientation = Basis();
var delta_position = Vector3();
var is_grabbed := false

# set to false to prevent the object from being grabbable
export var grab_enabled := true
# set to true to allow grab to be transferable between hands
export var is_transferable := true

var last_reported_collision_pos : Vector3 = Vector3(0,0,0);

var _orig_can_sleep := true;

var _grab_type := -1;

var _release_next_physics_step := false;
var _cached_linear_velocity := Vector3(0,0,0); # required for kinematic grab
var _cached_angular_velocity := Vector3(0,0,0);


var last_pos2d = null;

func ui_raycast_hit_event(position, click, release):
	var local_position = to_local(position);
	var pos2d = Vector2(local_position.x, -local_position.y)
	pos2d = pos2d + Vector2(0.5, 0.5)
	

	if (click || release):
		var e = InputEventMouseButton.new();
		e.pressed = click;
		e.button_index = BUTTON_LEFT;
		e.position = pos2d;
		e.global_position = pos2d;
		
		#if (click): print("Click");
		#if (release): print("Release");

		
	elif (last_pos2d != null && last_pos2d != pos2d):
		var e = InputEventMouseMotion.new();
		e.relative = pos2d - last_pos2d;
		e.speed = (pos2d - last_pos2d) / 16.0; #?? chose an arbitrary scale here for now
		e.global_position = pos2d;
		e.position = pos2d;
		
	last_pos2d = pos2d;

func grab_init(node, grab_type: int) -> void:
	feature_grab_node = node
	_grab_type = grab_type
	
	is_grabbed = true
	sleeping = false;
	_orig_can_sleep = can_sleep;
	can_sleep = false;
	emit_signal("grabbed",self,feature_grab_node.controller)

func _release():
	var controller = feature_grab_node.controller
	is_grabbed = false
	feature_grab_node = null
	can_sleep = _orig_can_sleep;
	emit_signal("released",self,controller)


func grab_release() -> void:
	if _grab_type == vr.GrabTypes.KINEMATIC:
		_release_next_physics_step = true;
		_cached_linear_velocity = linear_velocity;
		_cached_angular_velocity = angular_velocity;
	else:
		_release();
	


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
		if _grab_type == vr.GrabTypes.KINEMATIC:
			state.set_linear_velocity(_cached_linear_velocity);
			state.set_angular_velocity(_cached_angular_velocity);
		_release();
		return;
	
	# it would be better to use == Feature_RigidBodyGrab.GrabTypes.KINEMATIC
	# but this leads to an odd cyclic reference error
	# related to this bug: https://github.com/godotengine/godot/issues/21461
	if _grab_type == vr.GrabTypes.KINEMATIC:
		return;

	if _grab_type == vr.GrabTypes.HINGEJOINT:
		return;
	
	if (_grab_type == vr.GrabTypes.VELOCITY):
		if (!feature_grab_node): return;
		var target_basis =  feature_grab_node.get_global_transform().basis * delta_orientation;
		var target_position = feature_grab_node.get_global_transform().origin# + target_basis.xform(delta_position);
		position_follow(state, get_global_transform().origin, target_position);
		orientation_follow(state, get_global_transform().basis, target_basis);
