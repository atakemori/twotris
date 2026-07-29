shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

uniform vec4 base_color : source_color = vec4(0.5, 0.47, 0.87, 1.0);
uniform vec4 stripe_color : source_color = vec4(0.65, 0.62, 0.95, 1.0);
uniform float stripe_speed : hint_range(0.0, 3.0) = 0.3;
uniform float stripe_width : hint_range(1.0, 20.0) = 6.0;

void fragment() {
	float diagonal = (UV.x + UV.y) * stripe_width - TIME * stripe_speed * stripe_width;
	float stripe = step(0.5, fract(diagonal));
	COLOR = mix(base_color, stripe_color, stripe * 0.35);
}
