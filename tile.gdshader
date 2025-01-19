shader_type canvas_item;

uniform sampler2D overlay_texture: repeat_enable, filter_nearest;
//uniform float falloff_distance = 0.7;

void fragment() {
    //float distance_from_center = length(UV - vec2(0.5));
   // float falloff = smoothstep(1.0, 1.0 - falloff_distance, distance_from_center);

    vec4 pixel_color = texture(overlay_texture, UV);
    //COLOR = vec4(pixel_color.rgb, pixel_color.a * falloff);
	COLOR.rgb = pixel_color.rgb;
}
