extends Spatial


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

# temporal!¡ tengo que seleccionar un objeto... oh hacerlo solo con la manzana xd
onready var apple = get_node("../../Pickables/FloatingApple")
#

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_EdgesButton_toggled(button_pressed):
	apple.update_edges_visibility(button_pressed)


func _on_NormalsButton_toggled(button_pressed):
	apple.update_normals_visibility(button_pressed)
