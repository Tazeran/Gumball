shader_type spatial;

render_mode cull_back, depth_draw_opaque;

uniform sampler2D albedo_texture;
uniform vec2 uv_offset = vec2(0.0, 0.0);
uniform vec2 uv_scale = vec2(1.0, 1.0);

void fragment() {
    vec2 new_uv = UV * uv_scale + uv_offset;
    vec4 tex_color = texture(albedo_texture, new_uv);

    ALBEDO = tex_color.rgb;
    ALPHA = tex_color.a;

    ALPHA_SCISSOR_THRESHOLD = 0.1; // Important: treat as opaque when needed
}

void light() {
    float NdotL = max(dot(NORMAL, LIGHT), 0.0);
    DIFFUSE_LIGHT = ALBEDO * NdotL * ATTENUATION;
}
