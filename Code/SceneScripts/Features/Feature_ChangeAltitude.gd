extends Spatial


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
onready var character = get_node("../../Character")
var initial_position

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_VSlider_value_changed(value):
	#vr.log_info(str(initial_position))
	character.transform.origin.y = value * 0.1
