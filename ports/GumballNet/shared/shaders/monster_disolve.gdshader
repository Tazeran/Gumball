shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform bool use_albedo_texture = false;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D noise_tex : filter_linear_mipmap;
uniform sampler2D burn_ramp : source_color;
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform float burn_width : hint_range(0.01, 0.25) = 0.09;
uniform float noise_scale : hint_range(0.5, 8.0) = 2.5;
uniform float emission_strength : hint_range(0.0, 12.0) = 5.0;

varying vec3 model_position;

void vertex() {
	model_position = VERTEX;
}

void fragment() {
	// Blend two projections so the breakup wraps around the model instead of
	// looking like a flat UV wipe. A small height bias makes the burn travel up.
	float noise_xy = texture(noise_tex, model_position.xy * noise_scale + vec2(0.17, 0.43)).r;
	float noise_zy = texture(noise_tex, model_position.zy * noise_scale + vec2(0.61, 0.11)).r;
	float breakup = mix(noise_xy, noise_zy, 0.5) + model_position.y * 0.08;
	float threshold = mix(-0.12, 1.12, dissolve_amount);
	float remaining = breakup - threshold;
	if (remaining < 0.0) {
		discard;
	}

	vec4 base = albedo_color;
	if (use_albedo_texture) {
		base *= texture(albedo_texture, UV);
	}
	float edge = 1.0 - smoothstep(0.0, burn_width, remaining);
	vec3 burn = texture(burn_ramp, vec2(clamp(remaining / burn_width, 0.0, 1.0), 0.5)).rgb;
	ALBEDO = mix(base.rgb, burn, edge);
	ROUGHNESS = mix(0.72, 0.35, edge);
	EMISSION = burn * edge * emission_strength;
}
