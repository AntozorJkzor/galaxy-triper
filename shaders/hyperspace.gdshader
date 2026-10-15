shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec2 center = vec2(0.5, 0.48);
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir = uv - center;
	float dist = length(dir);
	vec3 col = vec3(0.0);
	int samples = 16;
	float spread = amount * amount * 0.22 * (0.2 + dist);
	for (int i = 0; i < 16; i++) {
		float t = float(i) / 15.0;
		col += texture(screen_texture, uv - dir * (t * spread)).rgb;
	}
	col /= float(samples);
	vec3 tint = mix(vec3(1.0), vec3(0.62, 0.82, 1.35), amount);
	col *= tint;
	float ang = atan(dir.y, dir.x);
	float rays = pow(abs(sin(ang * 42.0 + amount * 8.0)), 16.0);
	col += vec3(0.55, 0.82, 1.25) * rays * dist * amount * 1.15;
	float core = (1.0 - smoothstep(0.0, 0.42, dist)) * amount * amount;
	col += vec3(0.55, 0.78, 1.15) * core * 0.85;
	col += vec3(0.35, 0.65, 1.2) * pow(amount, 1.6) * dist * 0.35;
	col = mix(col, vec3(0.92, 0.97, 1.0), flash);
	COLOR = vec4(col, 1.0);
}
