shader_type canvas_item;

void fragment() {
    vec2 uv = UV;
    uv -= 0.5; // move to center
    float dist = length(uv); // calculate distance from center
    if (dist > 0.5) {
        COLOR = vec4(0.0); // outside circle, transparent
    } else {
        COLOR = COLOR; // inside circle, use ColorRect's color
    }
}
