shader_type spatial;

render_mode blend_mix, cull_back, depth_prepass_alpha;

uniform sampler2D albedo_texture : source_color;
uniform float alpha = 0.4;
uniform vec3 tint_color : source_color = vec3(0.2, 0.6, 1.0); // bluish
uniform float fresnel_strength = 1.5;
uniform float fresnel_power = 2.0;
uniform float line_speed = 1.0;
uniform float line_density = 20.0;

void fragment() {
    vec4 base_tex = texture(albedo_texture, UV);

    float fresnel = pow(1.0 - dot(NORMAL, VIEW), fresnel_power) * fresnel_strength;
    float lines = sin(UV.y * line_density + TIME * line_speed) * 0.1 + 0.9;

    vec3 color = base_tex.rgb * tint_color * lines + fresnel;
    float final_alpha = base_tex.a * alpha;

    ALBEDO = color;
    ALPHA = final_alpha;
}
