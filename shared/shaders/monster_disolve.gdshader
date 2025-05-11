shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

uniform sampler2D noise_tex;
uniform sampler2D burn_ramp;

uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform float burn_width : hint_range(0.01, 0.3) = 0.1;

void fragment() {
	vec2 uv = UV;
	float noise = texture(noise_tex, uv).r;
	float edge = noise - dissolve_amount;

	if (edge < 0.0) {
		discard;
	}

	float burn_t = clamp(edge / burn_width, 0.0, 1.0);
	vec4 burn_color = texture(burn_ramp, vec2(burn_t, 0.0));

	ALBEDO = mix(burn_color.rgb, vec3(0.05), burn_t); // Blacken as it burns
	ALPHA = burn_color.a;
	EMISSION = burn_color.rgb * (1.0 - burn_t);
}
