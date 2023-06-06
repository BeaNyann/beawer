extends Spatial


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

onready var selected_holder : Node = get_node("../../SelectedModel");


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_EdgesButton_toggled(button_pressed):
	#vr.log_info("AAAAAAAAAAAAAAAAAAAAAAAAA")
	#vr.log_info(str(selected_holder))
	#vr.log_info(str(selected_holder.get_child_count()))
	if(selected_holder.get_child_count() > 0):
		#vr.log_info(str(selected_holder.get_child(0)))
		selected_holder.get_child(0).update_edges_visibility(button_pressed)
	else:
		vr.log_info("No hay nada seleccionado")


func _on_NormalsButton_toggled(button_pressed):
	if(selected_holder.get_child_count() > 0):
		selected_holder.get_child(0).update_normals_visibility(button_pressed)
	else:
		vr.log_info("No hay nada seleccionado")
