shader_type spatial;
render_mode unshaded, cull_back, specular_disabled, depth_draw_opaque;

uniform sampler2D planet_tex : source_color, filter_linear, repeat_disable;
uniform float dark_side : hint_range(0.15, 0.8) = 0.32;

void fragment() {
	vec3 world_n = normalize(mat3(INV_VIEW_MATRIX) * NORMAL);
	vec3 obj_n = normalize(inverse(mat3(MODEL_MATRIX)) * world_n);
	vec2 uv = vec2(obj_n.x, -obj_n.y) * 0.5 + 0.5;
	vec4 col = texture(planet_tex, uv);
	float rim = length(vec2(obj_n.x, obj_n.y));
	if (rim > 0.992 || col.a < 0.35) {
		discard;
	}
	vec3 rgb = col.rgb;
	if (obj_n.z < 0.0) {
		rgb *= dark_side;
	}
	ALBEDO = rgb;
	ALPHA = 1.0;
}
