extends Spatial


var selected_holder: Node
var edges_button: CheckButton
var normals_button: CheckButton

# Called when the node enters the scene tree for the first time
func _ready():
	selected_holder = get_node("../../SelectedModel")
	edges_button = $OQ_UI2DCanvas_DisplayProperties/ReferenceRect/EdgesButton
	normals_button = $OQ_UI2DCanvas_DisplayProperties/ReferenceRect/NormalsButton

func restore_properties():
	_on_EdgesButton_toggled(false)
	_on_NormalsButton_toggled(false)
	edges_button.pressed = false
	normals_button.pressed = false

func _on_EdgesButton_toggled(button_pressed):
	if (selected_holder.get_child_count() > 0):
		selected_holder.get_child(0).update_edges_visibility(button_pressed)
	else:
		vr.log_info("There is nothing selected")


func _on_NormalsButton_toggled(button_pressed):
	if (selected_holder.get_child_count() > 0):
		selected_holder.get_child(0).update_normals_visibility(button_pressed)
	else:
		vr.log_info("There is nothing selected")
