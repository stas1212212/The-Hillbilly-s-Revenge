shader_type canvas_item;

uniform float form_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 spirit_white : source_color = vec4(0.91, 0.96, 1.0, 1.0);
uniform vec4 shadow_blue : source_color = vec4(0.32, 0.42, 0.56, 1.0);
uniform float shimmer : hint_range(0.0, 1.0) = 0.13;

void fragment() {
    vec4 base = COLOR; // In Godot 4 fragment(), COLOR already includes TEXTURE.
    float mask = smoothstep(0.0, 1.0, form_strength);
    float luminance = dot(base.rgb, vec3(0.2126, 0.7152, 0.0722));

    // Keep the original shading, silhouette and transparent edges.
    vec3 pale = mix(shadow_blue.rgb, spirit_white.rgb, smoothstep(0.04, 0.88, luminance));
    // Even near-black hair and cloth brighten into the spectral form.
    pale = mix(pale, spirit_white.rgb, 0.30);
    float breathe = 0.5 + 0.5 * sin(TIME * 3.4 + UV.y * 5.0);
    vec3 spectral = pale + spirit_white.rgb * shimmer * breathe * 0.13;

    COLOR = vec4(mix(base.rgb, spectral, mask), base.a);
}
