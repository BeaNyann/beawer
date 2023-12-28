tool
extends Area


var plane_point_a:Vector3 
var plane_point_b:Vector3 
var plane_point_c:Vector3


func _on_Area_body_exited(body):
	#vr.log_info("r u here, im slicer")
	if body is ManipulableRigidBody:
		#vr.log_info("r u here parte 2, u r manipulablerigidbody")
		plane_point_a = $mesh/A.global_transform.origin
		plane_point_b = $mesh/B.global_transform.origin
		plane_point_c = $mesh/C.global_transform.origin
		var manipulation_feature = $"../Feature_RigidBodyManipulation"
		#body.cut_object(Plane(plane_point_a,plane_point_b,plane_point_c), manipulation_feature)
