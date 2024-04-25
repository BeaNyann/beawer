shader_type spatial;

render_mode unshaded, cull_front;

uniform float border_width : hint_range(0,1,0.001);
uniform vec4 color : hint_color = vec4(0.4898, 0.5852, 0.2810, 0.3);

void vertex() {
	VERTEX += VERTEX * border_width;
}

void fragment() {
	ALBEDO = color.xyz;
}