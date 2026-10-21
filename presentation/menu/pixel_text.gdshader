shader_type canvas_item;
// The menu lettering is drawn into a 320x180 layer; this turns it into hard game pixels: every pixel is either
// fully transparent or fully opaque (the anti-aliased edge is cut at half opacity) and its colour is snapped to the
// nearest colour of the Totoy 36 palette (reserved gold and red excluded). Readable pixel lettering over a smooth
// background.
uniform vec3 palette[36];
uniform int palette_size = 32;

float distance_weighted(vec3 a, vec3 b) {
	float rm = (a.r + b.r) * 0.5;
	vec3 d = a - b;
	return (2.0 + rm) * d.r * d.r + 4.0 * d.g * d.g + (3.0 - rm) * d.b * d.b;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec3 c = t.a > 0.001 ? clamp(t.rgb / t.a, 0.0, 1.0) : t.rgb;
	vec3 best = palette[0];
	float best_d = 1e9;
	for (int i = 0; i < 36; i++) {
		if (i >= palette_size) {
			break;
		}
		float d = distance_weighted(c, palette[i]);
		if (d < best_d) {
			best_d = d;
			best = palette[i];
		}
	}
	COLOR = vec4(best, step(0.5, t.a));
}
