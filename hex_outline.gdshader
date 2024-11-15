shader_type canvas_item;

uniform sampler2D hexagon_texture; // The hexagon texture
uniform vec4 outline_color; // Color of the outline
uniform float outline_thickness; // Thickness of the outline

void fragment() {
    vec4 tex_color = texture(hexagon_texture, UV); // Sample the hexagon texture

    // Initialize the color to the texture color
    COLOR = tex_color;

    // If the texture is transparent, we need to check surrounding pixels for the outline
    if (tex_color.a == 0.0) {
        // Check surrounding pixels for alpha
        float alpha_sum = 0.0;
        vec2 texel_size = 1.0 / vec2(textureSize(hexagon_texture, 0)); // Get the size of a texel

        // Loop through surrounding pixels based on outline thickness
        for (float x = -outline_thickness; x <= outline_thickness; x++) {
            for (float y = -outline_thickness; y <= outline_thickness; y++) {
                vec2 offset = vec2(x, y) * texel_size; // Offset based on texel size
                alpha_sum += texture(hexagon_texture, UV + offset).a;
            }
        }

        // If any surrounding pixel is opaque, we draw the outline
        if (alpha_sum > 0.0) {
            COLOR = outline_color; // Set outline color
        } else {
            discard; // Discard if no outline is found
        }
    }
}
