extends Spatial

class_name DisplayProperties

var selected_holder: Node
var edges_button: Node
var normals_button: Node

# Called when the node enters the scene tree for the first time
func _ready():
	selected_holder = get_node("../../../SelectedModel")
	edges_button = get_node("OQ_UI2DCanvas_DisplayProperties")
	#normals_button = $OQ_UI2DCanvas_DisplayProperties/ReferenceRect/NormalsButton

func restore_properties():
	vr.log_info("el connect funciono o no")
	_on_EdgesButton_toggled(false)
	_on_NormalsButton_toggled(false)
	vr.log_info("oye pq no printeas :C")
	for child in edges_button.get_children():
		vr.log_info(child.name)
	vr.log_info(edges_button.get_child(0).name)
	vr.log_info(edges_button.name)
	vr.log_info(edges_button)
	#vr.log_info(normals_button)
	#vr.log_info(normals_button.name)
	
	edges_button.emit_signal("pressed")
	#normals_button.emit_signal("pressed")
	vr.log_info("Aaaaaaaaa")

func _on_EdgesButton_toggled(button_pressed):
	if (selected_holder.get_child_count() > 0):
		#selected_holder.get_child(0).connect("selected_changed", self, "restore_properties")
		selected_holder.get_child(0).update_edges_visibility(button_pressed)
		vr.log_info("angry")
	else:
		vr.log_info("There is nothing selected")


func _on_NormalsButton_toggled(button_pressed):
	if (selected_holder.get_child_count() > 0):
		#selected_holder.get_child(0).connect("selected_changed", self, "restore_properties")
		selected_holder.get_child(0).update_normals_visibility(button_pressed)
		vr.log_info("angry 2")
	else:
		vr.log_info("There is nothing selected")
